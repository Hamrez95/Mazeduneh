"""Coupon contract against a real migrated API/PostgreSQL (CI or local).

Set MAZEDUNEH_TEST_BASE and MAZEDUNEH_TEST_CREDENTIALS for an existing local API.
Otherwise starts a CI API using the workflow's database/auth environment.
Creates uniquely named fixtures; does not touch existing products or campaigns.
"""
import concurrent.futures
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import uuid
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

ROOT = Path(__file__).resolve().parents[2]
BASE = os.environ.get('MAZEDUNEH_TEST_BASE', 'http://127.0.0.1:5112')
credentials = json.loads(Path(os.environ['MAZEDUNEH_TEST_CREDENTIALS']).read_text(encoding='utf-8-sig')) if os.environ.get('MAZEDUNEH_TEST_CREDENTIALS') else {}
EMAIL = credentials.get('adminEmail', os.environ.get('Admin__Email'))
PASSWORD = credentials.get('adminPassword', 'Mazeduneh-CI-Owner-Password!')
TOKEN = None
PREFIX = 'COUPON-' + uuid.uuid4().hex[:10].upper()


def request(path, method='GET', body=None, auth=False, headers=None):
    h = {'Content-Type': 'application/json'}
    if auth:
        h['Authorization'] = 'Bearer ' + TOKEN
    h.update(headers or {})
    try:
        response = urlopen(Request(BASE + path, method=method, headers=h,
                                   data=json.dumps(body).encode() if body is not None else None), timeout=20)
    except HTTPError as error:
        response = error
    with response:
        data = response.read()
        return response.status, json.loads(data) if data else None


def check(status, expected, body):
    assert status == expected, (status, expected, body)
    return body


def run():
    global TOKEN
    status, data = request('/health/ready')
    assert status == 200 and data['database'] == 'healthy'
    status, login = request('/api/v1/admin/auth/login', 'POST', {'email': EMAIL, 'password': PASSWORD})
    TOKEN = check(status, 200, login)['accessToken']
    cached_proof = None
    def proof():
        nonlocal cached_proof
        if cached_proof is not None:
            return cached_proof
        status, data = request('/api/v1/admin/auth/step-up', 'POST', {'password': PASSWORD}, True)
        cached_proof = {'X-Admin-Step-Up': check(status, 200, data)['stepUpToken']}
        return cached_proof
    sku = PREFIX + '-250'
    status, data = request('/api/v1/products/', 'POST', {
        'title': PREFIX, 'slug': PREFIX.lower(), 'category': 'Coupon fixture', 'origin': 'IR', 'currency': 'IRR',
        'unitType': 'Weight', 'isPublished': True, 'variants': [
            {'sku': sku, 'quantity': 250, 'displayLabel': '250g', 'price': 1000000, 'availablePackages': 0}]}, True, proof())
    check(status, 201, data)
    status, data = request('/api/v1/admin/inventory/batches', 'POST', {
        'sku': sku, 'batchCode': PREFIX, 'receivedPackages': 20,
        'producedAt': '2026-01-01T00:00:00Z', 'expiresAt': '2030-01-01T00:00:00Z',
        'costPrice': 100000, 'packagingCost': 10000, 'additionalCost': 5000,
        'purchasedAt': '2026-01-01T00:00:00Z', 'supplier': 'Coupon test fixture'}, True)
    check(status, 201, data)
    rule = {'name': PREFIX, 'kind': 'Percent', 'value': 10, 'active': True,
            'startsAt': '2026-01-01T00:00:00Z', 'endsAt': '2030-01-01T00:00:00Z',
            'minSubtotal': 1, 'maxDiscount': 50000, 'maxUses': 1, 'skus': [sku], 'allowLoss': False}
    path = '/api/v1/admin/promotions/' + PREFIX
    assert request(path, 'PUT', rule)[0] == 401
    assert request(path, 'PUT', rule, True)[0] == 428
    status, data = request(path, 'PUT', rule, True, proof())
    check(status, 200, data)
    preview = {'code': PREFIX.lower(), 'lines': [{'sku': sku, 'quantity': 1}], 'shippingMethod': 'pickup'}
    status, data = request('/api/v1/checkout/coupon-preview', 'POST', preview)
    check(status, 200, data)
    assert data['discount'] == 50000 and data['payable'] == 1045000
    assert 'cost' not in data and 'netProfit' not in data
    order = {'customerName': 'Coupon fixture', 'mobile': '09129999999', 'province': 'Tehran', 'city': 'Tehran',
             'address': 'Test address', 'postalCode': '1234567890', 'shippingMethod': 'pickup',
             'lines': preview['lines'], 'couponCode': PREFIX.lower()}
    def checkout(key, payload=order):
        return request('/api/v1/checkout/orders', 'POST', payload, headers={'Idempotency-Key': key})
    keys = [str(uuid.uuid4()), str(uuid.uuid4())]
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(checkout, keys))
    assert sorted(s for s, _ in results) == [201, 409], results
    winner = next(i for i, result in enumerate(results) if result[0] == 201)
    saved = results[winner][1]
    assert saved['couponCode'] == PREFIX and saved['discount'] == 50000 and saved['payable'] == 1045000
    status, replay = checkout(keys[winner])
    assert status == 200 and replay['id'] == saved['id']
    # Editing/turning off a campaign cannot rewrite a committed order snapshot.
    status, data = request(path, 'PUT', dict(rule, active=False, value=5), True, proof())
    check(status, 200, data)
    status, replay = checkout(keys[winner])
    assert status == 200 and replay['discount'] == 50000
    assert request('/api/v1/checkout/coupon-preview', 'POST', preview)[0] == 400
    # A loss-making basket requires an explicit stored Owner approval.
    status, data = request(path, 'PUT', dict(rule, value=100, maxDiscount=None, maxUses=10), True, proof())
    check(status, 200, data)
    assert request('/api/v1/checkout/coupon-preview', 'POST', preview)[0] == 400
    status, data = request(path, 'PUT', dict(rule, value=100, maxDiscount=None, maxUses=10, allowLoss=True), True, proof())
    assert check(status, 200, data)['lossApprovedBy'] == EMAIL
    assert request('/api/v1/checkout/coupon-preview', 'POST', preview)[0] == 200
    status, data = request(path, 'PUT', dict(rule, active=False), True, proof())
    check(status, 200, data)
    # A rejected coupon must release all tentative stock reservations.
    status, plain = checkout(str(uuid.uuid4()), dict(order, couponCode=None, lines=[{'sku': sku, 'quantity': 19}]))
    check(status, 201, plain)
    # Genuine sandbox payment and immutable persisted discount, including replay.
    status, intent = request('/api/v1/payments/orders/' + saved['id'] + '/intent', 'POST', {'receiptToken': saved['receiptToken']})
    assert status == 201 and intent['provider'] == 'Sandbox', (status, intent)
    for _ in range(2):
        status, paid = request('/api/v1/payments/sandbox/' + intent['authority'] + '/complete', 'POST', {'receiptToken': saved['receiptToken']})
        assert status == 200 and paid['state'] == 'Succeeded', (status, paid)
    status, persisted = request('/api/v1/checkout/orders/' + saved['id'], headers={'X-Order-Receipt-Token': saved['receiptToken']})
    assert status == 200 and persisted['state'] == 'Paid' and persisted['discount'] == 50000
    # Restore an inactive fixture and verify use/paid reporting (one redemption).
    status, listing = request('/api/v1/admin/promotions', auth=True)
    campaign = next(p for p in check(status, 200, listing) if p['code'] == PREFIX)
    assert campaign['uses'] == 1 and campaign['discountTotal'] == 50000, campaign
    print('Promotions: real DB, preview, auth/step-up, concurrent cap, rollback, idempotency, immutable snapshot, sandbox payment and reporting passed')


if __name__ == '__main__':
    process = None
    with tempfile.TemporaryFile() as log:
        try:
            if not os.environ.get('MAZEDUNEH_TEST_BASE'):
                process = subprocess.Popen(['dotnet', 'run', '--project', 'services/api/Mazeduneh.Api.csproj', '-c', 'Release', '--no-build', '--urls', BASE], cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
                for _ in range(60):
                    if process.poll() is not None:
                        raise AssertionError('Coupon fixture API exited')
                    try:
                        if request('/health/ready')[0] == 200:
                            break
                    except (URLError, TimeoutError):
                        pass
                    time.sleep(1)
            run()
        finally:
            if process:
                process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)
