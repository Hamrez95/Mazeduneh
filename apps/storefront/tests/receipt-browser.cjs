const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const { mkdir, readFile } = require('node:fs/promises');
const { chromium } = require('playwright');
const origin = 'http://127.0.0.1:3097';
const api = 'http://127.0.0.1:5997';
const id = '2a306b34-f031-f83a-92b5-026cb57bce63';
const token = 'receipt-browser-secret';
const lines = [{ productTitle: 'کوکی پروتئینی', sku: 'COOKIE-250', variantLabel: '۲۵۰ گرم', quantity: 1, lineTotal: 2000001 },
  { productTitle: 'کوکی پروتئینی', sku: 'COOKIE-500', variantLabel: '۵۰۰ گرم', quantity: 1, lineTotal: 3800000 }];
const saved = { name: 'سارا رضایی', orderId: id, receiptToken: token, payable: 6050001, tax: 0, shipping: 750000,
  subtotal: 5800001, discount: 500000, state: 'AwaitingPayment', expiresAt: '2030-10-22T12:00:00Z', lines };
const server = spawn(process.execPath, ['node_modules/next/dist/bin/next', 'dev', ...(process.platform === 'win32' ? ['--webpack'] : []), '--hostname', '127.0.0.1', '--port', '3097'], {
  env: { ...process.env, NEXT_PUBLIC_MAZEDUNEH_API_URL: api, NEXT_PUBLIC_MAZEDUNEH_API_BASE_URL: api,
    MAZEDUNEH_STATIC_EXPORT: 'false', NEXT_TELEMETRY_DISABLED: '1' }, stdio: ['ignore', 'pipe', 'pipe'],
});
let log = '';
server.stdout.on('data', b => { log = (log + b).slice(-6000); });
server.stderr.on('data', b => { log = (log + b).slice(-6000); });
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));

(async () => {
  let browser;
  try {
    for (let i = 0; i < 100; i++) {
      if (server.exitCode !== null) throw new Error('Next exited: ' + log);
      try { if ((await fetch(origin, { signal: AbortSignal.timeout(5000) })).ok) break; } catch {}
      if (i === 99) throw new Error('Next did not become ready: ' + log);
      await delay(500);
    }
    browser = await chromium.launch({ ...(process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH ? { executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH } : {}) });
    await mkdir('.test-results', { recursive: true });
    const font = (await readFile('../../services/api/Assets/Fonts/Vazirmatn-Regular.ttf')).toString('base64');
    const fontCss = `@font-face{font-family:Vazirmatn;src:url(data:font/ttf;base64,${font}) format('truetype');font-weight:100 900}`;
    for (const width of [360, 768, 1280]) {
      const context = await browser.newContext({ viewport: { width, height: 1000 }, reducedMotion: 'reduce' });
      const errors = [];
      let state = 'AwaitingPayment';
      let invoiceRequests = 0;
      let intentRequests = 0;
      await context.addInitScript(({ saved, token }) => {
        if (sessionStorage.getItem('receipt-test-seeded')) return;
        sessionStorage.setItem('receipt-test-seeded', 'yes');
        sessionStorage.setItem('mazedooneh-checkout-receipt-v1', JSON.stringify(saved));
        localStorage.setItem('mazedooneh-cart-v1', JSON.stringify([{ id: 'cookie', title: 'کوکی پروتئینی', sku: 'COOKIE-250', price: 200000.1, quantity: 1, stock: 3 }]));
      }, { saved, token });
      await context.route('https://fonts.googleapis.com/**', route => route.fulfill({ contentType: 'text/css', body: fontCss }));
      await context.route(api + '/**', async route => {
        const request = route.request();
        const path = new URL(request.url()).pathname;
        const headers = { 'access-control-allow-origin': '*', 'content-type': 'application/json' };
        if (path === `/api/v1/checkout/orders/${id}/invoice`) {
          assert.equal(request.headers()['x-order-receipt-token'], token);
          assert.equal(new URL(request.url()).search, '');
          invoiceRequests++;
          await route.fulfill({ contentType: 'text/html', body: '<!doctype html><html lang="fa" dir="rtl"><title>فاکتور مزه‌دونه</title></html>' });
        } else if (path === `/api/v1/checkout/orders/${id}`) {
          assert.equal(request.headers()['x-order-receipt-token'], token);
          await route.fulfill({ headers, body: JSON.stringify({ ...saved, id, customerName: saved.name, state, lines, reservationExpiresAt: saved.expiresAt }) });
        } else if (path === '/api/v1/checkout/orders' && request.method() === 'POST') {
          await route.fulfill({ status: 200, headers, body: JSON.stringify({ ...saved, id, receiptToken: token, state: 'Paid', reservationExpiresAt: saved.expiresAt }) });
        } else if (path.endsWith('/intent')) {
          intentRequests++;
          await route.fulfill({ status: 503, headers, body: JSON.stringify({ message: 'درگاه موقتاً در دسترس نیست.' }) });
        } else {
          const body = path.endsWith('/shipping-methods') ? { shippingMethods: [] }
            : path.endsWith('/coupon-preview') ? { discount: 0, shipping: 750000, tax: 0, payable: 6050001 } : [];
          await route.fulfill({ headers, body: JSON.stringify(body) });
        }
      });
      const page = await context.newPage();
      page.on('pageerror', error => errors.push(error.message));
      const callback = outcome => `${origin}/checkout?orderId=${id}&payment=${outcome}`;
      await page.goto(callback('success'));
      await page.getByText('وضعیت پرداخت هنوز قطعی نیست.', { exact: false }).waitFor();
      assert.equal(await page.getByRole('heading', { name: /خریدت کامل شد/ }).count(), 0, 'success URL alone must not claim payment');
      assert.equal(JSON.parse(await page.evaluate(() => localStorage.getItem('mazedooneh-cart-v1'))).length, 1);
      state = 'Paid';
      await page.getByRole('button', { name: 'بررسی دوبارهٔ وضعیت پرداخت' }).click();
      await page.getByRole('heading', { name: /خریدت کامل شد/ }).waitFor();
      assert.equal(await page.getByText('سارا رضایی عزیز،', { exact: true }).count(), 1);
      assert.equal(await page.getByRole('heading', { name: 'انتخاب‌های خوشمزهٔ تو' }).count(), 1);
      assert.equal(await page.locator('li').filter({ hasText: '۲۵۰ گرم' }).count(), 1);
      await page.waitForFunction(() => JSON.parse(localStorage.getItem('mazedooneh-cart-v1')).length === 0);
      assert.equal((await page.evaluate(() => JSON.parse(sessionStorage.getItem('mazedooneh-checkout-receipt-v1')))).state, 'Paid');
      assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1), true, `receipt overflow at ${width}`);
      const download = page.waitForEvent('download');
      await page.getByRole('button', { name: 'دانلود فاکتور خرید' }).click();
      assert.equal((await download).suggestedFilename(), `mazeduneh-invoice-${id}.html`);
      assert.equal(invoiceRequests, 1);
      await page.screenshot({ path: `.test-results/receipt-${width}.png`, fullPage: true });
      state = 'Preparing';
      await page.reload();
      await page.getByText('در حال آماده‌سازی', { exact: true }).waitFor();
      assert.equal(await page.getByRole('heading', { name: /خریدت کامل شد/ }).count(), 1);
      for (const [nextState, heading] of [['Cancelled', 'این سفارش لغو شده است.'], ['Expired', 'مهلت پرداخت این سفارش تمام شده است.']]) {
        state = nextState;
        await page.goto(callback('review'));
        await page.getByRole('heading', { name: heading, exact: true }).waitFor();
        assert.equal(await page.getByText('مبلغ پرداخت‌شده', { exact: true }).count(), 0);
      }
      await page.evaluate(({ saved }) => { sessionStorage.setItem('mazedooneh-checkout-receipt-v1', JSON.stringify(saved)); }, { saved });
      await page.goto(callback('failed'));
      await page.getByRole('heading', { name: /پرداختت تأیید نشد/ }).waitFor();
      await page.getByRole('button', { name: 'ادامهٔ پرداخت', exact: true }).click();
      await page.getByText('درگاه موقتاً در دسترس نیست.', { exact: true }).waitFor();
      if (width === 360) {
        await page.evaluate(() => localStorage.setItem('mazedooneh-cart-v1', JSON.stringify([{ id: 'cookie', title: 'کوکی پروتئینی', sku: 'COOKIE-250', price: 200000.1, quantity: 1, stock: 3 }])));
        await page.goto(origin + '/checkout');
        await page.getByLabel('نام و نام خانوادگی').fill(saved.name);
        await page.getByLabel('شماره موبایل').fill('09120000000');
        await page.getByLabel('استان').selectOption({ label: 'تهران' });
        await page.getByLabel('شهر').fill('تهران');
        await page.getByLabel('نشانی کامل').fill('نشانی نمونه');
        await page.getByLabel('کد پستی').fill('1234567890');
        const before = intentRequests;
        await page.getByRole('button', { name: 'ثبت سفارش و بررسی مبلغ نهایی' }).click();
        await page.getByRole('heading', { name: /خریدت کامل شد/ }).waitFor();
        assert.equal(intentRequests, before, 'replayed paid order must not start another payment');
        assert.ok(page.url().includes('payment=success'), 'confirmed receipt must survive reload');
        state = 'Paid';
        await page.reload();
        await page.getByRole('heading', { name: /خریدت کامل شد/ }).waitFor();
      }
      assert.deepEqual(errors, []);
      await context.close();
    }
    console.log('Receipt browser: server-confirmed success, cart clearing, reload, authorized download, failure/expired/cancelled states and 360/768/1280 layouts passed');
  } finally {
    if (browser) await browser.close();
    server.kill('SIGTERM');
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
