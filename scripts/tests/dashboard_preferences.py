"""Per-user dashboard preference, role fallback, and store isolation contract."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
from datetime import datetime, timedelta, timezone
from urllib.parse import urlencode
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[2]
BASE = "http://127.0.0.1:5108"
OWNER_PASSWORD = "Mazeduneh-CI-Owner-Password!"
WIDGETS = ["metrics", "quickActions", "alerts", "lowStock", "expiring"]


def request(path, method="GET", body=None, token=None, extra_headers=None):
    headers = {"Content-Type": "application/json"} if body is not None else {}
    if token:
        headers["Authorization"] = "Bearer " + token
    headers.update(extra_headers or {})
    try:
        response = urlopen(Request(BASE + path, method=method, headers=headers,
                                   data=json.dumps(body).encode() if body is not None else None), timeout=8)
    except HTTPError as error:
        response = error
    with response:
        content = response.read()
        return response.status, json.loads(content) if content else None


def start_api(role, log, permissions="dashboard.read"):
    environment = dict(os.environ, Admin__Role=role, Admin__Permissions=permissions)
    process = subprocess.Popen(
        ["dotnet", "run", "--project", "services/api/Mazeduneh.Api.csproj", "--configuration", "Release",
         "--no-build", "--urls", BASE], cwd=ROOT, env=environment, stdout=log, stderr=subprocess.STDOUT,
    )
    try:
        for _ in range(40):
            if process.poll() is not None:
                raise AssertionError(f"Dashboard preferences API exited for role {role}")
            try:
                if request("/health/live")[0] == 200:
                    status, login = request("/api/v1/admin/auth/login", "POST", {
                        "email": os.environ["Admin__Email"], "password": OWNER_PASSWORD})
                    assert status == 200, status
                    return process, login["accessToken"]
            except (URLError, TimeoutError):
                pass
            time.sleep(1)
        raise AssertionError("Dashboard preferences API did not start")
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


def seed_role_dashboard_preferences():
    database = {}
    for entry in os.environ["ConnectionStrings__Catalog"].split(";"):
        if "=" in entry:
            key, value = entry.split("=", 1)
            database[key.strip().lower()] = value.strip()
    environment = dict(os.environ)
    for source, target in (("host", "PGHOST"), ("port", "PGPORT"), ("database", "PGDATABASE"),
                           ("username", "PGUSER"), ("password", "PGPASSWORD")):
        if source in database:
            environment[target] = database[source]
    sql = """insert into admin_dashboard_role_preferences
        (store_id, role, widgets, updated_by, updated_at)
        values ('default', 'WarehouseOperator',
        '[{"id":"expiring","visible":true},{"id":"alerts","visible":false},
          {"id":"metrics","visible":true},{"id":"quickActions","visible":false},
          {"id":"lowStock","visible":true}]'::jsonb,
        'dashboard-preferences-ci', now())
        on conflict (store_id, role) do update
        set widgets=excluded.widgets, updated_by=excluded.updated_by, updated_at=excluded.updated_at;"""
    subprocess.run(["psql", "--no-psqlrc", "--set=ON_ERROR_STOP=1", "--command", sql],
                   cwd=ROOT, env=environment, check=True)


def create_dashboard_member(owner_token, email, password, display_name):
    status, step_up = request("/api/v1/admin/auth/step-up", "POST",
                             {"password": OWNER_PASSWORD}, owner_token)
    assert status == 200 and step_up["stepUpToken"], (status, step_up)
    status, invitation = request("/api/v1/admin/users", "POST", {
        "email": email,
        "displayName": display_name,
        "role": "WarehouseOperator",
        "permissions": ["dashboard.read"],
    }, owner_token, {"X-Admin-Step-Up": step_up["stepUpToken"]})
    assert status == 201 and invitation["invitationToken"], (status, invitation)
    status, _ = request("/api/v1/admin/auth/accept-invite", "POST", {
        "token": invitation["invitationToken"], "password": password,
    })
    assert status == 204, status
    status, login = request("/api/v1/admin/auth/login", "POST", {
        "email": email, "password": password, "storeId": "default",
    })
    assert status == 200 and login["permissions"] == ["dashboard.read"], (status, login)
    return login["accessToken"]


with tempfile.TemporaryFile() as log:
    # Use real role names: unknown values normalize to Owner, which would
    # accidentally make both processes share the same role-scoped preference.
    api, token = start_api("WarehouseOperator", log)
    try:
        health_endpoint = "/api/v1/admin/dashboard/health"
        assert request(health_endpoint)[0] == 401
        status, health = request(health_endpoint, token=token)
        assert status == 200 and health == {
            "api": "healthy", "database": "healthy", "migrations": "tracked",
            "adminAuthentication": "configured", "payment": "sandbox-enabled",
            "mediaStorage": "local", "ready": True,
        }, (status, health)
        endpoint = "/api/v1/admin/dashboard/preferences"
        assert request(endpoint)[0] == 401
        status, defaults = request(endpoint, token=token)
        assert status == 200 and [item["id"] for item in defaults["widgets"]] == WIDGETS
        now = datetime.now(timezone.utc).replace(microsecond=0)
        period = urlencode({"from": (now - timedelta(days=7)).isoformat(), "to": now.isoformat()})
        status, dashboard = request("/api/v1/admin/dashboard?" + period, token=token)
        assert status == 200 and dashboard["periodDays"] == 7, (status, dashboard)
        assert request("/api/v1/admin/dashboard?" + urlencode({"from": now.isoformat()}), token=token)[0] == 400
        assert request("/api/v1/admin/dashboard?" + urlencode({
            "from": now.isoformat(), "to": (now - timedelta(days=1)).isoformat(),
        }), token=token)[0] == 400
        assert request("/api/v1/admin/dashboard?" + urlencode({
            "from": (now - timedelta(days=367)).isoformat(), "to": now.isoformat(),
        }), token=token)[0] == 400
        custom = {"widgets": [
            {"id": "alerts", "visible": True},
            {"id": "metrics", "visible": False},
            {"id": "quickActions", "visible": True},
            {"id": "lowStock", "visible": False},
            {"id": "expiring", "visible": True},
        ]}
        status, saved = request(endpoint, "PUT", custom, token)
        assert status == 200 and saved == custom, (status, saved)
        assert request(endpoint, token=token)[1] == custom
        invalid = {"widgets": [*custom["widgets"][:-1], {"id": "other", "visible": True}]}
        assert request(endpoint, "PUT", invalid, token)[0] == 400
    finally:
        stop_api(api)

    api, other_token = start_api("SalesOperator", log)
    try:
        status, other_role = request("/api/v1/admin/dashboard/preferences", token=other_token)
        assert status == 200 and [item["id"] for item in other_role["widgets"]] == WIDGETS
    finally:
        stop_api(api)

    api, token = start_api("WarehouseOperator", log)
    try:
        status, saved = request("/api/v1/admin/dashboard/preferences", token=token)
        assert status == 200 and saved == custom
    finally:
        stop_api(api)

    first_email = "dashboard-preferences-one@example.test"
    first_password = "Dashboard-CI-Password-1!"
    second_email = "dashboard-preferences-two@example.test"
    second_password = "Dashboard-CI-Password-2!"
    api, owner_token = start_api("Owner", log, permissions="")
    try:
        seed_role_dashboard_preferences()
        first_user_token = create_dashboard_member(
            owner_token, first_email, first_password, "Dashboard member one")
        second_user_token = create_dashboard_member(
            owner_token, second_email, second_password, "Dashboard member two")
        endpoint = "/api/v1/admin/dashboard/preferences"
        role_default = {"widgets": [
            {"id": "expiring", "visible": True},
            {"id": "alerts", "visible": False},
            {"id": "metrics", "visible": True},
            {"id": "quickActions", "visible": False},
            {"id": "lowStock", "visible": True},
        ]}
        status, first_default = request(endpoint, token=first_user_token)
        assert status == 200 and first_default == role_default
        status, second_default = request(endpoint, token=second_user_token)
        assert status == 200 and second_default == role_default

        first_custom = {"widgets": [
            {"id": "quickActions", "visible": False},
            {"id": "metrics", "visible": True},
            {"id": "alerts", "visible": True},
            {"id": "lowStock", "visible": True},
            {"id": "expiring", "visible": False},
        ]}
        second_custom = {"widgets": [
            {"id": "expiring", "visible": True},
            {"id": "alerts", "visible": False},
            {"id": "metrics", "visible": False},
            {"id": "quickActions", "visible": True},
            {"id": "lowStock", "visible": True},
        ]}
        status, saved = request(endpoint, "PUT", first_custom, first_user_token)
        assert status == 200 and saved == first_custom, (status, saved)
        assert request(endpoint, token=first_user_token)[1] == first_custom
        assert request(endpoint, token=second_user_token)[1] == role_default
        status, saved = request(endpoint, "PUT", second_custom, second_user_token)
        assert status == 200 and saved == second_custom, (status, saved)
        assert request(endpoint, token=first_user_token)[1] == first_custom
        assert request(endpoint, token=second_user_token)[1] == second_custom
        stop_api(api)

        api, owner_token = start_api("Owner", log, permissions="")
        first_status, first_login = request("/api/v1/admin/auth/login", "POST", {
            "email": first_email, "password": first_password, "storeId": "default",
        })
        second_status, second_login = request("/api/v1/admin/auth/login", "POST", {
            "email": second_email, "password": second_password, "storeId": "default",
        })
        assert first_status == 200 and second_status == 200, (first_status, second_status)
        assert request(endpoint, token=first_login["accessToken"])[1] == first_custom
        assert request(endpoint, token=second_login["accessToken"])[1] == role_default
    finally:
        stop_api(api)

print("Dashboard preferences API: auth, validation, persistence, per-user, role and user isolation passed")


