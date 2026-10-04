"""Verify server-owned correlation and redacted structured logs on the real API."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[2]
BASE = "http://127.0.0.1:5102"
SENSITIVE = "private-observability-sentinel"


def request(path, method="GET", body=None):
    headers = {"X-Request-ID": SENSITIVE, "Authorization": "Bearer " + SENSITIVE,
               "Origin": "http://localhost:3000"}
    if body is not None:
        headers["Content-Type"] = "application/json"
    request = Request(BASE + path, data=body, headers=headers, method=method)
    try:
        response = urlopen(request, timeout=6)
    except HTTPError as error:
        response = error
    with response:
        content = response.read()
        return response.status, response.headers, json.loads(content) if content else None


with tempfile.TemporaryFile(mode="w+") as log:
    api = subprocess.Popen(
        ["dotnet", "run", "--project", "services/api/Mazeduneh.Api.csproj",
         "--configuration", "Release", "--no-build", "--urls", BASE],
        cwd=ROOT, env=os.environ.copy(), stdout=log, stderr=subprocess.STDOUT,
    )
    expected = []
    try:
        for _ in range(40):
            if api.poll() is not None:
                raise AssertionError("API exited before the test started")
            try:
                if request("/health/live")[0] == 200:
                    break
            except (URLError, TimeoutError):
                pass
            time.sleep(1)
        else:
            raise AssertionError("API did not start")

        cases = [
            ("/health/ready", "GET", None, 200, "/health/ready"),
            ("/api/v1/products/" + SENSITIVE + "?receiptToken=" + SENSITIVE,
             "GET", None, 404, "/api/v1/products/{slug}"),
            ("/api/v1/admin/orders", "GET", None, 401, "/api/v1/admin/orders"),
            ("/api/v1/checkout/orders", "POST", json.dumps({"customerName": SENSITIVE}).encode(),
             400, "/api/v1/checkout/orders"),
        ]
        for path, method, body, status, route in cases:
            actual, headers, payload = request(path, method, body)
            assert actual == status, (actual, path)
            request_id = headers.get("X-Request-ID")
            assert request_id and request_id != SENSITIVE
            assert "X-Request-ID" in headers.get("Access-Control-Expose-Headers", "")
            expected.append((request_id, method, route, status))
        assert len({item[0] for item in expected}) == len(expected)
    finally:
        api.terminate()
        try:
            api.wait(timeout=10)
        except subprocess.TimeoutExpired:
            api.kill()
            api.wait(timeout=5)

    log.seek(0)
    text = log.read()
    # Headers, raw SKU/URL query and request-body marker must never appear in logs.
    assert SENSITIVE not in text, "Sensitive request data was logged"
    records = []
    for line in text.splitlines():
        try:
            records.append(json.loads(line))
        except json.JSONDecodeError:
            pass  # dotnet run can print an unstructured launch-settings banner.
    completed = [item for item in records if item.get("Category", "").endswith("RequestObservabilityMiddleware")
                 and item.get("EventId") == 1000]
    for request_id, method, route, status in expected:
        record = next(item for item in completed if item["State"]["RequestId"] == request_id)
        state = record["State"]
        assert state["Method"] == method and state["Route"] == route
        assert state["StatusCode"] == status and state["ElapsedMilliseconds"] >= 0
        assert set(state) == {"Message", "RequestId", "Method", "Route", "StatusCode",
                              "ElapsedMilliseconds", "{OriginalFormat}"}
        assert any(scope.get("RequestId") == request_id for scope in record["Scopes"]
                   if isinstance(scope, dict))

print("API observability: correlation, CORS, validation errors and structured-log redaction passed")
