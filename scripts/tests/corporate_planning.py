"""Real API planning queue contract and existing assignment/follow-up flow."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[2]
BASE = 'http://127.0.0.1:5105'
PREFIX = 'ci-planning-fixture'
ADMIN = '/api/v1/admin/corporate-requests'


def request(path, method='GET', body=None, token=None):
    headers = {'Content-Type': 'application/json'} if body is not None else {}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    try:
        response = urlopen(Request(BASE + path, method=method, headers=headers,
                                   data=json.dumps(body).encode() if body is not None else None), timeout=8)
    except HTTPError as error:
        response = error
    with response:
        content = response.read()
        return response.status, json.loads(content) if content else None


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
        fixtures = []
        for index in range(7):
            status, created = request('/api/v1/corporate-requests', 'POST', {
                'customerName': 'CI customer', 'companyName': PREFIX + '-' + str(index),
                'mobile': '09123456789', 'email': None, 'city': 'CI-city', 'occasion': 'CI',
                'orderQuantity': 50, 'packageType': 'CI', 'budget': None, 'deliveryDate': None,
                'customPackaging': False, 'description': None, 'logoKey': None})
            assert status == 201, status
            fixtures.append(created['id'])
        a, b, c, d, e, f, g = fixtures
        mutate(b, '/assign', {'assignedTo': 'CI owner'})
        mutate(c, '/follow-up', {'nextFollowUpAt': '2099-01-01T00:00:00Z'})
        mutate(d, '/assign', {'assignedTo': 'CI owner'})
        mutate(d, '/follow-up', {'nextFollowUpAt': '2000-01-01T00:00:00Z'})
        assert change_status(e, 'Shipped')[0] == 409  # Cannot skip the sales and fulfillment stages.
        for next_status in ['Reviewing', 'Contacted', 'ProformaSent', 'Negotiating', 'Approved', 'Preparing', 'Shipped', 'Finalized']:
            assert change_status(e, next_status)[0] == 200, next_status
        assert change_status(e, 'Reviewing')[0] == 409  # Terminal requests cannot be reopened.
        mutate(f, '/status', {'status': 'Cancelled', 'note': 'CI'}, 'PATCH')
        mutate(g, '/assign', {'assignedTo': '  '})
        mutate(g, '/follow-up', {'nextFollowUpAt': '2099-01-01T00:00:00Z'})
        assert ids() == set(fixtures)
        assert ids('&needsPlanning=false') == set(fixtures)
        assert ids('&needsPlanning=true') == {a, b, c, g}
        assert ids('&needsPlanning=true&status=New&city=CI-city&minQuantity=50&maxQuantity=50') == {a, b, c, g}
        assert ids('&overdue=true') == {d}
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
    finally:
        stop_api(api)
    api, token = start_api(log, restricted=True)
    try:
        assert request(ADMIN + '?needsPlanning=true', token=token)[0] == 403
    finally:
        stop_api(api)

print('Corporate planning: inclusion, terminal exclusion, filters, assignment flow, restart and authorization passed')
