"""Inventory invariants against the disposable CI PostgreSQL database."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
from concurrent.futures import ThreadPoolExecutor
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[2]
BASE = 'http://127.0.0.1:5111'
LEGACY, BATCHED, UPGRADE, ACTOR_SCOPED = (
    'CI-ADJUST-LEGACY', 'CI-ADJUST-BATCH', 'CI-ADJUST-UPGRADE', 'CI-ADJUST-ACTOR')


def request(path, method='GET', body=None, token=None, key=None):
    headers = {'Content-Type': 'application/json'} if body is not None else {}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    if key:
        headers['Idempotency-Key'] = key
    try:
        response = urlopen(Request(BASE + path, method=method, headers=headers,
                                   data=json.dumps(body).encode() if body is not None else None), timeout=15)
    except HTTPError as error:
        response = error
    with response:
        raw = response.read()
        return response.status, json.loads(raw) if raw and 'json' in response.headers.get('Content-Type', '') else None


def start_api(email=None):
    process = subprocess.Popen(['dotnet', 'run', '--project', 'services/api/Mazeduneh.Api.csproj',
                                '--configuration', 'Release', '--no-build', '--urls', BASE],
                               cwd=ROOT, env=os.environ.copy(), stdout=log, stderr=subprocess.STDOUT)
    try:
        for _ in range(40):
            if process.poll() is not None:
                raise AssertionError('Inventory invariant test API exited')
            try:
                if request('/health/ready')[0] == 200:
                    status, login = request('/api/v1/admin/auth/login', 'POST', {
                        'email': email or os.environ['Admin__Email'], 'password': 'Mazeduneh-CI-Owner-Password!'})
                    assert status == 200
                    return process, login['accessToken']
            except (URLError, TimeoutError):
                pass
            time.sleep(1)
        raise AssertionError('Inventory invariant test API not ready')
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


def adjust(sku, delta, key, auth_token=None):
    return request('/api/v1/admin/inventory/adjust', 'POST', {'sku': sku, 'quantityDelta': delta, 'reason': 'CI invariant'}, auth_token or token, key)


def balances(sku):
    _, product = request('/api/v1/products/ci-adjustment-invariant')
    available = next(v['availablePackages'] for v in product['variants'] if v['sku'] == sku)
    _, batches = request('/api/v1/admin/inventory/batches?sku=' + sku, token=token)
    _, movements = request('/api/v1/admin/inventory/movements?sku=' + sku, token=token)
    _, audit = request('/api/v1/admin/audit-log?entityType=ProductVariant&entityId=' + sku, token=token)
    return available, sum(b['remainingPackages'] for b in batches), len(movements), len(audit)


def reserve_lines(key, lines):
    return request('/api/v1/checkout/orders', 'POST', {'customerName': 'InventoryFixture', 'mobile': '09120000198',
        'province': 'Tehran', 'city': 'Tehran', 'address': 'CI disposable', 'postalCode': '1234567890',
        'lines': lines}, key=key)


def reserve(key, quantity=1, sku=BATCHED):
    return reserve_lines(key, [{'sku': sku, 'quantity': quantity}])


def cancel(order):
    return request('/api/v1/admin/orders/' + order['id'] + '/state', 'PATCH', {'state': 'Cancelled', 'reason': 'CI release'}, token)


def expire_fixture_reservation(order_id):
    environment = os.environ.copy()
    environment['MAZEDUNEH_TEST_FIXTURES'] = 'true'
    subprocess.run(['dotnet', 'run', '--project', 'services/api.tests/Mazeduneh.Api.Tests.csproj',
                    '--configuration', 'Release', '--no-build', '--',
                    '--expire-inventory-fixture-reservation', order_id],
                   cwd=ROOT, env=environment, check=True, timeout=45)


with tempfile.TemporaryFile() as log:
    api, token = start_api()
    try:
        status, _ = request('/api/v1/products/', 'POST', {
            'title': 'CI invariant', 'slug': 'ci-adjustment-invariant', 'category': 'CI', 'origin': 'IR',
            'currency': 'IRR', 'unitType': 'Weight', 'isPublished': True, 'variants': [
                {'sku': sku, 'quantity': 250, 'displayLabel': sku, 'price': 5000, 'availablePackages': 0}
                for sku in [LEGACY, BATCHED, UPGRADE, ACTOR_SCOPED]]}, token)
        assert status == 201, status
        assert request('/api/v1/admin/inventory/adjust', 'POST', {'sku': LEGACY, 'quantityDelta': 1, 'reason': 'missing key'}, token)[0] == 400
        assert adjust(LEGACY, 10, 'ci-adjust-opening')[0] == 200
        opening = balances(LEGACY)
        assert opening == (10, 0, 1, 1), opening

        invitation_status, invitation = request('/api/v1/admin/users', 'POST', {
            'email': 'ci-inventory-operator@mazeduneh.test', 'displayName': 'CI inventory operator',
            'role': 'WarehouseOperator'}, token)
        assert invitation_status == 201, (invitation_status, invitation)
        assert request('/api/v1/admin/auth/accept-invite', 'POST', {
            'token': invitation['invitationToken'], 'password': 'Mazeduneh-CI-Operator-Password!'} )[0] == 204
        operator_status, operator_login = request('/api/v1/admin/auth/login', 'POST', {
            'email': 'ci-inventory-operator@mazeduneh.test', 'password': 'Mazeduneh-CI-Operator-Password!'})
        assert operator_status == 200, (operator_status, operator_login)
        actor_key = 'ci-adjust-actor-scope'
        assert adjust(ACTOR_SCOPED, 5, actor_key)[0] == 200
        assert adjust(ACTOR_SCOPED, 5, actor_key, operator_login['accessToken'])[0] == 200
        assert balances(ACTOR_SCOPED) == (10, 0, 2, 2)
        owner_replay_status, owner_replay = adjust(ACTOR_SCOPED, 5, actor_key)
        assert owner_replay_status == 200 and owner_replay['balanceAfter'] == 5
        assert balances(ACTOR_SCOPED) == (10, 0, 2, 2)
        _, actor_movements = request('/api/v1/admin/inventory/movements?sku=' + ACTOR_SCOPED, token=token)
        assert {item['actor'] for item in actor_movements} == {
            os.environ['Admin__Email'], 'ci-inventory-operator@mazeduneh.test'}

        # Concurrent duplicate requests write once; changed payload conflicts.
        with ThreadPoolExecutor(max_workers=4) as pool:
            results = list(pool.map(lambda _: adjust(LEGACY, -2, 'ci-adjust-replay'), range(4)))
        assert all(status == 200 for status, _ in results)
        assert all(body['balanceAfter'] == 8 for _, body in results)
        assert balances(LEGACY) == (8, 0, 2, 2)
        assert adjust(LEGACY, -3, 'ci-adjust-replay')[0] == 409
        oversell_status, oversell_body = adjust(LEGACY, -9, 'ci-adjust-oversell')
        assert oversell_status == 409, (oversell_status, oversell_body)
        assert balances(LEGACY) == (8, 0, 2, 2)
        for invalid in [0, 1.5, 'NaN', 'Infinity', 1_000_001, -1_000_001, 2_147_483_648]:
            assert adjust(LEGACY, invalid, 'ci-adjust-invalid')[0] in [400, 409], invalid
        assert balances(LEGACY) == (8, 0, 2, 2)
        assert adjust(LEGACY, -8, 'ci-adjust-empty')[0] == 200
        assert adjust(LEGACY, -1, 'ci-adjust-negative')[0] == 409
        assert balances(LEGACY)[0] == 0

        # The first batch cannot strand legacy stock, including units held by an unpaid order.
        assert adjust(UPGRADE, 3, 'ci-upgrade-opening')[0] == 200
        batch_receipt = {'sku': UPGRADE, 'batchCode': 'CI-UPGRADE-LOT', 'receivedPackages': 2,
            'producedAt': '2025-01-01T00:00:00Z', 'expiresAt': '2030-01-01T00:00:00Z',
            'costPrice': 1000, 'supplier': 'CI supplier'}
        status, cancelled_legacy_order = reserve('ci-upgrade-cancel-reservation', 3, UPGRADE)
        assert status == 201
        assert balances(UPGRADE)[:2] == (0, 0)
        assert request('/api/v1/admin/inventory/batches', 'POST', batch_receipt, token)[0] == 409
        assert cancel(cancelled_legacy_order)[0] == 200
        assert balances(UPGRADE)[:2] == (3, 0)
        assert request('/api/v1/admin/inventory/batches', 'POST', batch_receipt, token)[0] == 409
        status, expired_legacy_order = reserve('ci-upgrade-expire-reservation', 3, UPGRADE)
        assert status == 201
        expire_fixture_reservation(expired_legacy_order['id'])
        assert balances(UPGRADE)[:2] == (3, 0)
        assert request('/api/v1/admin/inventory/batches', 'POST', batch_receipt, token)[0] == 409
        # Only after cancellation and expiry leave no legacy reservation can the first batch be received.
        status, old_order = reserve('ci-upgrade-drain', 3, UPGRADE)
        assert status == 201
        _, payment = request('/api/v1/payments/orders/' + old_order['id'] + '/intent', 'POST',
            {'receiptToken': old_order['receiptToken']})
        assert request('/api/v1/payments/sandbox/' + payment['authority'] + '/complete', 'POST',
            {'receiptToken': old_order['receiptToken']})[0] == 200
        assert request('/api/v1/admin/inventory/batches', 'POST', batch_receipt, token)[0] == 201
        assert balances(UPGRADE)[:2] == (2, 2)

        assert request('/api/v1/admin/inventory/batches', 'POST', {
            'sku': BATCHED, 'batchCode': 'CI-INVARIANT-LOT', 'receivedPackages': 10,
            'producedAt': '2025-01-01T00:00:00Z', 'expiresAt': '2030-01-01T00:00:00Z',
            'costPrice': 1000, 'supplier': 'CI supplier'}, token)[0] == 201
        before = balances(BATCHED)
        assert before[:3] == (10, 10, 1), before
        for delta in [-2, 2]:
            assert adjust(BATCHED, delta, 'ci-adjust-batch-' + str(abs(delta)))[0] == 409
            assert balances(BATCHED) == before
        status, order = reserve('ci-invariant-reserve', 3)
        assert status == 201, (status, order)
        assert balances(BATCHED)[:3] == (7, 7, 2)
        assert cancel(order)[0] == 200
        released = balances(BATCHED)
        assert released[:3] == (10, 10, 3), released
        assert cancel(order)[0] in [200, 409]
        assert balances(BATCHED) == released
        waste = {'sku': BATCHED, 'batchCode': 'CI-INVARIANT-LOT', 'quantity': 2, 'reason': 'CI waste'}
        assert request('/api/v1/admin/inventory/waste', 'POST', waste, token, 'ci-invariant-waste')[0] == 200
        wasted = balances(BATCHED)
        assert wasted[:3] == (8, 8, 4), wasted
        assert request('/api/v1/admin/inventory/waste', 'POST', waste, token, 'ci-invariant-waste')[0] == 200
        assert balances(BATCHED) == wasted
        assert request('/api/v1/admin/inventory/waste', 'POST', dict(waste, quantity=9), token, 'ci-invariant-too-much')[0] == 409
        assert request('/api/v1/admin/inventory/waste', 'POST', dict(waste, batchCode='MISSING'), token, 'ci-invariant-missing')[0] == 409
        assert balances(BATCHED) == wasted
        # Checkout and forbidden generic adjustments share variant-before-batch locks.
        with ThreadPoolExecutor(max_workers=8) as pool:
            checkouts = [pool.submit(reserve, 'ci-invariant-parallel-' + str(i)) for i in range(8)]
            adjustments = [pool.submit(adjust, BATCHED, delta, 'ci-invariant-forbidden-' + str(i)) for i, delta in enumerate([-1, 1, -1, 1])]
            orders = [future.result() for future in checkouts]
            assert all(future.result()[0] == 409 for future in adjustments)
        assert all(status == 201 for status, _ in orders), orders
        exhausted = balances(BATCHED)
        assert exhausted[:3] == (0, 0, 12), exhausted
        assert reserve('ci-invariant-oversell')[0] == 409
        assert adjust(BATCHED, 1, 'ci-invariant-exhausted')[0] == 409
        assert balances(BATCHED) == exhausted
        for _, order in orders:
            assert cancel(order)[0] == 200
        assert balances(BATCHED)[:3] == (8, 8, 20)
        # A simultaneous cancellation and checkout keep the same variant-before-batch lock order.
        status, cancellation_race = reserve('ci-invariant-cancel-race', 2)
        assert status == 201
        with ThreadPoolExecutor(max_workers=2) as pool:
            cancellation = pool.submit(cancel, cancellation_race)
            competing_checkout = pool.submit(reserve, 'ci-invariant-checkout-race', 1)
            cancellation_result = cancellation.result(timeout=20)
            checkout_result = competing_checkout.result(timeout=20)
        assert cancellation_result[0] == 200, cancellation_result
        assert checkout_result[0] == 201, checkout_result
        assert balances(BATCHED)[:2] == (7, 7)
        assert cancel(checkout_result[1])[0] == 200
        assert balances(BATCHED)[:2] == (8, 8)
        # Later receipts remain valid after batch history exists, even when stock is positive.
        assert request('/api/v1/admin/inventory/batches', 'POST', {
            'sku': BATCHED, 'batchCode': 'CI-INVARIANT-LOT-2', 'receivedPackages': 3,
            'producedAt': '2025-01-01T00:00:00Z', 'expiresAt': '2030-01-01T00:00:00Z',
            'costPrice': 1000, 'supplier': 'CI supplier'}, token)[0] == 201
        assert balances(BATCHED)[:2] == (11, 11)
        assert adjust(LEGACY, 3, 'ci-multisku-opening')[0] == 200
        # A padded SKU must follow the same trimmed, canonical lock order as cancellation.
        multi_lines = [{'sku': ' ' + LEGACY + ' ', 'quantity': 1}, {'sku': BATCHED, 'quantity': 1}]
        status, multi_sku_order = reserve_lines('ci-invariant-multisku-cancel', multi_lines)
        assert status == 201, (status, multi_sku_order)
        with ThreadPoolExecutor(max_workers=2) as pool:
            cancellation = pool.submit(cancel, multi_sku_order)
            competing_checkout = pool.submit(reserve_lines, 'ci-invariant-multisku-checkout', multi_lines)
            cancellation_result = cancellation.result(timeout=20)
            checkout_result = competing_checkout.result(timeout=20)
        assert cancellation_result[0] == 200, cancellation_result
        assert checkout_result[0] == 201, checkout_result
        assert balances(BATCHED)[:2] == (10, 10)
        assert balances(LEGACY)[0] == 2
        assert cancel(checkout_result[1])[0] == 200
        assert balances(BATCHED)[:2] == (11, 11)
        assert balances(LEGACY)[0] == 3
    finally:
        stop_api(api)
    # Rehearse the additive migration/restart and durable replay on the same test DB.
    api, token = start_api()
    try:
        before = balances(LEGACY)
        assert adjust(LEGACY, 10, 'ci-adjust-opening')[0] == 200
        assert balances(LEGACY) == before
        assert balances(BATCHED)[:2] == (11, 11)
    finally:
        stop_api(api)
print('Inventory legacy/batch policy, reservations/releases/waste, atomic failure, concurrent and durable retry checks passed')
