"""HTTP PII regression on a disposable CI database. Never run against live data."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[2]
BASE = 'http://127.0.0.1:5110'
NAME, MOBILE, ADDRESS = 'PrivacyFixtureCustomer', '09120000199', 'PrivacyFixtureAddress'
SKU = 'CI-ORDER-PRIVACY'


def request(path, method='GET', body=None, token=None, headers=None):
    headers = dict(headers or {})
    if body is not None:
        headers['Content-Type'] = 'application/json'
    if token:
        headers['Authorization'] = 'Bearer ' + token
    try:
        response = urlopen(Request(BASE + path, method=method, headers=headers,
                           data=json.dumps(body).encode() if body is not None else None), timeout=8)
    except HTTPError as error:
        response = error
    with response:
        raw = response.read().decode('utf-8-sig')
        return response.status, json.loads(raw) if raw and 'json' in response.headers.get('Content-Type', '') else raw


def start_api(permissions=None):
    env = dict(os.environ, Admin__Role='Owner' if permissions is None else 'ReadOnlyAnalyst',
               Admin__Permissions='' if permissions is None else permissions)
    process = subprocess.Popen(['dotnet', 'run', '--project', 'services/api/Mazeduneh.Api.csproj',
                                '--configuration', 'Release', '--no-build', '--urls', BASE],
                               cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
    try:
        for _ in range(40):
            if process.poll() is not None:
                raise AssertionError('Privacy test API exited')
            try:
                if request('/health/ready')[0] == 200:
                    status, login = request('/api/v1/admin/auth/login', 'POST', {
                        'email': os.environ['Admin__Email'], 'password': 'Mazeduneh-CI-Owner-Password!'})
                    assert status == 200
                    return process, login['accessToken']
            except (URLError, TimeoutError):
                pass
            time.sleep(1)
        raise AssertionError('Privacy test API did not become ready')
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


def assert_private(payload):
    text = json.dumps(payload, ensure_ascii=False)
    for marker in [NAME, MOBILE, ADDRESS, '1234567890', 'PrivacyFixtureCarrier', 'PrivacyFixtureTracking']:
        assert marker not in text, 'PII leaked: ' + marker


with tempfile.TemporaryFile() as log:
    api, token = start_api()
    try:
        status, _ = request('/api/v1/products/', 'POST', {
            'title': 'CI privacy', 'slug': 'ci-order-privacy', 'category': 'CI', 'origin': 'IR',
            'currency': 'IRR', 'unitType': 'Weight', 'isPublished': True,
            'variants': [{'sku': SKU, 'quantity': 250, 'displayLabel': '250g', 'price': 5000, 'availablePackages': 0}]}, token)
        assert status == 201, status
        assert request('/api/v1/admin/inventory/batches', 'POST', {
            'sku': SKU, 'batchCode': 'CI-PRIVACY-LOT', 'receivedPackages': 10,
            'producedAt': '2025-01-01T00:00:00Z', 'expiresAt': '2030-01-01T00:00:00Z',
            'costPrice': 2000, 'packagingCost': 0, 'additionalCost': 0,
            'purchasedAt': '2026-01-01T00:00:00Z', 'supplier': 'CI supplier'}, token)[0] == 201
        status, created = request('/api/v1/checkout/orders', 'POST', {
            'customerName': NAME, 'mobile': MOBILE, 'province': 'تهران', 'city': 'تهران',
            'address': ADDRESS, 'postalCode': '1234567890', 'lines': [{'sku': SKU, 'quantity': 1}]},
            headers={'Idempotency-Key': 'ci-order-privacy-0001'})
        assert status == 201, (status, created)
        order_id = created['id']
        path = '/api/v1/admin/orders/' + order_id
        assert request(path + '/notes', 'POST', {'note': MOBILE + ' ' + ADDRESS}, token)[0] == 201
        assert request(path + '/shipping', 'PATCH', {'carrier': 'PrivacyFixtureCarrier',
            'trackingCode': 'PrivacyFixtureTracking', 'actualShippingCost': 100, 'reason': MOBILE}, token)[0] == 200
        for endpoint in [path + '/invoice', path + '/packing-slip']:
            status, html = request(endpoint, token=token)
            assert status == 200 and NAME in html and ADDRESS in html and MOBILE in html
        assert request(path, token=token)[1]['customerName'] == NAME
        assert request('/api/v1/admin/orders/export.csv?q=' + order_id, token=token)[0] == 200
        for endpoint in ['/api/v1/admin/orders', path, path + '/invoice', path + '/packing-slip', '/api/v1/admin/orders/export.csv']:
            assert request(endpoint)[0] == 401
    finally:
        stop_api(api)

    for permissions in ['orders.read', 'orders.read,orders.export',
                        'orders.read,orders.export,orders.documents.read', 'orders.export',
                        'orders.read,customers.pii.read', 'dashboard.read']:
        api, token = start_api(permissions)
        try:
            can_read = 'orders.read' in permissions.split(',')
            can_pii = 'customers.pii.read' in permissions.split(',')
            status, rows = request('/api/v1/admin/orders?q=' + order_id, token=token)
            assert status == (200 if can_read else 403)
            if can_read:
                assert len(rows) == 1
                status, detail = request(path, token=token)
                assert status == 200 and detail['lineCount'] == 1
                if not can_pii:
                    assert_private(rows)
                    assert_private(detail)
                    assert detail['notes'] == [] and detail['mobile'] == 'مخفی بر اساس نقش'
                    assert request('/api/v1/admin/orders?q=' + quote(MOBILE), token=token)[1] == []
                assert request('/api/v1/admin/orders/' + '00000000-0000-0000-0000-000000000001', token=token)[0] == 404
            for suffix in ['/invoice', '/packing-slip', '/invoice/', '/packing-slip/']:
                assert request(path + suffix, token=token)[0] == 403
            status, csv = request('/api/v1/admin/orders/export.csv?q=' + order_id, token=token)
            assert status == (200 if can_read and 'orders.export' in permissions.split(',') else 403)
            if status == 200 and not can_pii:
                assert_private(csv)
                assert 'مخفی بر اساس نقش' in csv
            status, overdue = request('/api/v1/admin/shipping/overdue', token=token)
            assert status == (200 if can_read else 403)
            if not can_pii:
                assert_private(overdue)
        finally:
            stop_api(api)

print('Direct HTTP order privacy, search, document/export role matrix passed')
