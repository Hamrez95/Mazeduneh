const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const { chromium } = require('playwright');
const { mkdir } = require('node:fs/promises');
const origin = 'http://127.0.0.1:3098';
const api = 'http://127.0.0.1:5998';
const product = (slug, title, stock = 3) => ({ id: slug, slug, title, category: 'دسته پنل', origin: 'ایران',
  currency: 'IRR', unitType: 'Weight', isPublished: true, description: 'توضیح ثبت‌شده در پنل',
  variants: [{ sku: slug.toUpperCase(), quantity: 250, displayLabel: '۲۵۰ گرم', price: 321000, availablePackages: stock }] });
const server = spawn(process.execPath, ['node_modules/next/dist/bin/next', 'dev', ...(process.platform === 'win32' ? ['--webpack'] : []), '--hostname', '127.0.0.1', '--port', '3098'], {
  env: { ...process.env, NEXT_PUBLIC_MAZEDUNEH_API_URL: api, NEXT_PUBLIC_MAZEDUNEH_API_BASE_URL: api,
    MAZEDUNEH_STATIC_EXPORT: 'false', NEXT_PUBLIC_MAZEDUNEH_DEMO_MODE: 'false', NEXT_TELEMETRY_DISABLED: '1' }, stdio: ['ignore', 'pipe', 'pipe'],
});
let log = '';
server.stdout.on('data', (b) => { log = (log + b).slice(-6000); });
server.stderr.on('data', (b) => { log = (log + b).slice(-6000); });
const delay = (ms) => new Promise((r) => setTimeout(r, ms));
async function ready() {
  for (let i = 0; i < 90; i++) {
    if (server.exitCode !== null) throw new Error('Next server exited: ' + log);
    try { if ((await fetch(origin)).ok) return; } catch {}
    await delay(500);
  }
  throw new Error('Next did not become ready: ' + log);
}

(async () => {
  let browser;
  try {
    await ready();
    browser = await chromium.launch({
      ...(process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH
        ? { executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH }
        : {}),
    });
    await mkdir('.test-results', { recursive: true });
    for (const width of [360, 768, 1280]) {
      const context = await browser.newContext({ viewport: { width, height: 1000 }, reducedMotion: 'reduce' });
      const page = await context.newPage();
      const errors = [];
      page.on('pageerror', (error) => errors.push(error.message));
      let records = [product('live-nut', 'پسته پنل'), product('live-almond', 'بادام پنل', 0)];
      let orderRequests = 0;
      let lastCheckout = null;
      records[0].variants[0].price = 2000000;
      records[0].variants.push({ sku: 'LIVE-NUT-500', quantity: 500, displayLabel: '۵۰۰ گرم', price: 3800000, availablePackages: 2 });
      let failing = false;
      await context.route(api + '/**', async (route) => {
        const path = new URL(route.request().url()).pathname;
        if (path === '/api/v1/checkout/orders') {
          orderRequests++;
          lastCheckout = route.request().postDataJSON();
          await delay(500);
          await route.fulfill({ status: 201, headers: { 'access-control-allow-origin': '*', 'content-type': 'application/json' },
            body: JSON.stringify({ id: 'order-test', receiptToken: 'receipt-test', payable: 8250000, tax: 0, shipping: 750000, shippingMethod: 'post', state: 'AwaitingPayment', reservationExpiresAt: '2026-10-20T12:00:00Z' }) });
          return;
        }
        const body = path.endsWith('/categories') ? (records.length ? [{ name: 'دسته پنل', isActive: true }] : [])
          : path.endsWith('/shipping-methods') ? { taxRatePercent: 9.5, shippingMethods: [{ code: 'post', title: 'پست', price: 321000, freeAbove: 9000000, isActive: true }, { code: 'pickup', title: 'تحویل حضوری', price: 0, freeAbove: 0, isActive: true }] }
          : path.endsWith('/coupon-preview') ? { discount: 0, shipping: 750000, tax: 0, payable: 8250000 }
          : path.endsWith('/products') ? records : records.find((item) => path.endsWith('/' + item.slug));
        await route.fulfill({ status: failing ? 503 : body ? 200 : 404,
          headers: { 'access-control-allow-origin': '*', 'content-type': 'application/json' },
          body: JSON.stringify(failing ? { message: 'offline' } : body ?? {}) });
      });
      await page.goto(origin, { waitUntil: 'domcontentloaded' });
      await page.getByRole('heading', { name: 'پسته پنل', exact: true }).waitFor();
      assert.equal(await page.getByRole('heading', { name: 'پسته اکبری ممتاز', exact: true }).count(), 0);
      await page.getByRole('heading', { name: 'بادام پنل', exact: true }).waitFor();
      const soldOut = page.getByRole('article').filter({ has: page.getByRole('heading', { name: 'بادام پنل', exact: true }) });
      assert.equal(await soldOut.getByRole('button', { name: /افزودن به سبد/ }).isDisabled(), true);
      assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth + 1), true, `overflow at ${width}`);
      await page.screenshot({ path: `.test-results/catalog-${width}.png`, fullPage: true });

      records[0] = { ...records[0], title: 'پسته ویرایش‌شده در پنل' };
      await page.evaluate(() => window.dispatchEvent(new Event('focus')));
      await page.getByRole('heading', { name: records[0].title, exact: true }).waitFor();
      failing = true;
      await page.evaluate(() => window.dispatchEvent(new Event('focus')));
      await page.getByText(/اتصال قطع شده؛ آخرین محصولات/).waitFor();
      assert.equal(await page.getByRole('heading', { name: records[0].title, exact: true }).count(), 1);
      failing = false;
      await page.getByRole('button', { name: 'دریافت دوباره', exact: true }).focus();
      await page.keyboard.press('Enter');
      await page.getByText(/اتصال قطع شده؛ آخرین محصولات/).waitFor({ state: 'hidden' });

      await page.goto(origin + '/shop', { waitUntil: 'domcontentloaded' });
      await page.getByRole('heading', { name: records[0].title, exact: true }).waitFor();
      await page.goto(origin + '/product/live-nut', { waitUntil: 'domcontentloaded' });
      await page.getByRole('heading', { name: records[0].title, exact: true }).waitFor();
      await page.getByRole('heading', { name: 'بادام پنل', exact: true }).waitFor();
      assert.equal(await page.getByText('پسته اکبری ممتاز', { exact: true }).count(), 0);
      assert.equal(await page.getByText('ثبت دیدگاه در پیش‌نمایش', { exact: true }).count(), 0);
      assert.equal(await page.locator('.reviewCard').count(), 0);
      const selectedPrice = page.getByRole('status', { name: 'قیمت بستهٔ انتخاب‌شده', exact: true });
      assert.match(await selectedPrice.textContent(), /۲۰۰٬۰۰۰/);
      const bigPack = page.getByRole('option', { name: /۵۰۰ گرم/ });
      await bigPack.click();
      assert.equal(await bigPack.getAttribute('aria-selected'), 'true');
      assert.match(await selectedPrice.textContent(), /۳۸۰٬۰۰۰/);
      await page.getByRole('button', { name: 'افزودن به سبد خرید', exact: true }).click();
      await page.getByRole('option', { name: /۲۵۰ گرم/ }).click();
      assert.match(await selectedPrice.textContent(), /۲۰۰٬۰۰۰/);
      await page.getByRole('button', { name: 'افزودن به سبد خرید', exact: true }).click();
      await page.goto(origin + '/cart', { waitUntil: 'domcontentloaded' });
      await page.getByText('۵۰۰ گرم', { exact: true }).waitFor();
      await page.getByText('۲۵۰ گرم', { exact: true }).waitFor();
      await page.reload({ waitUntil: 'domcontentloaded' });
      await page.getByText('۵۰۰ گرم', { exact: true }).waitFor();
      await page.getByText('۲۵۰ گرم', { exact: true }).waitFor();
      assert.equal(await page.getByText('سبد خرید خالی است', { exact: true }).count(), 0);

      if (width === 360) {
        await page.goto(origin + '/checkout', { waitUntil: 'domcontentloaded' });
        await page.getByRole('heading', { name: 'اطلاعات تحویل سفارش', exact: true }).waitFor();
        const summary = await page.getByRole('heading', { name: 'مرور سفارش', exact: true }).boundingBox();
        const submit = await page.getByRole('button', { name: /ثبت سفارش و بررسی مبلغ نهایی/ }).boundingBox();
        assert.ok(summary && submit && summary.y < submit.y, 'mobile order summary must appear before the submit action');
        await page.getByRole('button', { name: 'بررسی تخفیف‌ها', exact: true }).waitFor();
        assert.equal(await page.getByText('بررسی پیشنهادهای خودکار', { exact: true }).count(), 0);
        assert.equal(await page.getByText('ارسال پستی برای این مرحله در نظر گرفته شده است.', { exact: true }).count(), 0);
        await page.getByLabel('نام و نام خانوادگی').fill('مشتری آزمایشی');
        await page.getByLabel('شماره موبایل').fill('۰۹۱۲۰۰۰۰۰۰۰');
        assert.equal(await page.getByLabel('شماره موبایل').evaluate(el => el.checkValidity()), true);
        await page.getByLabel('استان').selectOption({ label: 'تهران' });
        await page.getByLabel('شهر').fill('تهران');
        await page.getByLabel('نشانی کامل').fill('خیابان نمونه، پلاک ۱');
        await page.getByLabel('روش ارسال').selectOption('post');
        await page.getByLabel('کد پستی').fill('۱۲۳۴۵۶۷۸۹۰');
        const submitButton = page.getByRole('button', { name: /ثبت سفارش و بررسی مبلغ نهایی/ });
        await submitButton.click();
        await page.getByRole('heading', { name: /سفارش ثبت شد/ }).waitFor();
        assert.equal(orderRequests, 1, 'one active checkout submission creates one order');
        assert.equal(lastCheckout.mobile, '09120000000');
        assert.equal(lastCheckout.postalCode, '1234567890');
      }


      for (const route of ['/contact', '/returns', '/privacy', '/terms', '/profile', '/shipping']) {
        await page.goto(origin + route, { waitUntil: 'domcontentloaded' });
        await page.getByRole('heading', { level: 1 }).waitFor();
        assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1), true, `${route} overflow at ${width}`);
        assert.equal(await page.locator('a[href^="tel:"], a[href^="mailto:"]').count(), route === '/contact' ? 1 : 0);
      }
      await page.goto(origin + '/contact', { waitUntil: 'domcontentloaded' });
      assert.ok(await page.getByRole('link', { name: 'تلگرام', exact: true }).count() >= 2);
      assert.ok(await page.getByRole('link', { name: 'بله', exact: true }).count() >= 2);
      assert.equal(await page.getByRole('link', { name: 'تلگرام', exact: true }).first().getAttribute('href'), 'https://t.me/+9893339870210');
      assert.equal(await page.getByRole('link', { name: 'بله', exact: true }).first().getAttribute('href'), 'https://ble.ir/mazeduneh');
      assert.equal(await page.getByRole('link', { name: 'تماس تلفنی با مزه‌دونه', exact: true }).getAttribute('href'), 'tel:+9893339870210');
      assert.equal(await page.getByRole('dialog').count(), 0);
      records = [];
      await page.goto(origin, { waitUntil: 'domcontentloaded' });
      await page.getByText('محصولی در این دسته پیدا نشد.', { exact: true }).waitFor();
      assert.equal(await page.getByRole('article').count(), 0);
      failing = true;
      await page.reload({ waitUntil: 'domcontentloaded' });
      await page.getByText(/محصولات دریافت نشد/).waitFor();
      assert.equal(await page.getByRole('article').count(), 0);
      assert.deepEqual(errors, []);
      await context.close();
    }
    console.log('Storefront browser: catalog, real-review empty state, cart hydration/reload, mobile checkout summary, errors and responsive 360/768/1280 passed');
  } finally {
    if (browser) await browser.close();
    server.kill('SIGTERM');
  }
})().catch((error) => { console.error(error); process.exitCode = 1; });
