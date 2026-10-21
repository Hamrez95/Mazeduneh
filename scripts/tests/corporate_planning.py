"""Real API planning queue contract and existing assignment/follow-up flow."""
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
BASE = 'http://127.0.0.1:5105'
PREFIX = 'ci-planning-fixture'
ADMIN = '/api/v1/admin/corporate-requests'


def request(path, method='GET', body=None, token=None, extra_headers=None, include_headers=False):
    headers = {'Content-Type': 'application/json'} if body is not None else {}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    if extra_headers:
        headers.update(extra_headers)
    try:
        response = urlopen(Request(BASE + path, method=method, headers=headers,
                                   data=json.dumps(body).encode() if body is not None else None), timeout=8)
    except HTTPError as error:
        response = error
    with response:
        content = response.read()
        result = (response.status, json.loads(content) if content else None)
        return (*result, response.headers) if include_headers else result


def start_api(log, restricted=False):
    env = os.environ.copy()
    if restricted:
        env.update(Admin__Role='ReadOnlyAnalyst', Admin__Permissions='dashboard.read')
    process = subprocess.Popen(['dotnet', 'run', '--project', 'services/api/Mazeduneh.Api.csproj',
                                '--configuration', 'Release', '--no-build', '--urls', BASE],
                               cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
    try:
        for _ in range(40):
            if process.poll() is not None:
                raise AssertionError('Planning test API exited')
            try:
                if request('/health/live')[0] == 200:
                    status, login = request('/api/v1/admin/auth/login', 'POST', {
                        'email': os.environ['Admin__Email'], 'password': 'Mazeduneh-CI-Owner-Password!'})
                    assert status == 200
                    return process, login['accessToken']
            except (URLError, TimeoutError):
                pass
            time.sleep(1)
        raise AssertionError('Planning test API did not start')
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


def mutate(id, suffix, body, method='POST'):
    status, detail = request(ADMIN + '/' + id + suffix, method, body, token)
    assert status == 200, (suffix, status)
    return detail


def ids(params=''):
    status, items = request(ADMIN + '?query=' + PREFIX + params, token=token)
    assert status == 200
    return {item['id'] for item in items}


def change_status(id, status):
    return request(ADMIN + '/' + id + '/status', 'PATCH', {'status': status, 'note': 'CI'}, token)


def metrics():
    status, value = request(ADMIN + '/summary', token=token)
    assert status == 200
    return value


with tempfile.TemporaryFile() as log:
    api, token = start_api(log)
    try:
        baseline = metrics()
        package_body = {
            'name': 'CI package snapshot', 'description': 'Snapshot contract fixture', 'isActive': True,
            'items': [{'name': 'CI item', 'quantity': 2, 'unit': 'بسته', 'unitPrice': 120000}],
        }
        package_status, package = request(ADMIN + '/packages/ci-corp-kit', 'PUT', package_body, token)
        assert package_status == 200, package
        assert package['unitPrice'] == 240000 and package['items'][0]['quantity'] == 2
        assert request(ADMIN + '/packages', token=token)[0] == 200
        assert request(ADMIN + '/packages')[0] == 401
        public_status, public_packages = request('/api/v1/corporate-packages')
        assert public_status == 200 and any(item['code'] == 'ci-corp-kit' for item in public_packages)
        template_body = {
            'title': 'CI greeting', 'body': 'Hello company', 'isActive': True,
        }
        template_status, template = request(
            ADMIN + '/templates/ci-greeting', 'PUT', template_body, token)
        assert template_status == 200 and template['code'] == 'ci-greeting'
        assert template['title'] == 'CI greeting' and template['isActive'] is True
        template_list_status, templates = request(ADMIN + '/templates', token=token)
        assert template_list_status == 200 and any(item['code'] == 'ci-greeting' for item in templates)
        assert request(ADMIN + '/templates')[0] == 401
        disabled_body = dict(template_body, isActive=False)
        disabled_status, disabled = request(
            ADMIN + '/templates/ci-greeting', 'PUT', disabled_body, token)
        assert disabled_status == 200 and disabled['isActive'] is False
        fixtures = []
        for index in range(7):
            status, created, response_headers = request('/api/v1/corporate-requests', 'POST', {
                'customerName': 'CI customer', 'companyName': PREFIX + '-' + str(index),
                'mobile': '09123456789', 'email': None, 'city': 'CI-city', 'occasion': 'CI',
                'orderQuantity': 50, 'packageType': 'CI', 'packageCode': 'ci-corp-kit' if index == 0 else None,
                'budget': None, 'deliveryDate': None, 'customPackaging': False,
                'description': None, 'logoKey': None}, include_headers=True)
            assert status == 201, status
            access_token = created['accessToken']
            assert access_token and access_token not in (response_headers.get('Location') or '')
            public_path = '/api/v1/corporate-requests/' + created['id']
            assert request(public_path)[0] == 404
            assert request(public_path + '?accessToken=')[0] == 404
            assert request(public_path + '?accessToken=' + quote(access_token))[0] == 404
            assert request(public_path, extra_headers={'X-Corporate-Request-Token': 'invalid'})[0] == 404
            public_status, public_summary = request(public_path, extra_headers={
                'X-Corporate-Request-Token': access_token})
            assert public_status == 200 and public_summary['id'] == created['id']
            assert 'mobile' not in public_summary and 'email' not in public_summary
            fixtures.append(created['id'])
        a, b, c, d, e, f, g = fixtures
        detail_status, saved_request = request(ADMIN + '/' + a, token=token)
        assert detail_status == 200 and saved_request['packageCode'] == 'ci-corp-kit'
        assert saved_request['orderId'] is None
        assert request(ADMIN + '/' + a + '/order-link', 'POST', {
            'orderId': '00000000-0000-0000-0000-000000000001'}, token)[0] == 409
        snapshot = saved_request['packageSnapshot']
        assert snapshot['unitPrice'] == 240000 and snapshot['orderQuantity'] == 50
        assert snapshot['estimatedTotal'] == 12000000
        repriced = dict(package_body, items=[{'name': 'CI item', 'quantity': 2, 'unit': 'بسته', 'unitPrice': 150000}])
        updated_status, updated_package = request(ADMIN + '/packages/ci-corp-kit', 'PUT', repriced, token)
        assert updated_status == 200 and updated_package['unitPrice'] == 300000
        _, historical = request(ADMIN + '/' + a, token=token)
        assert historical['packageSnapshot']['unitPrice'] == 240000
        assert historical['packageSnapshot']['estimatedTotal'] == 12000000
        assigned = mutate(b, '/assign', {'assignedTo': 'CI owner'})
        assert assigned['assignedTo'] == 'CI owner'
        mutate(c, '/follow-up', {'nextFollowUpAt': '2099-01-01T00:00:00Z'})
        mutate(d, '/assign', {'assignedTo': 'CI owner'})
        mutate(d, '/follow-up', {'nextFollowUpAt': '2000-01-01T00:00:00Z'})
        assert change_status(e, 'Shipped')[0] == 409  # Cannot skip the sales and fulfillment stages.
        for next_status in ['Reviewing', 'Contacted', 'ProformaSent', 'Negotiating', 'Approved', 'Preparing', 'Shipped', 'Finalized']:
            status, updated = change_status(e, next_status)
            assert status == 200 and updated['status'] == next_status, (next_status, status, updated)
        assert change_status(e, 'Reviewing')[0] == 409  # Terminal requests cannot be reopened.
        assert request(ADMIN + '/' + e + '/order-link', 'POST', {
            'orderId': '00000000-0000-0000-0000-000000000001'}, token)[0] == 404
        checkout_payload = {
            'customerName': 'CI corporate order', 'mobile': '09123456789',
            'province': 'تهران', 'city': 'تهران', 'address': 'CI order link fixture',
            'postalCode': '1234567890', 'lines': [{'sku': 'PI-AKB-250', 'quantity': 1}],
        }
        order_status, linked_order = request('/api/v1/checkout/orders', 'POST', checkout_payload,
                                             extra_headers={'Idempotency-Key': 'corporate-order-link-0001'})
        assert order_status == 201, (order_status, linked_order)
        link_status, linked_request = request(ADMIN + '/' + e + '/order-link', 'POST',
                                              {'orderId': linked_order['id']}, token)
        assert link_status == 200 and linked_request['orderId'] == linked_order['id']
        replay_status, replayed_link = request(ADMIN + '/' + e + '/order-link', 'POST',
                                               {'orderId': linked_order['id']}, token)
        assert replay_status == 200 and replayed_link['orderId'] == linked_order['id']
        assert sum(event['eventType'] == 'order-linked' for event in replayed_link['events']) == 1
        link_audit_status, link_audit = request(
            '/api/v1/admin/audit-log?entityType=CorporateRequest&entityId=' + e, token=token)
        assert link_audit_status == 200 and sum(
            entry['action'] == 'corporate-request.order-linked' for entry in link_audit) == 1
        mutate(f, '/status', {'status': 'Cancelled', 'note': 'CI'}, 'PATCH')
        mutate(g, '/assign', {'assignedTo': '  '})
        mutate(g, '/follow-up', {'nextFollowUpAt': '2099-01-01T00:00:00Z'})
        assert ids() == set(fixtures)
        assert ids('&needsPlanning=false') == set(fixtures)
        assert ids('&needsPlanning=true') == {a, b, c, g}
        assert ids('&needsPlanning=true&status=New&city=CI-city&minQuantity=50&maxQuantity=50') == {a, b, c, g}
        assert ids('&overdue=true') == {d}
        notification_status, notifications = request('/api/v1/admin/notifications', token=token)
        assert notification_status == 200
        assert notifications['corporateOverdueFollowUps'] >= 1
        assert any(item['type'] == 'corporate-follow-up'
                   and 'ci-planning-fixture-3' in item['detail']
                   and item['id'].startswith('corporate-follow-up_')
                   and item['target']['module'] == 'corporate'
                   for item in notifications['items'])
        assert request(ADMIN + '?needsPlanning=true&overdue=true', token=token)[0] == 400
        assert request(ADMIN + '?needsPlanning=invalid', token=token)[0] == 400
        assert request(ADMIN + '?needsPlanning=true')[0] == 401
        mutate(a, '/assign', {'assignedTo': 'CI owner'})
        assert a in ids('&needsPlanning=true')  # Still missing its follow-up date.
        mutate(a, '/follow-up', {'nextFollowUpAt': '2099-01-01T00:00:00Z'})
        assert ids('&needsPlanning=true') == {b, c, g}
        updated_metrics = metrics()
        assert updated_metrics['totalCount'] == baseline['totalCount'] + len(fixtures)
        assert updated_metrics['newCount'] == baseline['newCount'] + 5
        assert updated_metrics['activeCount'] == baseline['activeCount'] + 5
        assert updated_metrics['finalizedCount'] == baseline['finalizedCount'] + 1
        assert updated_metrics['firstContactCount'] == baseline['firstContactCount'] + 1
        expected_rate = updated_metrics['finalizedCount'] * 100 / updated_metrics['totalCount']
        assert abs(updated_metrics['conversionRatePercent'] - expected_rate) < 0.01
        assert updated_metrics['averageHoursToFirstContact'] >= 0
    finally:
        stop_api(api)
    api, token = start_api(log)
    try:
        assert ids('&needsPlanning=true') == {b, c, g}
        persisted_templates = request(ADMIN + '/templates', token=token)
        assert persisted_templates[0] == 200 and any(
            item['code'] == 'ci-greeting' and item['isActive'] is False
            for item in persisted_templates[1])
    finally:
        stop_api(api)
    api, token = start_api(log, restricted=True)
    try:
        assert request(ADMIN + '?needsPlanning=true', token=token)[0] == 403
        assert request(ADMIN + '/packages', token=token)[0] == 403
        assert request(ADMIN + '/packages/ci-corp-kit', 'PUT', package_body, token)[0] == 403
        assert request(ADMIN + '/templates', token=token)[0] == 403
        assert request(ADMIN + '/templates/ci-greeting', 'PUT', template_body, token)[0] == 403
        notification_status, restricted_notifications = request('/api/v1/admin/notifications', token=token)
        assert notification_status == 200
        assert restricted_notifications['corporateOverdueFollowUps'] == 0
        assert not any(item['type'] == 'corporate-follow-up'
                       for item in restricted_notifications['items'])
    finally:
        stop_api(api)

print('Corporate planning: inclusion, terminal exclusion, filters, assignment flow, restart and authorization passed')
