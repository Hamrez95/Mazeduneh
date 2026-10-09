"""Exercise the real API against CI PostgreSQL, including outage and recovery."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
from urllib.error import HTTPError, URLError
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[2]
BASE = "http://127.0.0.1:5101"


def request(path):
    started = time.monotonic()
    try:
        response = urlopen(BASE + path, timeout=6)
    except HTTPError as error:
        response = error
    with response:
        body = json.load(response)
        assert time.monotonic() - started < 5.5, "Probe exceeded its time budget"
        return response.status, body, response.headers


def assert_ready(expected_status, **expected_fields):
    status, body, headers = request("/health/ready")
    assert status == expected_status, (status, body)
    assert headers.get("Cache-Control") == "no-store"
    assert body["status"] == ("ready" if expected_status == 200 else "not-ready")
    for key, value in expected_fields.items():
        assert body[key] == value, (key, body)
    assert set(body) == {"status", "database", "migrations", "adminAuthentication"}
    return body


def start_api(overrides=None):
    environment = dict(os.environ, **(overrides or {}))
    process = subprocess.Popen(
        ["dotnet", "run", "--project", "services/api/Mazeduneh.Api.csproj",
         "--configuration", "Release", "--no-build", "--urls", BASE],
        cwd=ROOT, env=environment, stdout=log, stderr=subprocess.STDOUT,
    )
    try:
        for _ in range(40):
            if process.poll() is not None:
                raise AssertionError("API exited before liveness was available")
            try:
                status, body, _ = request("/health/live")
                assert (status, body) == (200, {"status": "alive"})
                return process
            except (URLError, TimeoutError):
                time.sleep(1)
        raise AssertionError("API did not start within 40 seconds")
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
    api = start_api({"ConnectionStrings__Catalog": ""})
    try:
        assert_ready(503, database="not-configured", migrations="not-configured")
        status, body, _ = request("/health")
        assert status == 200 and body["database"] == "not-configured"
    finally:
        stop_api(api)

    api = start_api({"Admin__TokenSigningKey": ""})
    try:
        assert_ready(503, database="healthy", migrations="tracked", adminAuthentication="not-configured")
    finally:
        stop_api(api)

    api = start_api()
    postgres_container = os.environ.get("READINESS_POSTGRES_CONTAINER")
    postgres_cluster = os.environ.get("READINESS_POSTGRES_CLUSTER")

    def set_postgres_running(running):
        if postgres_container:
            action = "start" if running else "stop"
            subprocess.run(["docker", action, postgres_container], check=True, stdout=subprocess.DEVNULL)
        elif postgres_cluster:
            action = "start" if running else "stop"
            version, cluster = postgres_cluster.split("/", maxsplit=1)
            subprocess.run(["sudo", "pg_ctlcluster", version, cluster, action], check=True, stdout=subprocess.DEVNULL)
        else:
            raise AssertionError("Set READINESS_POSTGRES_CONTAINER or READINESS_POSTGRES_CLUSTER")
    try:
        assert_ready(200, database="healthy", migrations="tracked", adminAuthentication="configured")
        try:
            set_postgres_running(False)
            assert_ready(503, database="unhealthy", migrations="unavailable")
            assert request("/health/live")[:2] == (200, {"status": "alive"})
            status, body, _ = request("/health")
            assert status == 200 and body["status"] == "degraded"
            assert body["migrations"]["status"] == "unavailable"
        finally:
            # Restore the disposable CI dependency even when an assertion fails.
            set_postgres_running(True)

        # The same API process must become ready without a restart.
        for attempt in range(40):
            if request("/health/ready")[0] == 200:
                break
            time.sleep(1)
        else:
            raise AssertionError("API did not recover after PostgreSQL restarted")
        assert_ready(200, database="healthy", migrations="tracked")
    finally:
        stop_api(api)

print("API readiness: missing database, missing authentication, outage, liveness, diagnostics and recovery passed")
