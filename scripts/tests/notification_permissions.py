"""Real API notification projection; fixtures exist only in the disposable CI DB."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[2]
BASE = "http://127.0.0.1:5103"
INVENTORY_MARKER = "NOTIFICATION-ONLY-INVENTORY"


def request(path, method="GET", body=None, token=None, extra_headers=None):
    headers = dict(extra_headers or {})
    if body is not None:
        headers["Content-Type"] = "application/json"
    if token:
        headers["Authorization"] = "Bearer " + token
    try:
        response = urlopen(Request(BASE + path, method=method, headers=headers,
                                   data=json.dumps(body).encode() if body is not None else None), timeout=8)
    except HTTPError as error:
        response = error
    with response:
        payload = response.read()
        return response.status, json.loads(payload) if payload else None


def start_api(permissions=None):
    environment = dict(os.environ, Admin__Role="Owner" if permissions is None else "ReadOnlyAnalyst",
                       Admin__Permissions="" if permissions is None else permissions)
    process = subprocess.Popen(
        ["dotnet", "run", "--project", "services/api/Mazeduneh.Api.csproj", "--configuration", "Release",
         "--no-build", "--urls", BASE], cwd=ROOT, env=environment, stdout=log, stderr=subprocess.STDOUT,
    )
    try:
        for _ in range(40):
            if process.poll() is not None:
                raise AssertionError("API exited before the permission test")
            try:
                if request("/health/live")[0] == 200:
                    status, login = request("/api/v1/admin/auth/login", "POST",
                                            {"email": os.environ["Admin__Email"], "password": "Mazeduneh-CI-Owner-Password!"})
                    assert status == 200
                    return process, login["accessToken"]
            except (URLError, TimeoutError):
                pass
            time.sleep(1)
        raise AssertionError("Permission API did not start")
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
        # One low-stock draft ensures an always-empty implementation cannot pass.
        status, _ = request("/api/v1/products/", "POST", {
            "title": "کالای تست مجوز اعلان", "slug": "notification-permission-fixture", "category": "آزمایشی",
            "origin": "ایران", "currency": "IRR", "unitType": "Weight", "isPublished": False,
            "variants": [{"sku": INVENTORY_MARKER, "quantity": 250, "displayLabel": "۲۵۰ گرم",
                          "price": 1000, "availablePackages": 0}],
        }, token)
        assert status == 201, status
        status, _ = request("/api/v1/checkout/orders", "POST", {
            "customerName": "تست اعلان", "mobile": "09120000001", "province": "تهران", "city": "تهران",
            "address": "نشانی تست مجوز", "postalCode": "1234567890", "lines": [{"sku": "PI-AKB-250", "quantity": 1}],
        }, extra_headers={"Idempotency-Key": "ci-notification-projection-0001"})
        assert status == 201, status
        status, owner = request("/api/v1/admin/notifications", token=token)
        assert status == 200 and owner["awaitingPayment"] > 0 and owner["lowStockItems"] > 0
        assert INVENTORY_MARKER in json.dumps(owner)
        assert request("/api/v1/admin/notifications")[0] == 401
    finally:
        stop_api(api)

    for permissions, allowed_types in [
        ("dashboard.read", set()),
        ("dashboard.read,orders.read", {"awaiting-payment", "new-orders"}),
        ("dashboard.read,inventory.read", {"low-stock"}),
        ("dashboard.read,orders.read,inventory.read", {"awaiting-payment", "new-orders", "low-stock"}),
    ]:
        api, token = start_api(permissions)
        try:
            status, payload = request("/api/v1/admin/notifications", token=token)
            assert status == 200
            types = {item["type"] for item in payload["items"]}
            assert types == allowed_types, (permissions, types)
            assert set(payload) == {"awaitingPayment", "lowStockItems", "items"}
            assert payload["awaitingPayment"] == (owner["awaitingPayment"] if "orders.read" in permissions else 0)
            assert payload["lowStockItems"] == (owner["lowStockItems"] if "inventory.read" in permissions else 0)
            assert (INVENTORY_MARKER in json.dumps(payload)) == ("inventory.read" in permissions)
        finally:
            stop_api(api)

    api, token = start_api("inventory.read")
    try:
        assert request("/api/v1/admin/notifications", token=token)[0] == 403
    finally:
        stop_api(api)

print("Notification API: Owner regression, domain projection, hidden counts and 401/403 passed")
