"""Role- and store-scoped dashboard preference API contract."""
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


def start_api(role, log):
    environment = dict(os.environ, Admin__Role=role, Admin__Permissions="dashboard.read")
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
            "adminAuthentication": "configured", "ready": True,
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

print("Dashboard preferences API: auth, validation, persistence, visibility, order and role isolation passed")

