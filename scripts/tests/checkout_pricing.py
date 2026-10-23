"""Real database pricing, payment, stock and report reconciliation for launch.

Run against a migrated, demo-seeded disposable database, using the CI auth env.
Each fixture is unique. Never point this contract at a customer database.
"""
import concurrent.futures
import json
from html import unescape
import os
from pathlib import Path
import subprocess
import tempfile
import time
import uuid
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[2]
BASE = 'http://127.0.0.1:5113'
PASSWORD = 'Mazeduneh-CI-Owner-Password!'
token = None


def request(path, method='GET', body=None, headers=None, raw=False):
    h = {'Content-Type': 'application/json'}
    if token:
        h['Authorization'] = 'Bearer ' + token
    h.update(headers or {})
    try:
        response = urlopen(Request(BASE + path, method=method, headers=h,
            data=json.dumps(body).encode() if body is not None else None), timeout=15)
    except HTTPError as error:
        response = error
    with response:
        data = response.read()
        return response.status, data.decode('utf-8-sig') if raw else json.loads(data) if data else None


def expect(expected, result):
    status, body = result
    assert status == expected, (expected, status, body)
    return body


with tempfile.TemporaryFile() as log:
    api = subprocess.Popen(['dotnet', 'run', '--project', 'services/api/Mazeduneh.Api.csproj',
        '--configuration', 'Release', '--no-build', '--urls', BASE], cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
    try:
        for _ in range(60):
            if api.poll() is not None:
                raise AssertionError('Pricing test API exited')
            try:
                if request('/health/ready')[0] == 200:
                    break
            except (URLError, TimeoutError, ConnectionError):
                pass
            time.sleep(1)
        token = expect(200, request('/api/v1/admin/auth/login', 'POST',
            {'email': os.environ['Admin__Email'], 'password': PASSWORD}))['accessToken']
        proof = {'X-Admin-Step-Up': expect(200, request('/api/v1/admin/auth/step-up', 'POST', {'password': PASSWORD}))['stepUpToken']}
        prefix = 'RECON-' + uuid.uuid4().hex[:8].upper()
        a, b = prefix + '-250', prefix + '-500'
        product = {'title': 'محصول تطبیق حسابداری', 'slug': prefix.lower(), 'category': prefix,
            'origin': 'ایران', 'currency': 'IRR', 'unitType': 'Weight', 'isPublished': True,
            'variants': [
                {'sku': a, 'quantity': 250, 'displayLabel': '۲۵۰ گرم', 'price': 2000000, 'availablePackages': 0},
                {'sku': b, 'quantity': 500, 'displayLabel': '۵۰۰ گرم', 'price': 3800000, 'availablePackages': 0}]}
        expect(201, request('/api/v1/products/', 'POST', product, proof))
        for sku, cost, packaging in [(a, 1000000, 100000), (b, 2000000, 150000)]:
            expect(201, request('/api/v1/admin/inventory/batches', 'POST', {
                'sku': sku, 'batchCode': sku, 'receivedPackages': 5, 'producedAt': '2026-01-01T00:00:00Z',
                'expiresAt': '2030-01-01T00:00:00Z', 'costPrice': cost, 'packagingCost': packaging,
                'additionalCost': 50000, 'purchasedAt': '2026-01-01T00:00:00Z', 'supplier': 'Prelaunch fixture'}))
        settings = {'taxRatePercent': 9.5, 'shippingMethods': [
            {'code': 'post', 'title': 'پست', 'price': 321000, 'freeAbove': 9000000, 'isActive': True, 'internalCost': 111000},
            {'code': 'pickup', 'title': 'تحویل حضوری', 'price': 0, 'freeAbove': 0, 'isActive': True, 'internalCost': 0}]}
        expect(200, request('/api/v1/admin/commerce/settings', 'PUT', settings, proof))
        public_settings = expect(200, request('/api/v1/commerce/shipping-methods'))
        assert public_settings['taxRatePercent'] == 9.5 and 'internalCost' not in json.dumps(public_settings)
        lines = [{'sku': a, 'quantity': 1}, {'sku': b, 'quantity': 1}]
        for method, shipping, payable in [('post', 321000, 6672000), ('pickup', 0, 6351000)]:
            quote = expect(200, request('/api/v1/checkout/coupon-preview', 'POST', {'code': '', 'shippingMethod': method, 'lines': lines}))
            assert (quote['subtotal'], quote['tax'], quote['shipping'], quote['payable']) == (5800000, 551000, shipping, payable), quote
        order_payload = {'customerName': 'تست تطبیق', 'mobile': '09128880000', 'province': 'تهران', 'city': 'تهران',
            'address': 'نشانی مصنوعی آزمون', 'postalCode': '1234567890', 'shippingMethod': 'post', 'lines': lines,
            'price': 1, 'payable': 1, 'tax': 0, 'discount': 999999999}
        key = str(uuid.uuid4())
        def checkout(_):
            return request('/api/v1/checkout/orders', 'POST', order_payload, {'Idempotency-Key': key})
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            responses = list(pool.map(checkout, range(2)))
        assert sorted(status for status, _ in responses) == [200, 201], responses
        order = responses[0][1]
        assert responses[1][1]['id'] == order['id']
        assert (order['subtotal'], order['tax'], order['shipping'], order['payable']) == (5800000, 551000, 321000, 6672000), order
        receipt = {'X-Order-Receipt-Token': order['receiptToken']}
        payment_body = {'receiptToken': order['receiptToken']}
        intent = expect(201, request(f"/api/v1/payments/orders/{order['id']}/intent", 'POST', payment_body))
        for _ in range(2):
            expect(200, request(f"/api/v1/payments/sandbox/{intent['authority']}/complete", 'POST', payment_body))
        expect(201, request(f"/api/v1/admin/orders/{order['id']}/internal-costs", 'POST', {'title': 'سمپل هدیه', 'amount': 50000}))
        public_order = expect(200, request(f"/api/v1/checkout/orders/{order['id']}", headers=receipt))
        assert public_order['state'] == 'Paid' and public_order['payable'] == 6672000
        assert not any(key in public_order for key in ['internalCosts', 'cost', 'netProfit'])
        admin_order = expect(200, request(f"/api/v1/admin/orders/{order['id']}"))
        assert len(admin_order['lines']) == 2 and len(admin_order['internalCosts']) == 1
        analytics = expect(200, request('/api/v1/admin/analytics?days=30'))
        for field, expected in [('orderCount', 1), ('unitsSold', 2), ('merchandiseRevenue', 5800000),
                ('productCost', 3000000), ('packagingCost', 250000), ('additionalCost', 100000),
                ('shippingRevenue', 321000), ('shippingExpense', 111000), ('tax', 551000),
                ('orderInternalCosts', 50000), ('netProfit', 2610000)]:
            assert analytics[field] == expected, (field, expected, analytics[field])
        rows = expect(200, request('/api/v1/admin/analytics/products?days=30'))
        assert len(rows) == 2 and sum(row['unitsSold'] for row in rows) == 2
        assert sum(row['quantitySold'] for row in rows) == 750
        invoice = expect(200, request(f"/api/v1/checkout/orders/{order['id']}/invoice", headers=receipt, raw=True))
        assert '۶۶۷,۲۰۰' in unescape(invoice) and 'سمپل هدیه' not in unescape(invoice) and order['receiptToken'] not in invoice
        settings['taxRatePercent'] = 0
        settings['shippingMethods'][0]['price'] = 0
        expect(200, request('/api/v1/admin/commerce/settings', 'PUT', settings, proof))
        replay = expect(200, checkout(None))
        assert replay['id'] == order['id'] and replay['payable'] == 6672000
        catalog = expect(200, request('/api/v1/products/' + prefix.lower()))
        assert [v['availablePackages'] for v in catalog['variants']] == [4, 4]
        for path, method, body in [
            ('/api/v1/products/', 'POST', dict(product, variants=[None])),
            ('/api/v1/products/', 'POST', dict(product, currency='USD')),
            ('/api/v1/products/', 'POST', dict(product, variants=[dict(product['variants'][0], price=1.001)])),
            ('/api/v1/products/', 'POST', dict(product, unitType='Count', variants=[dict(product['variants'][0], quantity=1.5)])),
            ('/api/v1/admin/commerce/settings', 'PUT', dict(settings, shippingMethods=[None])),
            ('/api/v1/admin/commerce/settings', 'PUT', dict(settings, shippingMethods=[dict(settings['shippingMethods'][0], code=None)])),
            ('/api/v1/checkout/orders', 'POST', dict(order_payload, lines=[None])),
            ('/api/v1/checkout/coupon-preview', 'POST', {'code': '', 'lines': [None]})]:
            status, body = request(path, method, body, dict(proof, **{'Idempotency-Key': str(uuid.uuid4())}))
            assert status == 400, (path, status, body)
        print('Checkout reconciliation: live settings, units, tax, shipping, forged totals, concurrent replay, payment replay, stock, internal costs, reports, invoice and invalid inputs passed')
    finally:
        api.terminate()
        try:
            api.wait(timeout=10)
        except subprocess.TimeoutExpired:
            api.kill()
            api.wait(timeout=5)
