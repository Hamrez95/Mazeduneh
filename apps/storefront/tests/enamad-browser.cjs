const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const { mkdir } = require('node:fs/promises');
const { chromium } = require('playwright');
const origin = 'http://127.0.0.1:3094';
const profile = 'https://trustseal.enamad.ir/?id=8329471&Code=xq46ZqyHRQtv0ZGlrkmnEj6fFhmX7Zxc';
const server = spawn(process.execPath, ['node_modules/next/dist/bin/next', 'dev', ...(process.platform === 'win32' ? ['--webpack'] : []), '--hostname', '127.0.0.1', '--port', '3094'], {
  env: { ...process.env, NEXT_PUBLIC_MAZEDUNEH_API_URL: '', NEXT_PUBLIC_MAZEDUNEH_API_BASE_URL: '', MAZEDUNEH_RELEASE_BUILD: 'false', MAZEDUNEH_STATIC_EXPORT: 'false', NEXT_PUBLIC_MAZEDUNEH_DEMO_MODE: 'true', NEXT_TELEMETRY_DISABLED: '1' },
  stdio: ['ignore', 'pipe', 'pipe'],
});
let log = '';
for (const stream of [server.stdout, server.stderr]) stream.on('data', data => { log = (log + data).slice(-5000); });
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
async function ready() {
  for (let i = 0; i < 120; i++) {
    if (server.exitCode !== null) throw new Error('Next server exited: ' + log);
    try { if ((await fetch(origin + '/contact', { signal: AbortSignal.timeout(2000) })).ok) return; } catch {}
    await delay(500);
  }
  throw new Error('Next did not become ready: ' + log);
}
const fixture = '<svg xmlns="http://www.w3.org/2000/svg" width="125" height="136"><rect width="125" height="136" fill="#16543e"/><text x="20" y="70" fill="white">FIXTURE</text></svg>';
(async () => {
  let browser;
  try {
    await ready();
    browser = await chromium.launch(process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH ? { executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH } : {});
    await mkdir('.test-results', { recursive: true });
    for (const width of [360, 1280]) {
      const context = await browser.newContext({ viewport: { width, height: 900 }, reducedMotion: 'reduce' });
      const page = await context.newPage();
      const errors = [];
      page.on('pageerror', error => errors.push(error.message));
      let mode = 'failure';
      let requests = 0;
      let referer;
      await context.route(url => url.origin === 'https://trustseal.enamad.ir' && url.pathname === '/logo.aspx', async route => {
        requests++;
        const parameters = new URL(route.request().url()).searchParams;
        assert.equal(parameters.get('id'), '8329471');
        assert.equal(parameters.get('Code'), 'xq46ZqyHRQtv0ZGlrkmnEj6fFhmX7Zxc');
        referer = route.request().headers().referer;
        if (mode === 'failure') return route.fulfill({ status: 503, body: 'unavailable' });
        if (mode === 'pending') return; // Exercise a hung external image without contacting eNamad.
        return route.fulfill({ status: 200, contentType: 'image/svg+xml', body: mode === 'tiny' ? '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"/>' : fixture });
      });
      await page.goto(origin + '/contact', { waitUntil: 'domcontentloaded' });
      const seal = page.getByRole('region', { name: 'نماد اعتماد الکترونیکی', exact: true });
      await seal.scrollIntoViewIfNeeded();
      await page.getByText('تصویر نماد فعلاً در دسترس نیست', { exact: true }).waitFor();
      const link = seal.getByRole('link');
      assert.equal(await link.getAttribute('href'), profile);
      assert.equal(await link.getAttribute('rel'), 'noopener');
      assert.equal(await link.getAttribute('referrerpolicy'), 'origin');
      assert.equal(await seal.locator('img').getAttribute('referrerpolicy'), 'origin');
      const foreground = await seal.locator('a > span').first().evaluate(node => getComputedStyle(node).backgroundColor);
      assert.equal(foreground, 'rgb(255, 255, 255)');
      assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1), true);
      await seal.screenshot({ path: `.test-results/enamad-unavailable-${width}.png` });
      mode = 'ready';
      const before = requests;
      await seal.getByRole('button', { name: 'تلاش دوباره برای تصویر', exact: true }).click();
      await page.waitForFunction(() => document.querySelector('section[aria-label="نماد اعتماد الکترونیکی"]')?.dataset.state === 'ready');
      assert.ok(requests > before, 'Retry must make a fresh official-image request');
      assert.equal(referer, origin + '/');
      assert.equal(await seal.locator('img').evaluate(image => getComputedStyle(image).opacity), '1');
      assert.equal(await seal.getByRole('button').count(), 0);
      await seal.screenshot({ path: `.test-results/enamad-loaded-fixture-${width}.png` });
      mode = 'tiny';
      await page.reload({ waitUntil: 'domcontentloaded' });
      await seal.scrollIntoViewIfNeeded();
      await page.getByText('تصویر نماد فعلاً در دسترس نیست', { exact: true }).waitFor();
      assert.equal(await seal.locator('img').evaluate(image => image.naturalWidth), 1);
      if (width === 360) {
        mode = 'pending';
        await seal.getByRole('button', { name: 'تلاش دوباره برای تصویر', exact: true }).click();
        await page.getByText('در حال دریافت تصویر نماد…', { exact: true }).waitFor();
        await page.getByText('تصویر نماد فعلاً در دسترس نیست', { exact: true }).waitFor({ timeout: 20000 });
      }
      assert.deepEqual(errors, []);
      await context.close();
    }
    console.log('eNamad browser: official URLs/referrer, visible white image surface, failure/timeout/tiny-image fallback and retry recovery passed at 360/1280. Image fixtures do not certify external eNamad availability.');
  } finally {
    if (browser) await browser.close();
    server.kill('SIGTERM');
    await new Promise(resolve => { server.once('exit', resolve); setTimeout(resolve, 5000).unref(); });
  }
})().catch(error => { console.error(error); console.error(log); process.exitCode = 1; });
