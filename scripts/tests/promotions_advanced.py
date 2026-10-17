"""Real database advanced campaign cases, called by promotions.py."""
import concurrent.futures
import uuid


def run_advanced(request, proof, prefix):
    a, b = prefix + '-A', prefix + '-B'
    fixtures = []
    for suffix, sku, category, price in [('a', a, 'Advanced nuts', 1000000), ('b', b, 'Advanced gifts', 500000)]:
        slug = prefix.lower() + '-' + suffix
        status, body = request('/api/v1/products/', 'POST', {
            'title': 'Advanced campaign fixture', 'slug': slug, 'category': category, 'origin': 'IR', 'currency': 'IRR',
            'unitType': 'Weight', 'isPublished': True,
            'variants': [{'sku': sku, 'quantity': 250, 'displayLabel': '250g', 'price': price, 'availablePackages': 0}]}, True, proof())
        assert status == 201, (status, body)
        fixtures.append(slug)
        status, body = request('/api/v1/admin/inventory/batches', 'POST', {
            'sku': sku, 'batchCode': sku, 'receivedPackages': 40, 'producedAt': '2026-01-01T00:00:00Z',
            'expiresAt': '2030-01-01T00:00:00Z', 'costPrice': 100000, 'packagingCost': 10000,
            'additionalCost': 5000, 'purchasedAt': '2026-01-01T00:00:00Z', 'supplier': 'Advanced test'}, True)
        assert status == 201, (status, body)

    base = {'name': prefix, 'kind': 'Percent', 'value': 10, 'active': True, 'startsAt': '2026-01-01T00:00:00Z',
            'endsAt': '2030-01-01T00:00:00Z', 'maxUses': 100, 'skus': [a, b]}

    def save(suffix, **changes):
        code = prefix + '-' + suffix
        rule = dict(base, **changes)
        status, data = request('/api/v1/admin/promotions/' + code, 'PUT', rule, True, proof())
        assert status == 200, (suffix, status, data)
        return code, rule

    def mobile():
        return '09' + str(int(uuid.uuid4().hex, 16))[-9:]

    def preview(code, lines=None, **contact):
        return request('/api/v1/checkout/coupon-preview', 'POST', dict(
            code=code, lines=lines or [{'sku': a, 'quantity': 2}, {'sku': b, 'quantity': 1}],
            shippingMethod='pickup', **contact))

    def order(code, number, sku=a, key=None):
        return request('/api/v1/checkout/orders', 'POST', {
            'customerName': 'Advanced coupon test', 'mobile': number, 'province': 'Tehran', 'city': 'تهران',
            'address': 'Test address', 'postalCode': '1234567890', 'shippingMethod': 'pickup',
            'lines': [{'sku': sku, 'quantity': 1}], 'couponCode': code},
            headers={'Idempotency-Key': key or str(uuid.uuid4())})

    pack, pack_rule = save('PACK', kind='Bundle', value=0, skus=[], bundleItems=[{'sku': a, 'quantity': 2}, {'sku': b, 'quantity': 1}], bundlePrice=2200000)
    status, data = preview(pack)
    assert status == 200 and data['discount'] == 300000 and data['payable'] == 2420000, (status, data)
    assert preview(pack, [{'sku': a, 'quantity': 2}])[0] == 400
    gift, _ = save('GIFT', kind='BuyGet', value=0, skus=[a], rewardSkus=[b], buyQuantity=2, getQuantity=1, maxApplications=1)
    status, data = preview(gift, [{'sku': a, 'quantity': 4}, {'sku': b, 'quantity': 2}])
    assert status == 200 and data['discount'] == 500000, (status, data)
    assert preview(gift, [{'sku': a, 'quantity': 2}])[0] == 400  # Gift must physically be in basket.
    number = mobile()
    scoped, _ = save('SCOPE', categories=['advanced NUTS'], cities=['تهران'], customerMobiles=[number])
    status, data = preview(scoped, mobile=number, city='تهران')
    assert status == 200 and data['discount'] == 200000, (status, data)
    assert preview(scoped, mobile=number, city='شیراز')[0] == 400
    assert preview(scoped, mobile=mobile(), city='تهران')[0] == 400
    # Pricing access alone must not expose customer allowlists or permit removing them.
    email = prefix.lower() + '@example.test'
    status, invitation = request('/api/v1/admin/users', 'POST', {
        'email': email, 'displayName': 'Campaign privacy fixture', 'role': 'ReadOnlyAnalyst',
        'permissions': ['pricing.read', 'pricing.write', 'audit.read']}, True, proof())
    assert status == 201, (status, invitation)
    password = 'Campaign-Privacy-Fixture-Password!'
    status, data = request('/api/v1/admin/auth/accept-invite', 'POST', {'token': invitation['invitationToken'], 'password': password})
    assert status == 204, (status, data)
    status, limited = request('/api/v1/admin/auth/login', 'POST', {'email': email, 'password': password})
    assert status == 200, (status, limited)
    limited_headers = {'Authorization': 'Bearer ' + limited['accessToken']}
    status, listing = request('/api/v1/admin/promotions', headers=limited_headers)
    personal = next(p for p in listing if p['code'] == scoped)
    assert status == 200 and personal['customerScopeHidden'] and personal['rule']['customerMobiles'] is None
    assert request('/api/v1/admin/audit-log?entityType=Promotion', headers=limited_headers)[0] == 403
    status, step_up = request('/api/v1/admin/auth/step-up', 'POST', {'password': password}, headers=limited_headers)
    assert status == 200, (status, step_up)
    limited_headers['X-Admin-Step-Up'] = step_up['stepUpToken']
    assert request('/api/v1/admin/promotions/' + scoped, 'PUT', base, headers=limited_headers)[0] == 403
    assert request('/api/v1/admin/promotions/preview', 'POST', {'rule': base, 'lines': [{'sku': a, 'quantity': 1}], 'mobile': number}, headers=limited_headers)[0] == 403
    per_contact, _ = save('CONTACT', maxUsesPerCustomer=1)
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(lambda sku: order(per_contact, number, sku), [a, b]))
    assert sorted(status for status, _ in results) == [201, 409], results
    first1, _ = save('FIRST1', firstOrderOnly=True)
    first2, _ = save('FIRST2', firstOrderOnly=True)
    first_mobile = mobile()
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        futures = [pool.submit(order, first1, first_mobile, a), pool.submit(order, first2, first_mobile, b)]
        results = [f.result() for f in futures]
    assert sorted(status for status, _ in results) == [201, 409], results
    assert preview(first1, mobile=number)[0] == 400  # An order with a different coupon still counts.
    regular_mobile = mobile()
    assert order(None, regular_mobile)[0] == 201
    assert order(first2, regular_mobile)[0] == 409  # An order without any coupon also counts.
    auto1, _ = save('AUTO1', automatic=True, priority=20, value=5)
    auto2, _ = save('AUTO2', automatic=True, priority=10, value=50)
    status, data = preview('')
    assert status == 200 and data['code'] == auto1, (status, data)
    save('AUTO2', automatic=True, priority=20, value=50)
    status, data = preview('')
    assert status == 200 and data['code'] == auto2 and data['automatic'], (status, data)
    explicit, _ = save('MANUAL', value=10)
    status, data = preview(explicit)
    assert status == 200 and data['code'] == explicit and data['discount'] == 250000, (status, data)
    key, auto_mobile = str(uuid.uuid4()), mobile()
    status, saved = order(None, auto_mobile, key=key)
    assert status == 201 and saved['couponCode'] == auto2 and saved['discount'] == 500000, (status, saved)
    save('AUTO2', automatic=True, priority=20, value=1, active=False)
    status, replay = order(None, auto_mobile, key=key)
    assert status == 200 and replay['id'] == saved['id'] and replay['discount'] == 500000, (status, replay)
    save('AUTO1', automatic=True, priority=20, value=5, active=False)
    for slug in fixtures:
        status, data = request('/api/v1/products/' + slug + '/publication', 'PATCH', {'isPublished': False}, True)
        assert status == 200, (status, data)
    print('Advanced campaigns: bundles, gifts, scope, per-contact and cross-campaign first-order concurrency, automatic conflict policy and snapshots passed')
