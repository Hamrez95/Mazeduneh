"""Real API regression for zero-stock creation, variant addition and receiving."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[2]
BASE = "http://127.0.0.1:5107"
SLUG = "price-calculator-fixture"
ZERO, POSITIVE, ADDED = "CI-OPENING-ZERO", "CI-OPENING-POSITIVE", "CI-OPENING-ADDED"


def request(path, method="GET", body=None, token=None, extra_headers=None):
    headers = {"Content-Type": "application/json"} if body is not None else {}
    headers.update(extra_headers or {})
    if token:
        headers["Authorization"] = "Bearer " + token
    try:
        response = urlopen(Request(BASE + path, method=method, headers=headers,
                                   data=json.dumps(body).encode() if body is not None else None), timeout=8)
    except HTTPError as error:
        response = error
    with response:
        content = response.read()
        return response.status, json.loads(content) if content else None


def start_api(permissions=None):
    env = os.environ.copy()
    if permissions is not None:
        env.update(Admin__Role="ReadOnlyAnalyst", Admin__Permissions=permissions)
    process = subprocess.Popen(["dotnet", "run", "--project", "services/api/Mazeduneh.Api.csproj",
                                "--configuration", "Release", "--no-build", "--urls", BASE],
                               cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
    try:
        for _ in range(40):
            if process.poll() is not None:
                raise AssertionError("Purchase test API exited")
            try:
                if request("/health/live")[0] == 200:
                    status, login = request("/api/v1/admin/auth/login", "POST", {
                        "email": os.environ["Admin__Email"], "password": "Mazeduneh-CI-Owner-Password!"})
                    assert status == 200
                    return process, login["accessToken"]
            except (URLError, TimeoutError):
                pass
            time.sleep(1)
        raise AssertionError("Purchase test API did not start")
    except BaseException:
        stop_api(process)
        raise


def stop_api(process):
    process.terminate()
    try:
        process.wait(timeout=10)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=5)


def step_up(token, password="Mazeduneh-CI-Owner-Password!"):
    return request('/api/v1/admin/auth/step-up', 'POST', {'password': password}, token)


SKU = 'CI-PRICE-250'
PATH = '/api/v1/admin/inventory/pricing/' + SKU

def checkout(key):
    status, order = request('/api/v1/checkout/orders', 'POST', {
        'customerName': 'CI customer', 'mobile': '09129999999', 'province': 'Tehran', 'city': 'Tehran',
        'address': 'CI address', 'postalCode': '1234567890', 'shippingMethod': 'pickup',
        'lines': [{'sku': SKU, 'quantity': 1}]}, extra_headers={'Idempotency-Key': key})
    assert status == 201, status
    return order

with tempfile.TemporaryFile() as log:
    api, token = start_api()
    try:
        status, _ = request('/api/v1/products/', 'POST', {
            'title': 'CI price', 'slug': SLUG, 'category': 'CI', 'origin': 'IR', 'currency': 'IRR',
            'unitType': 'Weight', 'isPublished': True, 'variants': [
                {'sku': SKU, 'quantity': 250, 'displayLabel': '250g', 'price': 5000, 'availablePackages': 0}]}, token)
        assert status == 201
        receipt = {'sku': SKU, 'batchCode': 'CI-PRICE-ONE', 'receivedPackages': 12,
                   'producedAt': '2025-01-01T00:00:00Z', 'expiresAt': '2030-01-01T00:00:00Z',
                   'costPrice': 4000, 'packagingCost': 500, 'additionalCost': 100,
                   'purchasedAt': '2026-01-01T00:00:00Z', 'supplier': 'CI price supplier'}
        status, batch = request('/api/v1/admin/inventory/batches', 'POST', receipt, token)
        assert status == 201
        old_order = checkout('ci-price-before')
        recipe = {'batchId': batch['id'], 'packagingCost': 500, 'packagingMultiplier': 1.2,
                  'packagingPercent': 10, 'additionalCost': 100, 'additionalPercent': 5,
                  'markupPercent': 25, 'roundingStep': 10}
        status, quote = request(PATH+'/preview', 'POST', recipe, token)
        assert status == 200 and quote['sellingPrice'] == 6630 and quote['totalCost'] == 5300
        assert quote['profit'] == 1330 and quote['marginPercent'] == 20.06
        _, state = request(PATH, token=token)
        assert state['currentPrice'] == 5000 and state['recipe'] is None  # Preview never mutates.
        assert request(PATH+'/preview', 'POST', dict(recipe, roundingStep=0), token)[0] == 400
        assert request(PATH+'/preview', 'POST', dict(recipe, batchId='00000000-0000-0000-0000-000000000001'), token)[0] == 409
        assert request(PATH+'/apply', 'POST', {'recipe': recipe, 'expectedPrice': 5000}, token)[0] == 428
        assert step_up(token, 'incorrect-password')[0] == 403
        status, step_up_response = step_up(token)
        assert status == 200 and step_up_response.get('stepUpToken')
        step_up_headers = {'X-Admin-Step-Up': step_up_response['stepUpToken']}
        assert request(PATH+'/apply', 'POST', {'recipe': recipe, 'expectedPrice': 4999}, token, step_up_headers)[0] == 409
        assert request(PATH+'/apply', 'POST', {'recipe': recipe}, token, step_up_headers)[0] == 400
        status, applied = request(PATH+'/apply', 'POST', {'recipe': recipe, 'expectedPrice': 5000}, token, step_up_headers)
        assert status == 200 and applied == quote
        assert request(PATH+'/apply', 'POST', {'recipe': recipe, 'expectedPrice': 5000}, token, step_up_headers)[0] == 409
        assert request(PATH+'/apply', 'POST', {'recipe': recipe, 'expectedPrice': 6630}, token, step_up_headers)[0] == 200  # No-op, no duplicate audit.
        _, events = request('/api/v1/admin/audit-log?entityType=ProductVariant&entityId='+SKU, token=token)
        assert len(events) == 1 and events[0]['actor'] == os.environ['Admin__Email']
        assert events[0]['beforeJson'] and events[0]['afterJson']
        _, public = request('/api/v1/products/'+SLUG)
        assert public['variants'][0]['price'] == 6630  # Visible before process restart.
        assert public['variants'][0]['costPrice'] == 0
        _, private = request('/api/v1/products/admin', token=token)
        variant = next(p for p in private if p['slug'] == SLUG)['variants'][0]
        assert variant['costPrice'] == 4000 and variant['packagingCost'] == 1000 and variant['additionalCost'] == 300
        _, history = request('/api/v1/admin/inventory/batches?sku='+SKU, token=token)
        assert history[0]['costPrice'] == 4000 and history[0]['packagingCost'] == 500  # Original purchase immutable.
        new_order = checkout('ci-price-after')
        assert new_order['lines'][0]['unitPrice'] == 6630
        _, original = request('/api/v1/checkout/orders/'+old_order['id']+'?receiptToken='+old_order['receiptToken'])
        assert original['lines'][0]['unitPrice'] == 5000
        assert request(PATH)[0] == 401
    finally:
        stop_api(api)
    api, token = start_api()
    try:
        _, state = request(PATH, token=token)
        assert state['currentPrice'] == 6630 and state['recipe']['markupPercent'] == 25
        _, settings = request('/api/v1/admin/commerce/settings', token=token)
        update = {'taxRatePercent': 8, 'shippingMethods': settings['shippingMethods']}
        settings_path = '/api/v1/admin/commerce/settings'
        assert request(settings_path, 'PUT', update, token)[0] == 428
        assert step_up(token, 'incorrect-password')[0] == 403
        status, proof = step_up(token)
        assert status == 200 and proof.get('stepUpToken')
        headers = {'X-Admin-Step-Up': proof['stepUpToken']}
        assert request(settings_path, 'PUT', update, token, headers)[0] == 200
        _, updated_settings = request(settings_path, token=token)
        assert updated_settings['taxRatePercent'] == 8
        _, events = request('/api/v1/admin/audit-log?entityType=commerce_settings&entityId=default', token=token)
        assert any(event['action'] == 'commerce-settings.update'
                   and event['actor'] == os.environ['Admin__Email']
                   and event['beforeJson'] and event['afterJson'] for event in events)
    finally:
        stop_api(api)
    for permissions in ['inventory.read', 'inventory.read,pricing.write', 'inventory.read,products.write']:
        api, token = start_api(permissions)
        try:
            assert request(PATH+'/preview', 'POST', recipe, token)[0] == 200
            assert request(PATH+'/apply', 'POST', {'recipe': recipe, 'expectedPrice': 6630}, token)[0] == 403
        finally:
            stop_api(api)
    for permissions, expected_status in [('pricing.read', 403), ('pricing.read,pricing.write', 428)]:
        api, token = start_api(permissions)
        try:
            _, settings = request('/api/v1/admin/commerce/settings', token=token)
            update = {'taxRatePercent': settings['taxRatePercent'], 'shippingMethods': settings['shippingMethods']}
            settings_path = '/api/v1/admin/commerce/settings'
            status, _ = request(settings_path, 'PUT', update, token)
            assert status == expected_status, (permissions, status)
            if expected_status == 428:
                status, proof = step_up(token)
                assert status == 200
                assert request(settings_path, 'PUT', update, token,
                               {'X-Admin-Step-Up': proof['stepUpToken']})[0] == 200
        finally:
            stop_api(api)
print('Pricing arithmetic, preview/apply, permissions, stale safety, audit, persistence, catalog and order snapshot passed')
