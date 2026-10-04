const { test } = require('node:test');
const assert = require('node:assert/strict');
process.env.NEXT_PUBLIC_MAZEDUNEH_API_URL = 'https://catalog.test';
const { initialCatalog, catalogSuccess, catalogFailure } = require('../.test-build/catalog-state.js');
const { mapApiProduct, fetchLiveProducts, fetchLiveCategories } = require('../.test-build/api-catalog.js');
const preview = [{ id: 'preview-only' }];

test('configured API never uses preview products while loading, empty or failed', () => {
  assert.deepEqual(initialCatalog(true, preview, ['همه', 'نمونه']).products, []);
  assert.deepEqual(catalogFailure(initialCatalog(true, preview, [])).products, []);
  assert.deepEqual(catalogSuccess([], []).products, []);
  assert.deepEqual(initialCatalog(false, preview, []).products, preview);
});
test('failed refresh retains only the last live snapshot with stale state', () => {
  const live = catalogSuccess([{ id: 'admin-edited' }], ['دسته جدید', 'دسته جدید']);
  assert.deepEqual(live.categories, ['دسته جدید']);
  const stale = catalogFailure(live);
  assert.equal(stale.status, 'stale');
  assert.deepEqual(stale.products, live.products);
  assert.deepEqual(catalogFailure(stale).products, live.products);
});
const source = {
  id: 'server-id', slug: 'admin-product', title: 'محصول 12', category: 'دسته مدیر', origin: 'ایران',
  currency: 'IRR', unitType: 'Weight', isPublished: true,
  variants: [{ sku: 'ADMIN-250', quantity: 250, displayLabel: '250 گرم', price: 60000, availablePackages: 0 },
    { sku: 'ADMIN-500', quantity: 500, displayLabel: '500 گرم', price: 110000, availablePackages: 3 }],
};
test('adapter uses server SKU, prices and stock, and retains sold-out variants/products', () => {
  const product = mapApiProduct(source);
  assert.equal(product.sku, 'ADMIN-500');
  assert.equal(product.price, 11000);
  assert.equal(product.title, 'محصول ۱۲');
  assert.equal(product.variants.length, 2);
  assert.equal(mapApiProduct({ ...source, variants: [source.variants[0]] }).stock, 0);
  assert.equal(mapApiProduct({ ...source, isPublished: false }), null);
  assert.equal(source.variants[0].sku, 'ADMIN-250');
});
test('catalog fetch rejects server errors, respects empty results and active categories', async () => {
  const old = global.fetch;
  try {
    global.fetch = async (url, options) => {
      assert.equal(options.cache, 'no-store');
      return new Response(JSON.stringify(url.endsWith('/categories')
        ? [{ name: 'دسته 12', isActive: true }, { name: 'غیرفعال', isActive: false }] : []));
    };
    assert.deepEqual(await fetchLiveProducts(), []);
    assert.deepEqual(await fetchLiveCategories(), ['دسته ۱۲']);
    global.fetch = async () => new Response('', { status: 503 });
    await assert.rejects(fetchLiveProducts(), /catalog-503/);
  } finally { global.fetch = old; }
});
