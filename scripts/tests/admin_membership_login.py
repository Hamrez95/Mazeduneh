"""Membership invitation, store binding, revocation and authorization regression."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[2]
BASE = "http://127.0.0.1:5107"
OWNER_PASSWORD = "Mazeduneh-CI-Owner-Password!"


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


def start_api(log):
    process = subprocess.Popen(["dotnet", "run", "--project", "services/api/Mazeduneh.Api.csproj",
                                "--configuration", "Release", "--no-build", "--urls", BASE],
                               cwd=ROOT, env=os.environ.copy(), stdout=log, stderr=subprocess.STDOUT)
    try:
        for _ in range(40):
            if process.poll() is not None:
                raise AssertionError("Membership test API exited")
            try:
                if request("/health/live")[0] == 200:
                    status, login = request("/api/v1/admin/auth/login", "POST", {
                        "email": os.environ["Admin__Email"], "password": OWNER_PASSWORD})
                    assert status == 200
                    return process, login["accessToken"]
            except (URLError, TimeoutError):
                pass
            time.sleep(1)
        raise AssertionError("Membership test API did not start")
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


def invite(owner_token, email, name, permissions=None, store_id=None):
    payload = {"email": email, "displayName": name, "role": "WarehouseOperator"}
    if permissions is not None:
        payload["permissions"] = permissions
    path = "/api/v1/admin/users" + ("?storeId=" + store_id if store_id else "")
    status, result = request(path, "POST", payload, owner_token)
    assert status == 201, (status, result)
    assert result["user"]["email"] == email and result["invitationToken"] and result["expiresAt"]
    return result


def accept_and_login(invitation, email, password, check_unaccepted_login=True, store_id="default", role="WarehouseOperator"):
    if check_unaccepted_login:
        status, _ = request("/api/v1/admin/auth/login", "POST", {"email": email, "password": password})
        assert status == 401, status
    status, _ = request("/api/v1/admin/auth/accept-invite", "POST", {
        "token": invitation["invitationToken"], "password": password})
    assert status == 204, status
    assert request("/api/v1/admin/auth/accept-invite", "POST", {
        "token": invitation["invitationToken"], "password": password})[0] == 400
    status, login = request("/api/v1/admin/auth/login", "POST", {"email": email, "password": password, "storeId": store_id})
    assert status == 200 and login["role"] == role and login["storeId"] == store_id, (
        status, login.get("role") if login else None, login.get("storeId") if login else None)
    return login["accessToken"]


with tempfile.TemporaryFile() as log:
    api, owner_token = start_api(log)
    try:
        first_email = "membership-one@example.test"
        first_password = "Membership-CI-Password-1!"
        first_invitation = invite(owner_token, first_email, "CI member one")
        first_token = accept_and_login(first_invitation, first_email, first_password)
        status, session = request("/api/v1/admin/auth/session", token=first_token)
        assert status == 200 and session["authenticated"] is True and session["storeId"] == "default"
        assert request("/api/v1/admin/users", token=first_token)[0] == 403
        assert request("/api/v1/admin/inventory/movements?sku=UNKNOWN&storeId=default", token=first_token)[0] == 200
        wrong_store_requests = [
            ("/api/v1/admin/inventory/movements?sku=UNKNOWN&storeId=another-store", "GET", None),
            ("/api/v1/admin/orders?storeId=another-store", "GET", None),
            ("/api/v1/admin/inventory/adjust?storeId=another-store", "POST",
             {"sku": "UNKNOWN", "quantityDelta": 1, "reason": "cross-store-must-not-write"}),
            ("/api/v1/admin/users/" + first_invitation["user"]["id"] + "/status?storeId=another-store", "PATCH",
             {"isActive": False}),
        ]
        for path, method, body in wrong_store_requests:
            status, denial = request(path, method, body, first_token)
            assert status == 403 and denial["message"] == "به این فروشگاه دسترسی ندارید.", (path, status, denial)

        member_id = first_invitation["user"]["id"]
        status, revised = request("/api/v1/admin/users/" + member_id + "/permissions", "PATCH",
                                 {"permissions": ["inventory.read"]}, owner_token)
        assert status == 200 and revised["permissions"] == ["inventory.read"]
        # Keep the production rate limit intact while proving both the override
        # and session revocation survive an API restart against the same database.
        stop_api(api)
        api, owner_token = start_api(log)
        assert request("/api/v1/admin/auth/session", token=first_token)[0] == 401
        status, limited_login = request("/api/v1/admin/auth/login", "POST", {
            "email": first_email, "password": first_password})
        assert status == 200 and limited_login["permissions"] == ["inventory.read"], (status, limited_login)
        limited_token = limited_login["accessToken"]
        assert request("/api/v1/admin/inventory/movements?sku=UNKNOWN", token=limited_token)[0] == 200
        assert request("/api/v1/admin/orders", token=limited_token)[0] == 403

        status, cleared = request("/api/v1/admin/users/" + member_id + "/permissions", "PATCH",
                                  {"permissions": []}, owner_token)
        assert status == 200 and cleared["permissions"] == []
        assert request("/api/v1/admin/auth/session", token=limited_token)[0] == 401
        status, empty_login = request("/api/v1/admin/auth/login", "POST", {
            "email": first_email, "password": first_password})
        assert status == 200 and empty_login["permissions"] == []
        assert request("/api/v1/admin/inventory/movements?sku=UNKNOWN", token=empty_login["accessToken"])[0] == 403

        status, audit = request("/api/v1/admin/audit-log?entityType=AdminUser&entityId=" + first_invitation["user"]["id"], token=owner_token)
        assert status == 200
        assert any(item["action"] == "admin-user.invitation-accepted" for item in audit)
        assert len([item for item in audit if item["action"] == "admin-user.permissions-changed"]) == 2
        assert request("/api/v1/admin/auth/logout", "POST", token=first_token)[0] == 204
        assert request("/api/v1/admin/auth/session", token=first_token)[0] == 401

        # Restart to reset the shared login/invitation rate-limit window before the additional tenant flow.
        stop_api(api)
        api, owner_token = start_api(log)

        # Simulate a pre-existing membership Owner in a non-default store.
        # Omitting storeId must bind user-management queries and writes to the
        # authenticated membership, never fall back to the default store.
        tenant_email = "membership-tenant-owner@example.test"
        tenant_password = "Membership-CI-Tenant-Password!"
        tenant_invitation = invite(owner_token, tenant_email, "CI tenant owner", store_id="tenant-a")
        subprocess.run(["dotnet", "run", "--project", "services/api.tests/Mazeduneh.Api.Tests.csproj",
                        "--configuration", "Release", "--no-build", "--", "--promote-membership-owner", tenant_email, "tenant-a"],
                       cwd=ROOT, env=dict(os.environ, MAZEDUNEH_TEST_FIXTURES="true"), check=True)
        tenant_token = accept_and_login(tenant_invitation, tenant_email, tenant_password,
                                        check_unaccepted_login=False, store_id="tenant-a", role="Owner")
        status, tenant_users = request("/api/v1/admin/users", token=tenant_token)
        assert status == 200 and any(user["id"] == tenant_invitation["user"]["id"] for user in tenant_users)
        assert all(user["storeId"] == "tenant-a" for user in tenant_users), (status, tenant_users)
        status, denied = request("/api/v1/admin/users/" + first_invitation["user"]["id"] + "/permissions",
                                 "PATCH", {"permissions": []}, tenant_token)
        assert status == 404, (status, denied)
        assert request("/api/v1/admin/users?storeId=default", token=tenant_token)[0] == 403
        status, owner_unchanged = request("/api/v1/admin/users/" + tenant_invitation["user"]["id"] + "/status?storeId=tenant-a",
                                          "PATCH", {"isActive": False}, owner_token)
        assert status == 404, (status, owner_unchanged)
        assert request("/api/v1/admin/auth/session", token=tenant_token)[0] == 200

        # Start a fresh in-memory rate-limit window before checking deactivation separately.
        stop_api(api)
        api, owner_token = start_api(log)

        second_email = "membership-two@example.test"
        second_password = "Membership-CI-Password-2!"
        second_invitation = invite(owner_token, second_email, "CI member two", ["orders.read", "customers.pii.read"])
        second_token = accept_and_login(second_invitation, second_email, second_password, check_unaccepted_login=False)
        member_id = second_invitation["user"]["id"]
        status, disabled = request("/api/v1/admin/users/" + member_id + "/status", "PATCH",
                                   {"isActive": False}, owner_token)
        assert status == 200 and disabled["isActive"] is False
        assert request("/api/v1/admin/auth/session", token=second_token)[0] == 401
        assert request("/api/v1/admin/inventory/movements?sku=UNKNOWN", token=second_token)[0] == 401
    finally:
        stop_api(api)

print("Membership invitation, one-time use, permissions, store binding and revocation passed")
