const { test } = require('node:test');
const assert = require('node:assert/strict');
process.env.NEXT_PUBLIC_MAZEDUNEH_API_URL = 'https://catalog.test';
process.env.NEXT_PUBLIC_MAZEDUNEH_DEMO_MODE = 'false';
const { initialCatalog, catalogSuccess, catalogFailure } = require('../.test-build/catalog-state.js');
const { mapApiProduct, fetchLiveProducts, fetchLiveCategories } = require('../.test-build/api-catalog.js');
const { formatRialsAsTomans, formatMoney, formatNumber, rialsToTomans } = require('../.test-build/formatters.js');
const { parseCommerceSettings, estimateCommerce } = require('../.test-build/commerce-settings.js');
const preview = [{ id: 'preview-only' }];

test('explicit demo mode overrides a configured API without changing live mode', () => {
  const { execFileSync } = require('node:child_process');
  const command = "process.stdout.write(require('./.test-build/api-catalog.js').API_BASE)";
  for (const [mode, expected] of [['true', ''], ['false', 'https://catalog.test']]) {
    assert.equal(execFileSync(process.execPath, ['-e', command], { encoding: 'utf8',
      env: { ...process.env, NEXT_PUBLIC_MAZEDUNEH_DEMO_MODE: mode } }), expected);
  }
});

test('shipping and tax follow live rial settings, selected method and exact free-shipping threshold', () => {
  const settings = parseCommerceSettings({ taxRatePercent: 9.5, shippingMethods: [
    { code: 'post', title: 'پست', price: 321000, freeAbove: 9000000, isActive: true },
    { code: 'pickup', title: 'تحویل حضوری', price: 0, freeAbove: 0, isActive: true },
    { code: 'disabled', title: 'غیرفعال', price: 1, freeAbove: 0, isActive: false },
  ] });
  assert.equal(estimateCommerce(580000, settings).shipping, 32100);
  assert.equal(estimateCommerce(580000, settings).tax, 55100);
  assert.equal(estimateCommerce(580000, settings).total, 667200);
  assert.equal(estimateCommerce(899999.9, settings).shipping, 32100);
  assert.equal(estimateCommerce(900000, settings).shipping, 0);
  assert.equal(estimateCommerce(580000, settings, 'pickup').total, 635100);
  assert.equal(estimateCommerce(580000, settings, 'disabled'), null);
  assert.equal(estimateCommerce(580000, null), null);
  assert.equal(parseCommerceSettings({ taxRatePercent: 101, shippingMethods: [] }), null);
  assert.equal(parseCommerceSettings({ taxRatePercent: 10, shippingMethods: [{ code: 'post', title: 'bad', price: -1, freeAbove: 0, isActive: true }] }), null);
});

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
  variants: [{ sku: 'ADMIN-250', quantity: 250, displayLabel: '250 گرم', price: 60005, availablePackages: 0 },
    { sku: 'ADMIN-500', quantity: 500, displayLabel: '500 گرم', price: 110005, availablePackages: 3 }],
};
test('adapter uses server SKU, prices and stock, and retains sold-out variants/products', () => {
  const product = mapApiProduct(source);
  assert.equal(product.sku, 'ADMIN-500');
  assert.equal(product.price, 11000.5);
  assert.equal(product.variants[0].price, 6000.5);
  assert.equal(product.title, 'محصول ۱۲');
  assert.equal(product.variants.length, 2);
  assert.equal(mapApiProduct({ ...source, variants: [source.variants[0]] }).stock, 0);
  assert.equal(mapApiProduct({ ...source, isPublished: false }), null);
  assert.equal(source.variants[0].sku, 'ADMIN-250');
});
test('money displays whole tomans while calculations retain original rial precision', () => {
  assert.equal(formatRialsAsTomans(1234565), '۱۲۳٬۴۵۷');
  assert.equal(formatRialsAsTomans(1234564), '۱۲۳٬۴۵۶');
  assert.equal(formatRialsAsTomans(-1234565), '‎−۱۲۳٬۴۵۷');
  assert.equal(formatRialsAsTomans(0), '۰');
  assert.equal(formatMoney(123456.5), '۱۲۳٬۴۵۷');
  assert.equal(rialsToTomans(1234565), 123456.5);
  assert.equal(formatNumber(1.25), '۱٫۲۵'); // Weights/percentages retain decimals.
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
