"""Exercise Owner TOTP step-up and replay protection against the live API."""
import base64
import hashlib
import hmac
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import time
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parents[2]
BASE = "http://127.0.0.1:5111"
TEST_TOTP_SECRET = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ"
OWNER_PASSWORD = "Mazeduneh-CI-Owner-Password!"


def request(path, method="GET", body=None, token=None, extra_headers=None):
    headers = {"Content-Type": "application/json"} if body is not None else {}
    headers.update(extra_headers or {})
    if token:
        headers["Authorization"] = "Bearer " + token
    try:
        response = urlopen(Request(
            BASE + path,
            method=method,
            headers=headers,
            data=json.dumps(body).encode() if body is not None else None,
        ), timeout=10)
    except HTTPError as error:
        response = error
    with response:
        content = response.read()
        return response.status, json.loads(content) if content else None


def totp_code(counter):
    secret = base64.b32decode(TEST_TOTP_SECRET)
    digest = hmac.new(secret, struct.pack(">Q", counter), hashlib.sha1).digest()
    offset = digest[-1] & 0x0F
    code = (int.from_bytes(digest[offset:offset + 4], "big") & 0x7FFFFFFF) % 1_000_000
    return f"{code:06d}"


def current_totp_code():
    return totp_code(int(time.time()) // 30)


def invalid_totp_code():
    current_step = int(time.time()) // 30
    accepted_codes = {totp_code(current_step + delta) for delta in (-1, 0, 1)}
    candidate = 0
    while f"{candidate:06d}" in accepted_codes:
        candidate += 1
    return f"{candidate:06d}"


def start_api(log):
    env = os.environ.copy()
    env["Admin__Mfa__SensitiveActionsRequired"] = "true"
    env["Admin__Mfa__Required"] = "false"
    env["Admin__Mfa__TotpSecret"] = TEST_TOTP_SECRET
    process = subprocess.Popen(
        ["dotnet", "run", "--project", "services/api/Mazeduneh.Api.csproj",
         "--configuration", "Release", "--no-build", "--urls", BASE],
        cwd=ROOT, env=env, stdout=log, stderr=subprocess.STDOUT)
    try:
        for _ in range(40):
            if process.poll() is not None:
                raise AssertionError("MFA integration API exited before becoming ready")
            try:
                if request("/health/live")[0] == 200:
                    status, login = request("/api/v1/admin/auth/login", "POST", {
                        "email": os.environ["Admin__Email"], "password": OWNER_PASSWORD,
                    })
                    assert status == 200, login
                    return process, login["accessToken"]
            except (URLError, TimeoutError):
                pass
            time.sleep(0.5)
        raise AssertionError("MFA integration API did not start")
    except BaseException:
        stop_api(process)
        log.seek(0)
        sys.stderr.write(log.read())
        raise


def stop_api(process):
    if process.poll() is not None:
        return
    process.terminate()
    try:
        process.wait(timeout=10)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=5)


with tempfile.TemporaryFile(mode="w+t", encoding="utf-8") as log:
    api, token = start_api(log)
    try:
        endpoint = "/api/v1/admin/auth/step-up"
        status, response = request(endpoint, "POST", {"password": OWNER_PASSWORD}, token)
        assert status == 428 and response.get("code") == "mfa_required", (status, response)

        status, response = request(endpoint, "POST", {
            "password": OWNER_PASSWORD, "mfaCode": invalid_totp_code(),
        }, token)
        assert status == 403 and response.get("code") == "mfa_invalid", (status, response)

        accepted_code = current_totp_code()
        status, proof = request(endpoint, "POST", {
            "password": OWNER_PASSWORD, "mfaCode": accepted_code,
        }, token)
        assert status == 200 and proof.get("stepUpToken"), (status, proof)
        assert proof.get("expiresAt"), proof

        replay_status, replay = request(endpoint, "POST", {
            "password": OWNER_PASSWORD, "mfaCode": accepted_code,
        }, token)
        assert replay_status == 403 and replay.get("code") == "mfa_invalid", (replay_status, replay)

        cancel_path = "/api/v1/admin/orders/00000000-0000-0000-0000-000000000001/state"
        cancel_body = {"state": "Cancelled", "reason": "MFA integration contract"}
        assert request(cancel_path, "PATCH", cancel_body, token)[0] == 428
        authorized_status, _ = request(
            cancel_path, "PATCH", cancel_body, token,
            {"X-Admin-Step-Up": proof["stepUpToken"]})
        assert authorized_status == 404, authorized_status
    finally:
        stop_api(api)

print("Owner step-up TOTP challenge, validation, replay guard, and sensitive-route proof passed")

