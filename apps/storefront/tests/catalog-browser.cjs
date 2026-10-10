const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const { chromium } = require('playwright');
const { mkdir } = require('node:fs/promises');
const origin = 'http://127.0.0.1:3098';
const api = 'http://127.0.0.1:5998';
const product = (slug, title, stock = 3) => ({ id: slug, slug, title, category: 'دسته پنل', origin: 'ایران',
  currency: 'IRR', unitType: 'Weight', isPublished: true, description: 'توضیح ثبت‌شده در پنل',
  variants: [{ sku: slug.toUpperCase(), quantity: 250, displayLabel: '۲۵۰ گرم', price: 321000, availablePackages: stock }] });
const server = spawn(process.execPath, ['node_modules/next/dist/bin/next', 'dev', '--hostname', '127.0.0.1', '--port', '3098'], {
  env: { ...process.env, NEXT_PUBLIC_MAZEDUNEH_API_URL: api, NEXT_PUBLIC_MAZEDUNEH_API_BASE_URL: api,
    MAZEDUNEH_STATIC_EXPORT: 'false', NEXT_TELEMETRY_DISABLED: '1' }, stdio: ['ignore', 'pipe', 'pipe'],
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
    browser = await chromium.launch();
    await mkdir('.test-results', { recursive: true });
    for (const width of [360, 768, 1280]) {
      const context = await browser.newContext({ viewport: { width, height: 1000 }, reducedMotion: 'reduce' });
      const page = await context.newPage();
      const errors = [];
      page.on('pageerror', (error) => errors.push(error.message));
      let records = [product('live-nut', 'پسته پنل'), product('live-almond', 'بادام پنل', 0)];
      let failing = false;
      await context.route(api + '/**', async (route) => {
        const path = new URL(route.request().url()).pathname;
        const body = path.endsWith('/categories') ? (records.length ? [{ name: 'دسته پنل', isActive: true }] : [])
          : path.endsWith('/products') ? records : records.find((item) => path.endsWith('/' + item.slug));
        await route.fulfill({ status: failing ? 503 : body ? 200 : 404,
          headers: { 'access-control-allow-origin': '*', 'content-type': 'application/json' },
          body: JSON.stringify(failing ? { message: 'offline' } : body ?? {}) });
      });
      await page.goto(origin);
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

      await page.goto(origin + '/shop');
      await page.getByRole('heading', { name: records[0].title, exact: true }).waitFor();
      await page.goto(origin + '/product/live-nut');
      await page.getByRole('heading', { name: records[0].title, exact: true }).waitFor();
      await page.getByRole('heading', { name: 'بادام پنل', exact: true }).waitFor();
      assert.equal(await page.getByText('پسته اکبری ممتاز', { exact: true }).count(), 0);

      records = [];
      await page.goto(origin);
      await page.getByText('محصولی در این دسته پیدا نشد.', { exact: true }).waitFor();
      assert.equal(await page.getByRole('article').count(), 0);
      failing = true;
      await page.reload();
      await page.getByText(/محصولات دریافت نشد/).waitFor();
      assert.equal(await page.getByRole('article').count(), 0);
      assert.deepEqual(errors, []);
      await context.close();
    }
    console.log('Catalog browser: home/shop/detail/related, admin edits, sold-out, empty/error/stale, keyboard and responsive 360/768/1280 passed');
  } finally {
    if (browser) await browser.close();
    server.kill('SIGTERM');
  }
})().catch((error) => { console.error(error); process.exitCode = 1; });
