"""HTTP PII regression on a disposable CI database. Never run against live data."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
from datetime import datetime, timedelta
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[2]
BASE = 'http://127.0.0.1:5110'
NAME, MOBILE, ADDRESS = 'PrivacyFixtureCustomer', '09120000199', 'PrivacyFixtureAddress'
SKU = 'CI-ORDER-PRIVACY'


def request(path, method='GET', body=None, token=None, headers=None, include_response_headers=False):
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
        result = json.loads(raw) if raw and 'json' in response.headers.get('Content-Type', '') else raw
        return (response.status, result, response.headers) if include_response_headers else (response.status, result)


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


def step_up_token(token):
    status, response = request('/api/v1/admin/auth/step-up', 'POST',
                               {'password': 'Mazeduneh-CI-Owner-Password!'}, token)
    assert status == 200, response
    return response['stepUpToken']


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
            'variants': [{'sku': SKU, 'quantity': 250, 'displayLabel': '250g', 'price': 5000, 'availablePackages': 0}]},
            token, headers={'X-Admin-Step-Up': step_up_token(token)})
        assert status == 201, status
        assert request('/api/v1/admin/inventory/batches', 'POST', {
            'sku': SKU, 'batchCode': 'CI-PRIVACY-LOT', 'receivedPackages': 10,
            'producedAt': '2025-01-01T00:00:00Z', 'expiresAt': '2030-01-01T00:00:00Z',
            'costPrice': 2000, 'packagingCost': 0, 'additionalCost': 0,
            'purchasedAt': '2026-01-01T00:00:00Z', 'supplier': 'CI supplier'}, token)[0] == 201
        checkout_payload = {
            'customerName': NAME, 'mobile': MOBILE, 'province': 'تهران', 'city': 'تهران',
            'address': ADDRESS, 'postalCode': '1234567890', 'lines': [{'sku': SKU, 'quantity': 1}],
            'marketingConsent': True,
        }
        status, created = request('/api/v1/checkout/orders', 'POST', checkout_payload,
                                  headers={'Idempotency-Key': 'ci-order-privacy-0001'})
        assert status == 201, (status, created)
        order_id = created['id']
        receipt_token = created['receiptToken']
        public_order_path = '/api/v1/checkout/orders/' + order_id
        assert request(public_order_path)[0] == 404
        assert request(public_order_path + '?receiptToken=invalid-receipt-token')[0] == 404
        assert request(public_order_path, headers={'X-Order-Receipt-Token': 'invalid-receipt-token'})[0] == 404
        status, public_order, public_headers = request(
            public_order_path, headers={'X-Order-Receipt-Token': receipt_token}, include_response_headers=True)
        assert status == 200 and public_order['id'] == order_id
        assert public_order.get('receiptToken') == ''
        assert public_headers.get('Cache-Control') == 'no-store'
        public_invoice_path = public_order_path + '/invoice'
        assert request(public_invoice_path)[0] == 404
        assert request(public_invoice_path + '?receiptToken=invalid-receipt-token')[0] == 404
        invoice_status, invoice_html, invoice_headers = request(
            public_invoice_path, headers={'X-Order-Receipt-Token': receipt_token}, include_response_headers=True)
        assert invoice_status == 200 and NAME in invoice_html and MOBILE not in invoice_html
        assert invoice_headers.get('Cache-Control') == 'no-store'

        replay_status, replayed = request('/api/v1/checkout/orders', 'POST', checkout_payload,
                                          headers={'Idempotency-Key': 'ci-order-privacy-0001'})
        assert replay_status == 200 and replayed['id'] == order_id
        customer_status, customers = request('/api/v1/admin/customers/?q=' + quote(MOBILE), token=token)
        assert customer_status == 200 and len(customers) == 1, (customer_status, customers)
        customer_id = customers[0]['id']
        assert customers[0]['marketingConsent'] is True

        profile_path = '/api/v1/admin/customers/' + customer_id
        profile_status, customer = request(profile_path, token=token)
        assert profile_status == 200 and customer['marketingConsent'] is True, (profile_status, customer)
        consent_events = customer['consentHistory']
        assert len(consent_events) == 1
        assert consent_events[0]['granted'] is True
        assert consent_events[0]['source'] == 'guest_checkout'
        assert consent_events[0]['policyVersion'] == 'marketing-v1'

        revoke_path = '/api/v1/checkout/orders/' + order_id + '/marketing-consent/revoke'
        assert request(revoke_path, 'POST', {'receiptToken': 'invalid-receipt-token'})[0] == 404
        assert request(revoke_path, 'POST', {'receiptToken': created['receiptToken']})[0] == 204
        assert request(revoke_path, 'POST', {'receiptToken': created['receiptToken']})[0] == 204
        profile_status, customer = request(profile_path, token=token)
        assert profile_status == 200 and customer['marketingConsent'] is False
        consent_events = customer['consentHistory']
        assert len(consent_events) == 2
        assert {event['granted'] for event in consent_events} == {True, False}
        assert any(event['source'] == 'receipt_self_service' and not event['granted'] for event in consent_events)

        order_created_at = datetime.fromisoformat(created['createdAt'].replace('Z', '+00:00'))
        range_start = quote((order_created_at - timedelta(seconds=1)).isoformat())
        range_end = quote((order_created_at + timedelta(seconds=1)).isoformat())
        status, range_orders = request('/api/v1/admin/orders?from=' + range_start + '&to=' + range_end, token=token)
        assert status == 200 and [row['id'] for row in range_orders] == [order_id], (status, range_orders)
        assert request('/api/v1/admin/orders?from=' + range_start, token=token)[0] == 400
        too_long_start = quote('2024-01-01T00:00:00+00:00')
        too_long_end = quote('2025-02-01T00:00:00+00:00')
        assert request('/api/v1/admin/orders?from=' + too_long_start + '&to=' + too_long_end, token=token)[0] == 400
        _, second = request('/api/v1/checkout/orders', 'POST', {
            'customerName': NAME, 'mobile': MOBILE, 'province': 'تهران', 'city': 'تهران',
            'address': ADDRESS, 'postalCode': '1234567890', 'lines': [{'sku': SKU, 'quantity': 1}]},
            headers={'Idempotency-Key': 'ci-order-privacy-0002'})
        assert request(profile_path, token=token)[1]['marketingConsent'] is False
        assert len(request(profile_path, token=token)[1]['consentHistory']) == 2
        _, intent = request('/api/v1/payments/orders/' + order_id + '/intent', 'POST', {'receiptToken': created['receiptToken']})
        assert request('/api/v1/payments/sandbox/' + intent['authority'] + '/complete', 'POST', {'receiptToken': created['receiptToken']})[0] == 200
        status, ranged_analytics = request('/api/v1/admin/analytics?from=' + range_start + '&to=' + range_end, token=token)
        assert status == 200 and ranged_analytics['orderCount'] == 1 and ranged_analytics['revenue'] > 0, (status, ranged_analytics)
        status, ranged_products = request('/api/v1/admin/analytics/products?from=' + range_start + '&to=' + range_end, token=token)
        assert status == 200 and any(row['sku'] == SKU for row in ranged_products), (status, ranged_products)
        assert request('/api/v1/admin/analytics?from=' + range_start, token=token)[0] == 400
        status, processing_orders = request('/api/v1/admin/orders?state=Processing&q=' + order_id, token=token)
        assert status == 200 and len(processing_orders) == 1 and processing_orders[0]['state'] == 'Paid'
        status, sku_orders = request('/api/v1/admin/orders?q=' + SKU, token=token)
        assert status == 200 and any(row['id'] == order_id for row in sku_orders), (status, sku_orders)
        path = '/api/v1/admin/orders/' + order_id
        assert request(path + '/notes', 'POST', {'note': MOBILE + ' ' + ADDRESS}, token)[0] == 201
        shipping_request = {'carrier': 'PrivacyFixtureCarrier', 'trackingCode': 'PrivacyFixtureTracking',
                            'actualShippingCost': 100, 'reason': MOBILE}
        assert request(path + '/shipping', 'PATCH', shipping_request, token)[0] == 428
        shipping_proof = step_up_token(token)
        status, shipping_detail = request(path + '/shipping', 'PATCH', shipping_request, token,
                                          headers={'X-Admin-Step-Up': shipping_proof})
        assert status == 200 and shipping_detail['shippingExpense'] == 100
        for state in ['Preparing', 'Shipped']:
            assert request(path + '/state', 'PATCH', {'state': state, 'reason': MOBILE}, token)[0] == 200
            if state == 'Preparing':
                status, processing_orders = request('/api/v1/admin/orders?state=Processing&q=' + order_id, token=token)
                assert status == 200 and len(processing_orders) == 1 and processing_orders[0]['state'] == 'Preparing'
        subprocess.run(['dotnet', 'run', '--project', 'services/api.tests/Mazeduneh.Api.Tests.csproj',
                        '--configuration', 'Release', '--', '--backdate-privacy-shipment', order_id],
                       cwd=ROOT, env=dict(os.environ, MAZEDUNEH_TEST_FIXTURES='true'), check=True)
        assert any(row['id'] == order_id for row in request('/api/v1/admin/shipping/overdue', token=token)[1])
        for endpoint in [path + '/invoice', path + '/packing-slip']:
            status, html = request(endpoint, token=token)
            assert status == 200 and NAME in html
            if endpoint.endswith('/packing-slip'):
                assert ADDRESS in html
            # Existing invoice/slip renderers do not print the mobile number.
        assert request(path, token=token)[1]['customerName'] == NAME
        export_proof = step_up_token(token)
        assert request('/api/v1/admin/orders/export.csv?q=' + order_id, token=token,
                       headers={'X-Admin-Step-Up': export_proof})[0] == 200
        status, ranged_csv = request('/api/v1/admin/orders/export.csv?from=' + range_start + '&to=' + range_end,
                                     token=token, headers={'X-Admin-Step-Up': export_proof})
        assert status == 200 and order_id in ranged_csv, (status, ranged_csv)
        for endpoint in ['/api/v1/admin/orders', path, path + '/invoice', path + '/packing-slip', '/api/v1/admin/orders/export.csv']:
            assert request(endpoint)[0] == 401
        status, order_audit = request('/api/v1/admin/audit-log?entityType=Order&entityId=' + order_id, token=token)
        assert status == 200 and any(item['action'] == 'order.shipping-updated' for item in order_audit)
        assert any('PrivacyFixtureTracking' in (item['afterJson'] or '') for item in order_audit)
    finally:
        stop_api(api)

    for permissions in ['orders.read', 'orders.read,orders.export',
                        'orders.read,orders.export,orders.documents.read', 'orders.export',
                        'orders.read,customers.pii.read', 'orders.documents.read,customers.pii.read',
                        'dashboard.read', 'orders.read,orders.write', 'audit.read',
                        'audit.read,customers.pii.read']:
        api, token = start_api(permissions)
        try:
            can_read = 'orders.read' in permissions.split(',')
            can_pii = 'customers.pii.read' in permissions.split(',')
            can_read_audit = 'audit.read' in permissions.split(',')
            if can_read_audit:
                status, audit = request('/api/v1/admin/audit-log?entityType=Order&entityId=' + order_id, token=token)
                assert status == (200 if can_pii else 403)
                if can_pii:
                    assert any('PrivacyFixtureTracking' in (item['afterJson'] or '') for item in audit)
                status, audit = request('/api/v1/admin/audit-log', token=token)
                assert status == (200 if can_pii else 403)
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
            export_allowed = can_read and 'orders.export' in permissions.split(',')
            expected_export_status = 428 if export_allowed else 403
            assert request('/api/v1/admin/orders/export.csv/?q=' + order_id, token=token)[0] == expected_export_status
            status, csv = request('/api/v1/admin/orders/export.csv?q=' + order_id, token=token)
            assert status == expected_export_status
            if export_allowed:
                status, csv = request('/api/v1/admin/orders/export.csv?q=' + order_id, token=token,
                                      headers={'X-Admin-Step-Up': step_up_token(token)})
                assert status == 200
            if status == 200 and not can_pii:
                assert_private(csv)
                assert 'مخفی بر اساس نقش' in csv
            status, overdue = request('/api/v1/admin/shipping/overdue', token=token)
            assert status == (200 if can_read else 403)
            if not can_pii:
                assert_private(overdue)
            if can_read:
                assert any(row['id'] == order_id for row in overdue), 'Nonempty overdue fixture missing'
            if 'orders.write' in permissions.split(','):
                status, note = request(path + '/notes', 'POST', {'note': ADDRESS}, token)
                assert status == 201
                assert_private(note)
                status, shipping = request(path + '/shipping', 'PATCH', {'carrier': NAME, 'trackingCode': MOBILE,
                    'updateActualShippingCost': False, 'reason': ADDRESS}, token)
                assert status == 200 and shipping['shippingExpense'] == 100
                assert_private(shipping)
                status, changed = request(path + '/state', 'PATCH', {'state': 'Delivered', 'reason': MOBILE}, token)
                assert status == 200
                assert_private(changed)
                bulk_request = {'orderIds': [second['id']], 'state': 'Cancelled', 'reason': ADDRESS}
                status, _ = request('/api/v1/admin/orders/bulk-state', 'POST', bulk_request, token)
                assert status == 428, (status, _)
                status, bulk = request('/api/v1/admin/orders/bulk-state', 'POST', bulk_request, token,
                                       headers={'X-Admin-Step-Up': step_up_token(token)})
                assert status == 200 and len(bulk['updated']) == 1
                assert_private(bulk)
                status, problem_orders = request('/api/v1/admin/orders?state=Problem&q=' + second['id'], token=token)
                assert status == 200 and len(problem_orders) == 1 and problem_orders[0]['state'] == 'Cancelled'
                assert request('/api/v1/admin/orders?state=Unknown&q=' + second['id'], token=token)[0] == 400
        finally:
            stop_api(api)

    for permissions, expected_matches in [('customers.read', 0), ('customers.read,customers.pii.read', 1)]:
        api, token = start_api(permissions)
        try:
            status, customers = request('/api/v1/admin/customers/?q=' + MOBILE, token=token)
            assert status == 200 and len(customers) == expected_matches, (status, customers)
            if expected_matches:
                assert customers[0]['mobile'] == MOBILE
            status, customers = request('/api/v1/admin/customers/?q=' + quote(NAME), token=token)
            assert status == 200 and len(customers) == expected_matches, (status, customers)
        finally:
            stop_api(api)

print('Direct HTTP order and customer privacy, search, document/export role matrix passed')
