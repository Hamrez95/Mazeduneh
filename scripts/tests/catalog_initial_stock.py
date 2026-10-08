"""Real API regression for zero-stock creation, variant addition and receiving."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[2]
BASE = "http://127.0.0.1:5104"
SLUG = "zero-opening-stock-fixture"
ZERO, POSITIVE, ADDED = "CI-OPENING-ZERO", "CI-OPENING-POSITIVE", "CI-OPENING-ADDED"


def request(path, method="GET", body=None, token=None, extra_headers=None):
    headers = {"Content-Type": "application/json"} if body is not None else {}
    headers.update(extra_headers or {})
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


def start_api():
    process = subprocess.Popen(["dotnet", "run", "--project", "services/api/Mazeduneh.Api.csproj",
                                "--configuration", "Release", "--no-build", "--urls", BASE],
                               cwd=ROOT, env=os.environ.copy(), stdout=log, stderr=subprocess.STDOUT)
    try:
        for _ in range(40):
            if process.poll() is not None:
                raise AssertionError("Catalog test API exited")
            try:
                if request("/health/live")[0] == 200:
                    status, login = request("/api/v1/admin/auth/login", "POST", {
                        "email": os.environ["Admin__Email"], "password": "Mazeduneh-CI-Owner-Password!"})
                    assert status == 200
                    return process, login["accessToken"]
            except (URLError, TimeoutError):
                pass
            time.sleep(1)
        raise AssertionError("Catalog test API did not start")
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


def variant(sku, stock, quantity=250):
    return {"sku": sku, "quantity": quantity, "displayLabel": "بسته تست", "price": 1000, "availablePackages": stock}


def movements(sku):
    status, items = request("/api/v1/admin/inventory/movements?sku=" + sku, token=token)
    assert status == 200
    return items


with tempfile.TemporaryFile() as log:
    api, token = start_api()
    try:
        product = {"title": "محصول تست موجودی اولیه", "slug": SLUG, "category": "آزمایشی", "origin": "ایران",
                   "currency": "IRR", "unitType": "Weight", "isPublished": False,
                   "variants": [variant(ZERO, 0), variant(POSITIVE, 3, 500)]}
        status, created = request("/api/v1/products/", "POST", product, token)
        assert status == 201, status
        assert movements(ZERO) == []
        initial = movements(POSITIVE)
        assert len(initial) == 1 and initial[0]["movementType"] == "InitialStock"
        assert initial[0]["quantityDelta"] == 3 and initial[0]["balanceAfter"] == 3

        product["variants"].append(variant(ADDED, 0, 750))
        status, _ = request("/api/v1/products/" + SLUG, "PUT", product, token)
        assert status == 200, status
        assert movements(ADDED) == []
        assert len(movements(POSITIVE)) == 1  # Editing does not duplicate opening stock.

        status, adjusted = request("/api/v1/admin/inventory/adjust", "POST", {
            "sku": ZERO, "quantityDelta": 5, "reason": "ci-receiving-zero-opening"}, token, {"Idempotency-Key": "ci-initial-stock-adjust-01"})
        assert status == 200 and adjusted["balanceAfter"] == 5
        received = movements(ZERO)
        assert len(received) == 1 and received[0]["quantityDelta"] == 5
        assert received[0]["movementType"] == "ManualAdjustment"
        assert received[0]["actor"] == os.environ["Admin__Email"]
        # The public storefront reads the same catalog that the authenticated Admin edits.
        assert request('/api/v1/products/' + SLUG + '/publication', 'PATCH', {'isPublished': True}, token)[0] == 200
        assert request('/api/v1/products/' + SLUG)[1]['title'] == product['title']
        product['title'] = 'عنوان ویرایش‌شده در پنل'
        product['description'] = 'توضیح جدید پنل'
        product['variants'][0]['price'] = 43210
        assert request('/api/v1/products/' + SLUG, 'PUT', product, token)[0] == 200
        status, public = request('/api/v1/products/' + SLUG)
        assert status == 200 and public['title'] == product['title'] and public['description'] == product['description']
        public_variants = {item['sku']: item for item in public['variants']}
        assert public_variants[ZERO]['price'] == 43210 and public_variants[ZERO]['availablePackages'] == 5
        assert public_variants[ADDED]['availablePackages'] == 0  # Sold-out SKU is still an editable catalog entry.
        assert all(item['costPrice'] == 0 for item in public['variants'])
        assert request('/api/v1/products/' + SLUG + '/publication', 'PATCH', {'isPublished': False}, token)[0] == 200
        assert request('/api/v1/products/' + SLUG)[0] == 404
        invalid = dict(product, slug="negative-opening-stock-fixture", variants=[variant("CI-NEGATIVE-STOCK", -1)])
        assert request("/api/v1/products/", "POST", invalid, token)[0] == 400
    finally:
        stop_api(api)

    api, token = start_api()
    try:
        status, products = request("/api/v1/products/admin", token=token)
        persisted = next(item for item in products if item["slug"] == SLUG)
        balances = {item["sku"]: item["availablePackages"] for item in persisted["variants"]}
        assert status == 200 and balances == {ZERO: 5, POSITIVE: 3, ADDED: 0}
        assert request("/api/v1/products/" + SLUG)[0] == 404  # Draft remains private.
        assert len(movements(ZERO)) == 1 and len(movements(POSITIVE)) == 1
    finally:
        stop_api(api)

print("Catalog stock: zero creation/addition, positive ledger, receiving, validation and restart passed")
