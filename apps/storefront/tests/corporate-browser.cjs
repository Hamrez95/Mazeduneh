const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const { mkdir } = require('node:fs/promises');
const { chromium } = require('playwright');
const origin = 'http://127.0.0.1:3095';
const api = 'http://127.0.0.1:5995';
const server = spawn(process.execPath, ['node_modules/next/dist/bin/next', 'dev', ...(process.platform === 'win32' ? ['--webpack'] : []), '--hostname', '127.0.0.1', '--port', '3095'], {
  env: { ...process.env, NEXT_PUBLIC_MAZEDUNEH_API_URL: api, NEXT_PUBLIC_MAZEDUNEH_API_BASE_URL: api,
    MAZEDUNEH_RELEASE_BUILD: 'false', MAZEDUNEH_STATIC_EXPORT: 'false', NEXT_PUBLIC_MAZEDUNEH_DEMO_MODE: 'false', NEXT_TELEMETRY_DISABLED: '1' },
  stdio: ['ignore', 'pipe', 'pipe'],
});
let log = '';
for (const stream of [server.stdout, server.stderr]) stream.on('data', data => { log = (log + data).slice(-5000); });
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
async function ready() {
  for (let i = 0; i < 120; i++) {
    if (server.exitCode !== null) throw new Error('Next server exited: ' + log);
    try { if ((await fetch(origin + '/corporate-sales', { signal: AbortSignal.timeout(2000) })).ok) return; } catch {}
    await delay(500);
  }
  throw new Error('Next did not become ready: ' + log);
}
const headers = { 'access-control-allow-origin': '*', 'access-control-allow-headers': '*', 'content-type': 'application/json' };
(async () => {
  let browser;
  try {
    await ready();
    browser = await chromium.launch(process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH ? { executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH } : {});
    await mkdir('.test-results', { recursive: true });
    for (const width of [320, 360, 390, 768, 1024, 1440]) {
      const context = await browser.newContext({ viewport: { width, height: 900 }, reducedMotion: 'reduce' });
      const page = await context.newPage();
      const errors = [];
      page.on('pageerror', error => errors.push(error.message));
      page.on('console', message => { if (/hydration|hydrated|didn't match/i.test(message.text())) errors.push(message.text()); });
      let submitted;
      let fail = true;
      await context.route('https://trustseal.enamad.ir/**', route => route.fulfill({ status: 200, contentType: 'image/svg+xml', body: '<svg xmlns="http://www.w3.org/2000/svg" width="60" height="60" />' }));
      await context.route(api + '/**', async route => {
        const request = route.request();
        const path = new URL(request.url()).pathname;
        if (request.method() === 'OPTIONS') return route.fulfill({ status: 204, headers });
        if (path.endsWith('/corporate-requests')) {
          submitted = request.postDataJSON();
          return route.fulfill({ status: fail ? 503 : 201, headers, body: JSON.stringify(fail ? { message: 'دوباره تلاش کنید؛ اطلاعات حفظ شده است.' } : { id: 'synthetic-corporate-request' }) });
        }
        const body = path.endsWith('/corporate-packages') ? [{ code: 'TEAM', name: 'بستهٔ همکاران', unitPrice: 5000000, isActive: true }]
          : path.endsWith('/shipping-methods') ? { taxRatePercent: 0, shippingMethods: [] } : [];
        return route.fulfill({ status: 200, headers, body: JSON.stringify(body) });
      });
      await page.goto(origin + '/corporate-sales', { waitUntil: 'domcontentloaded' });
      await page.getByRole('heading', { name: 'پیشنهاد مخصوص سازمان شما', exact: true }).waitFor();
      await page.locator('#request select').last().getByRole('option', { name: 'بستهٔ همکاران', exact: true }).waitFor({ state: 'attached' });
      await page.evaluate(async () => { await document.fonts.ready; for (const image of document.querySelectorAll('main img')) { image.loading = 'eager'; await image.decode(); } });
      assert.equal(await page.locator('header').count(), 1);
      assert.equal(await page.locator('footer').count(), 1);
      assert.equal(await page.locator('head meta[name="enamad"]').count(), 1);
      assert.equal(await page.locator('head meta[name="enamad"]').getAttribute('content'), '23492933');
      assert.equal(await page.locator('footer a[href="/privacy"]').count(), 1);
      assert.equal(await page.locator('footer a[href*="trustseal.enamad.ir"]').count(), 1);
      assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth + 1), true, `overflow at ${width}`);
      const typography = await page.locator('main h1, main h2, main select, main textarea').evaluateAll(nodes => nodes.map(node => ({ font: getComputedStyle(node).fontFamily, spacing: getComputedStyle(node).letterSpacing })));
      assert.ok(typography.every(item => item.font.includes('Vazirmatn') && ['normal', '0px'].includes(item.spacing)), `Persian typography at ${width}`);
      assert.equal(await page.evaluate(() => document.fonts.check('700 20px Vazirmatn', 'پیشنهاد مخصوص سازمان شما')), true);
      const hero = page.locator('main > section').first();
      const image = await hero.locator('img').boundingBox();
      const copy = await hero.locator(':scope > div').boundingBox();
      const frame = await hero.locator('figure').boundingBox();
      assert.ok(image.x >= frame.x - 1 && image.x + image.width <= frame.x + frame.width + 1, `hero image escapes frame at ${width}`);
      const intersection = Math.min(image.x + image.width, copy.x + copy.width) > Math.max(image.x, copy.x) + 1 && Math.min(image.y + image.height, copy.y + copy.height) > Math.max(image.y, copy.y) + 1;
      assert.equal(intersection, false, `hero image overlaps copy at ${width}`);
      await page.screenshot({ path: `.test-results/corporate-${width}.png`, fullPage: true });
      if (width === 390 || width === 1440) await hero.screenshot({ path: `.test-results/corporate-hero-${width}.png` });
      if (width <= 390) {
        await page.getByRole('button', { name: 'باز کردن فهرست', exact: true }).click();
        await page.getByRole('navigation', { name: 'ناوبری فروشگاه' }).getByRole('link', { name: 'همهٔ محصولات', exact: true }).waitFor({ state: 'visible' });
        await page.getByRole('button', { name: 'بستن فهرست', exact: true }).first().click();
      }
      await page.getByRole('button', { name: 'برای این ایده پیشنهاد می‌خواهم ←', exact: true }).first().click();
      assert.equal(await page.locator('[name="occasion"]').inputValue(), 'قدردانی از همکاران');
      await page.locator('input[name="customerName"]').fill('خریدار آزمایشی');
      await page.getByText('یک هدیهٔ خوش‌طعم، با بودجهٔ شما', { exact: true }).waitFor({ state: 'hidden', timeout: 5000 });
      await page.locator('input[name="companyName"]').fill('سازمان آزمایشی');
      await page.locator('input[name="mobile"]').fill('۰۹۱۲۱۱۱۱۱۱۱');
      await page.locator('input[name="city"]').fill('تهران');
      await page.locator('input[name="orderQuantity"]').fill('۲۰');
      await page.locator('input[name="budget"]').fill('۵۰۰۰۰۰');
      await page.locator('#request select').last().selectOption('TEAM');
      await page.getByText('بودجهٔ تقریبی کل: ۱۰٬۰۰۰٬۰۰۰ تومان', { exact: true }).waitFor();
      await page.locator('#request details summary').click();
      const logoInput = page.getByLabel('انتخاب تصویر لوگو', { exact: true });
      await page.getByText('تصویری انتخاب نشده است', { exact: true }).waitFor();
      await logoInput.setInputFiles({ name: 'نشان-سازمان.png', mimeType: 'image/png', buffer: Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j2ioAAAAASUVORK5CYII=', 'base64') });
      await page.getByText('نشان-سازمان.png', { exact: true }).waitFor();
      await page.getByRole('button', { name: 'حذف فایل انتخاب‌شده', exact: true }).click();
      assert.equal(await logoInput.evaluate(input => input.files.length), 0);
      await page.locator('#request textarea').fill('بسته‌بندی با کارت قدردانی');
      if (width === 390 || width === 1440) await page.locator('#request').screenshot({ path: `.test-results/corporate-request-${width}.png` });
      const submit = page.getByRole('button', { name: 'درخواست پیشنهاد و هماهنگی', exact: true });
      await submit.click();
      try { await page.locator('#request').getByRole('alert').waitFor({ timeout: 10000 }); }
      catch (error) { await page.screenshot({ path: `.test-results/corporate-submit-error-${width}.png`, fullPage: true }); throw new Error(`Submit at ${width}: ${await page.locator('#request').innerText()}; payload=${JSON.stringify(submitted)}; ${error}`); }
      assert.equal(await page.locator('input[name="companyName"]').inputValue(), 'سازمان آزمایشی');
      fail = false;
      await submit.click();
      await page.getByRole('heading', { name: 'قدم اول را با هم برداشتیم!', exact: true }).waitFor();
      assert.equal(submitted.budget, 100000000);
      assert.equal(submitted.orderQuantity, 20);
      assert.equal(submitted.packageCode, 'TEAM');
      assert.equal(submitted.mobile, '09121111111');
      assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1), true);
      assert.deepEqual(errors, []);
      await page.getByRole('button', { name: 'بازگشت', exact: true }).click();
      await page.waitForURL(origin + '/shop');
      if (width === 390) {
        await page.locator('footer a[href="/corporate-sales"]').click();
        await page.waitForURL(origin + '/corporate-sales');
        await page.getByRole('button', { name: 'بازگشت', exact: true }).click();
        await page.waitForURL(origin + '/shop');
      }
      await context.close();
    }
    console.log('Corporate browser: shared chrome, Persian fonts/word spacing, contained images, mobile navigation, back fallback and request retry/toman conversion passed at 320/360/390/768/1024/1440.');
  } finally {
    if (browser) await browser.close();
    server.kill('SIGTERM');
    await new Promise(resolve => { server.once('exit', resolve); setTimeout(resolve, 5000).unref(); });
  }
})().catch(error => { console.error(error); console.error(log); process.exitCode = 1; });
