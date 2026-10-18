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


def audit(entity_type, entity_id):
    path = f"/api/v1/admin/audit-log?entityType={entity_type}&entityId={entity_id}&limit=50"
    status, items = request(path, token=token)
    assert status == 200
    return items


with tempfile.TemporaryFile() as log:
    api, token = start_api()
    try:
        product = {"title": "محصول تست موجودی اولیه", "slug": SLUG, "category": "آزمایشی", "origin": "ایران",
                   "currency": "IRR", "unitType": "Weight", "isPublished": False,
                   "variants": [variant(ZERO, 0), variant(POSITIVE, 3, 500)]}
        for invalid_slug, invalid_stock in (
            ("fractional-opening-stock-fixture", 1.5),
            ("overflow-opening-stock-fixture", 2147483648),
        ):
            invalid = dict(product, slug=invalid_slug, variants=[variant("CI-INVALID-STOCK", invalid_stock)])
            status, body = request("/api/v1/products/", "POST", invalid, token)
            assert status == 400, (invalid_slug, status, body)

        status, _ = request("/api/v1/products/", "POST", product, token)
        assert status == 428, status
        status, create_proof = request("/api/v1/admin/auth/step-up", "POST", {
            "password": "Mazeduneh-CI-Owner-Password!"}, token)
        assert status == 200 and create_proof["stepUpToken"]
        status, created = request("/api/v1/products/", "POST", product, token,
                                  {"X-Admin-Step-Up": create_proof["stepUpToken"]})
        assert status == 201, status
        product_events = audit("Product", created["id"])
        product_created = next(item for item in product_events if item["action"] == "product.created")
        created_snapshot = json.loads(product_created["afterJson"])
        assert product_created["actor"] == os.environ["Admin__Email"]
        assert product_created["beforeJson"] is None
        assert created_snapshot["Slug"] == SLUG
        assert any(item["Sku"] == ZERO for item in created_snapshot["Variants"])
        assert product_created["requestId"]
        initial_price_event = next(item for item in audit("ProductVariant", ZERO)
                                   if item["action"] == "product.variant-added")
        assert initial_price_event["actor"] == os.environ["Admin__Email"]
        assert json.loads(initial_price_event["afterJson"])["Price"] == 1000

        category_body = {"name": "دسته ممیزی CI", "slug": "ci-audit-category",
                         "description": "دسته برای بررسی ثبت تغییرات", "sortOrder": 9000, "isActive": True}
        status, created_category = request("/api/v1/categories", "POST", category_body, token)
        assert status == 201, status
        category_id = created_category["id"]
        category_events = audit("Category", category_id)
        category_created = next(item for item in category_events if item["action"] == "category.created")
        assert category_created["actor"] == os.environ["Admin__Email"]
        assert category_created["beforeJson"] is None
        assert json.loads(category_created["afterJson"])["Slug"] == category_body["slug"]

        updated_category_body = dict(category_body, name="دسته ممیزی ویرایش‌شده", slug="ci-audit-category-updated")
        status, _ = request("/api/v1/categories/" + category_body["slug"], "PUT", updated_category_body, token)
        assert status == 200, status
        category_events = audit("Category", category_id)
        category_updated = next(item for item in category_events if item["action"] == "category.updated")
        assert json.loads(category_updated["beforeJson"])["Slug"] == category_body["slug"]
        assert json.loads(category_updated["afterJson"])["Slug"] == updated_category_body["slug"]

        status, _ = request("/api/v1/categories/" + updated_category_body["slug"] + "/active", "PATCH",
                            {"isActive": False}, token)
        assert status == 200, status
        category_events = audit("Category", category_id)
        active_change = next(item for item in category_events if item["action"] == "category.updated")
        assert json.loads(active_change["beforeJson"])["IsActive"] is True
        assert json.loads(active_change["afterJson"])["IsActive"] is False

        status, _ = request("/api/v1/categories/" + updated_category_body["slug"], "DELETE", token=token)
        assert status == 200, status
        category_deleted = next(item for item in audit("Category", category_id) if item["action"] == "category.deleted")
        assert category_deleted["actor"] == os.environ["Admin__Email"]
        assert category_deleted["beforeJson"] and category_deleted["afterJson"] is None

        assert movements(ZERO) == []
        initial = movements(POSITIVE)
        assert len(initial) == 1 and initial[0]["movementType"] == "InitialStock"
        assert initial[0]["quantityDelta"] == 3 and initial[0]["balanceAfter"] == 3

        product["variants"].append(variant(ADDED, 0, 750))
        status, _ = request("/api/v1/products/" + SLUG, "PUT", product, token)
        assert status == 428, status
        status, step_up = request("/api/v1/admin/auth/step-up", "POST", {
            "password": "Mazeduneh-CI-Owner-Password!"}, token)
        assert status == 200 and step_up["stepUpToken"]
        status, _ = request("/api/v1/products/" + SLUG, "PUT", product, token,
                            {"X-Admin-Step-Up": step_up["stepUpToken"]})
        assert status == 200, status
        assert movements(ADDED) == []
        assert len(movements(POSITIVE)) == 1  # Editing does not duplicate opening stock.
        product_events = audit("Product", created["id"])
        product_updated = next(item for item in product_events if item["action"] == "product.updated")
        assert product_updated["actor"] == os.environ["Admin__Email"]
        assert json.loads(product_updated["beforeJson"])["Variants"] != json.loads(product_updated["afterJson"])["Variants"]
        assert product_updated["requestId"]
        status, price_audit = request('/api/v1/admin/audit-log?entityType=ProductVariant&entityId=' + ADDED,
                                      token=token)
        assert status == 200
        price_event = next(item for item in price_audit if item['action'] == 'product.variant-added')
        assert price_event['actor'] == os.environ['Admin__Email']
        assert price_event['beforeJson'] is None and price_event['afterJson']
        assert json.loads(price_event['afterJson'])['Price'] == 1000
        assert price_event['reason'] == 'ثبت گونهٔ تازه با قیمت اولیه'

        status, step_up = request("/api/v1/admin/auth/step-up", "POST", {
            "password": "Mazeduneh-CI-Owner-Password!"}, token)
        assert status == 200 and step_up["stepUpToken"]
        status, adjusted = request("/api/v1/admin/inventory/adjust", "POST", {
            "sku": ZERO, "quantityDelta": 5, "reason": "ci-receiving-zero-opening"}, token,
            {"Idempotency-Key": "ci-initial-stock-adjust-01", "X-Admin-Step-Up": step_up["stepUpToken"]})
        assert status == 200 and adjusted["balanceAfter"] == 5
        received = movements(ZERO)
        assert len(received) == 1 and received[0]["quantityDelta"] == 5
        assert received[0]["movementType"] == "ManualAdjustment"
        assert received[0]["actor"] == os.environ["Admin__Email"]
        # The public storefront reads the same catalog that the authenticated Admin edits.
        assert request('/api/v1/products/' + SLUG + '/publication', 'PATCH', {'isPublished': True}, token)[0] == 200
        published_event = next(item for item in audit("Product", created["id"]) if item["action"] == "product.publication")
        assert published_event["actor"] == os.environ["Admin__Email"]
        assert json.loads(published_event["beforeJson"])["IsPublished"] is False
        assert json.loads(published_event["afterJson"])["IsPublished"] is True
        assert request('/api/v1/products/' + SLUG)[1]['title'] == product['title']
        product['title'] = 'عنوان ویرایش‌شده در پنل'
        product['description'] = 'توضیح جدید پنل'
        product['variants'][0]['price'] = 43210
        status, _ = request('/api/v1/products/' + SLUG, 'PUT', product, token)
        assert status == 428, status
        status, step_up = request('/api/v1/admin/auth/step-up', 'POST', {
            'password': 'Mazeduneh-CI-Owner-Password!'}, token)
        assert status == 200 and step_up['stepUpToken']
        status, _ = request('/api/v1/products/' + SLUG, 'PUT', product, token,
                            {'X-Admin-Step-Up': step_up['stepUpToken']})
        assert status == 200, status
        updated_product_event = next(item for item in audit("Product", created["id"]) if item["action"] == "product.updated")
        assert json.loads(updated_product_event["beforeJson"])["Title"] != json.loads(updated_product_event["afterJson"])["Title"]
        status, public = request('/api/v1/products/' + SLUG)
        assert status == 200 and public['title'] == product['title'] and public['description'] == product['description']
        public_variants = {item['sku']: item for item in public['variants']}
        # An explicit, stepped-up catalog price edit persists without changing inventory.
        assert public_variants[ZERO]['price'] == 43210 and public_variants[ZERO]['availablePackages'] == 5
        direct_price_event = next(item for item in audit('ProductVariant', ZERO) if item['action'] == 'product.selling-price-updated')
        assert json.loads(direct_price_event['beforeJson'])['Price'] == 1000
        assert json.loads(direct_price_event['afterJson'])['Price'] == 43210
        assert public_variants[ADDED]['availablePackages'] == 0  # Sold-out SKU is still an editable catalog entry.
        assert all(item['costPrice'] == 0 for item in public['variants'])
        assert request('/api/v1/products/' + SLUG + '/publication', 'PATCH', {'isPublished': False}, token)[0] == 200
        unpublished_event = next(item for item in audit("Product", created["id"]) if item["action"] == "product.publication")
        assert json.loads(unpublished_event["beforeJson"])["IsPublished"] is True
        assert json.loads(unpublished_event["afterJson"])["IsPublished"] is False
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
        assert next(v for v in persisted['variants'] if v['sku'] == ZERO)['price'] == 43210
        assert request("/api/v1/products/" + SLUG)[0] == 404  # Draft remains private.
        assert len(movements(ZERO)) == 1 and len(movements(POSITIVE)) == 1
    finally:
        stop_api(api)

print("Catalog stock and audit: product/category mutations, actor, before/after, request ID, validation and restart passed")

