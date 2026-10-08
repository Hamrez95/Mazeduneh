"""Real API regression for zero-stock creation, variant addition and receiving."""
import json
from datetime import datetime, timedelta, timezone
import os
from pathlib import Path
import subprocess
import tempfile
import time
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[2]
BASE = "http://127.0.0.1:5106"
SLUG = "purchase-history-fixture"
ZERO, POSITIVE, ADDED = "CI-OPENING-ZERO", "CI-OPENING-POSITIVE", "CI-OPENING-ADDED"


def request(path, method="GET", body=None, token=None):
    headers = {"Content-Type": "application/json"} if body is not None else {}
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


def start_api():
    process = subprocess.Popen(["dotnet", "run", "--project", "services/api/Mazeduneh.Api.csproj",
                                "--configuration", "Release", "--no-build", "--urls", BASE],
                               cwd=ROOT, env=os.environ.copy(), stdout=log, stderr=subprocess.STDOUT)
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


with tempfile.TemporaryFile() as log:
    api, token = start_api()
    try:
        status, _ = request('/api/v1/products/', 'POST', {
            'title': 'CI purchase', 'slug': SLUG, 'category': 'CI', 'origin': 'IR', 'currency': 'IRR',
            'unitType': 'Weight', 'isPublished': True, 'variants': [
                {'sku': 'CI-PURCHASE-250', 'quantity': 250, 'displayLabel': '250g', 'price': 5000, 'availablePackages': 0, 'costPrice': 2222, 'packagingCost': 333, 'additionalCost': 44}]}, token)
        assert status == 201
        payload = {'sku': 'CI-PURCHASE-250', 'batchCode': 'CI-PURCHASE-ONE', 'receivedPackages': 12,
                   'producedAt': '2025-01-01T00:00:00Z', 'expiresAt': (datetime.now(timezone.utc) + timedelta(days=3)).isoformat(),
                   'costPrice': 4000, 'packagingCost': 500, 'additionalCost': 100,
                   'purchasedAt': '2026-01-01T00:00:00Z', 'supplier': 'CI supplier',
                   'supplierContactName': 'CI contact', 'supplierPhone': '+982100000000',
                   'supplierEmail': 'supplier@example.test', 'supplierAddress': 'Tehran wholesale market',
                   'supplierNotes': 'Deliver before noon'}
        status, first = request('/api/v1/admin/inventory/batches', 'POST', payload, token)
        assert status == 201, status
        assert first['purchaseTotal'] == 48000 and first['supplier'] == 'CI supplier'
        assert (first['supplierContactName'], first['supplierPhone'], first['supplierEmail'], first['supplierAddress'], first['supplierNotes']) == (
            'CI contact', '+982100000000', 'supplier@example.test', 'Tehran wholesale market', 'Deliver before noon')
        assert first['purchasedAt'].startswith('2026-01-01')
        assert request('/api/v1/admin/inventory/batches', 'POST', payload, token)[0] == 409
        payload.update(batchCode='CI-PURCHASE-TWO', costPrice=6000, purchasedAt='2026-02-01T00:00:00Z')
        assert request('/api/v1/admin/inventory/batches', 'POST', payload, token)[0] == 201
        status, dashboard = request('/api/v1/admin/dashboard?days=1', token=token)
        assert status == 200
        fixture_batches = {
            item['batchCode'] for item in dashboard['expiringSoon']
            if item['sku'] == 'CI-PURCHASE-250'
        }
        assert fixture_batches == {
            'CI-PURCHASE-ONE', 'CI-PURCHASE-TWO', 'CI-PURCHASE-THREE'
        }, fixture_batches
        from urllib.parse import quote
        history_path = '/api/v1/admin/inventory/purchases?sku=CI-PURCHASE-250&limit=1'
        status, page1 = request(history_path, token=token)
        assert status == 200 and len(page1['items']) == 1 and page1['items'][0]['costPrice'] == 6000
        status, exact_batch = request(
            '/api/v1/admin/inventory/purchases?sku=CI-PURCHASE-250&batchCode=CI-PURCHASE-TWO',
            token=token)
        assert status == 200 and [item['batchCode'] for item in exact_batch['items']] == ['CI-PURCHASE-TWO']
        status, batch_without_sku = request(
            '/api/v1/admin/inventory/purchases?batchCode=CI-PURCHASE-TWO',
            token=token)
        assert status == 200 and [item['batchCode'] for item in batch_without_sku['items']] == ['CI-PURCHASE-TWO']
        status, conflicting_filters = request(
            '/api/v1/admin/inventory/purchases?sku=OTHER-SKU&batchCode=CI-PURCHASE-TWO',
            token=token)
        assert status == 200 and conflicting_filters == {'items': [], 'nextCursor': None}
        assert page1['nextCursor']
        # New/backdated receipt inserted between pages must not move the cursor boundary.
        newer = dict(payload, batchCode='CI-PURCHASE-THREE', costPrice=8000, purchasedAt='2020-01-01T00:00:00Z')
        assert request('/api/v1/admin/inventory/batches','POST',newer,token)[0] == 201
        status, page2 = request(history_path+'&cursor='+quote(page1['nextCursor'],safe=''),token=token)
        assert status == 200 and len(page2['items']) == 1 and page2['items'][0]['id'] == first['id']
        assert page2['nextCursor'] is None
        status, refresh = request(history_path,token=token)
        assert refresh['items'][0]['costPrice'] == 8000
        status, missing_sku = request('/api/v1/admin/inventory/purchases?sku=OTHER-SKU&limit=1&cursor='+quote(page1['nextCursor'],safe=''),token=token)
        assert status == 200 and missing_sku == {'items': [], 'nextCursor': None}, missing_sku
        assert request(history_path+'&cursor=invalid',token=token)[0] == 400
        assert request('/api/v1/admin/inventory/purchases?limit=251',token=token)[0] == 400
        assert request(history_path)[0] == 401
        for change in [{'purchasedAt': '2099-01-01T00:00:00Z'}, {'supplier': ''}, {'supplier': 'x'*201},
                       {'supplierEmail': 'not-an-email'}, {'supplierPhone': 'x'*41},
                       {'supplierAddress': 'x'*501}, {'supplierNotes': 'x'*1001},
                       {'supplierContactName': 'x'*201}, {'costPrice': -1}, {'receivedPackages': 0}, {'batchCode': 'x'*81}]: 
            assert request('/api/v1/admin/inventory/batches', 'POST', dict(payload, **change), token)[0] == 400
        assert request('/api/v1/admin/inventory/batches', 'POST', payload)[0] == 401
        status, movements = request('/api/v1/admin/inventory/movements?sku=CI-PURCHASE-250', token=token)
        assert status == 200 and len(movements) == 3
        assert all(m['actor'] == os.environ['Admin__Email'] for m in movements)
        status, audit = request('/api/v1/admin/audit-log?entityType=InventoryBatch&entityId='+first['id'], token=token)
        assert status == 200 and len(audit) == 1
        assert audit[0]['actor'] == os.environ['Admin__Email'] and audit[0]['beforeJson'] is None
        after = json.loads(audit[0]['afterJson'])
        assert (after.get('PurchaseTotal', after.get('purchaseTotal'))) == 48000
        assert after.get('SupplierContactName', after.get('supplierContactName')) == 'CI contact'
        assert after.get('SupplierPhone', after.get('supplierPhone')) == '+982100000000'
    finally:
        stop_api(api)
    api, token = start_api()
    try:
        status, history = request('/api/v1/admin/inventory/batches?sku=CI-PURCHASE-250', token=token)
        assert status == 200 and len(history) == 3
        assert history[-1]['supplierEmail'] == 'supplier@example.test'
        assert {item['costPrice'] for item in history} == {4000,6000,8000}
        assert sum(item['receivedPackages'] for item in history) == 36
        status, product = request('/api/v1/products/'+SLUG)
        assert status == 200 and product['variants'][0]['price'] == 5000
        assert product['variants'][0]['availablePackages'] == 36
        assert all(product['variants'][0][key] == 0 for key in ['costPrice','packagingCost','additionalCost'])
        _, private = request('/api/v1/products/admin', token=token)
        variant = next(p for p in private if p['slug'] == SLUG)['variants'][0]
        assert variant['costPrice'] == 2222 and variant['packagingCost'] == 333
    finally:
        stop_api(api)
print('Purchase history, duplicate safety, actor/audit, validation and restart passed')
