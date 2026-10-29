// Uses an isolated synthetic metadata API; no store database or user browser profile.
const assert = require('node:assert/strict');
const http = require('node:http');
const { spawn } = require('node:child_process');
const origin = 'http://127.0.0.1:3096';
const api = 'http://127.0.0.1:5996';
const next = 'node_modules/next/dist/bin/next';
const env = { ...process.env, MAZEDUNEH_STATIC_EXPORT: 'false', MAZEDUNEH_DOCKER_STANDALONE: 'false',
  MAZEDUNEH_RELEASE_BUILD: 'true', NEXT_PUBLIC_MAZEDUNEH_DEMO_MODE: 'false', NEXT_TELEMETRY_DISABLED: '1',
  NEXT_PUBLIC_MAZEDUNEH_API_URL: 'https://api.mazeduneh.ir', NEXT_PUBLIC_MAZEDUNEH_API_BASE_URL: 'https://api.mazeduneh.ir',
  NEXT_PUBLIC_SITE_URL: 'https://mazeduneh.ir', NEXT_PUBLIC_MAZEDUNEH_ADMIN_URL: 'https://admin.mazeduneh.ir',
  MAZEDUNEH_API_INTERNAL_URL: api };
const fixture = http.createServer((request, response) => {
  if (request.url === '/api/v1/products/slow-metadata') return;
  response.writeHead(200, { 'content-type': 'application/json' });
  const product = { id: 'production-fixture', slug: 'fresh-after-build', title: 'Fresh production product',
    seoTitle: 'Production route fixture', category: 'Fixture', origin: '', currency: 'IRR',
    isPublished: true, unitType: 'Weight', variants: [{ sku: 'FIXTURE-250', quantity: 250,
      baseUnit: 'g', displayLabel: '۲۵۰ گرم', price: 2000000, availablePackages: 2 }],
    seoDescription: 'A product slug that did not exist in preview at build time.' };
  response.end(JSON.stringify(request.url === '/api/v1/products' ? [product] : product));
});
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
let server;
let log = '';
function launch(args, pipe = false) {
  const process = spawn(global.process.execPath, [next, ...args], { env, stdio: pipe ? ['ignore', 'pipe', 'pipe'] : 'inherit' });
  if (pipe) for (const stream of [process.stdout, process.stderr]) stream.on('data', data => { log = (log + data).slice(-5000); });
  return process;
}
async function main() {
  try {
    await new Promise((resolve, reject) => { fixture.once('error', reject); fixture.listen(5996, '127.0.0.1', resolve); });
    if (!process.argv.includes('--skip-build')) await new Promise((resolve, reject) => {
      const build = launch(['build']);
      build.once('error', reject);
      build.once('exit', code => code === 0 ? resolve() : reject(new Error(`Production build exited ${code}`)));
    });
    server = launch(['start', '--hostname', '127.0.0.1', '--port', '3096'], true);
    let ready = false;
    for (let i = 0; i < 60; i++) {
      if (server.exitCode !== null) throw new Error('Production server exited: ' + log);
      try { if ((await fetch(origin, { signal: AbortSignal.timeout(2000) })).ok) { ready = true; break; } } catch {}
      await delay(500);
    }
    assert.ok(ready, 'Production server readiness: ' + log);
    const fresh = await fetch(origin + '/product/fresh-after-build', { signal: AbortSignal.timeout(10000) });
    assert.equal(fresh.status, 200, 'A new live slug must be served by the production Next server');
    assert.match(await fresh.text(), /Production route fixture/);
    const started = Date.now();
    const slow = await fetch(origin + '/product/slow-metadata', { signal: AbortSignal.timeout(10000) });
    assert.equal(slow.status, 200);
    const body = await slow.text();
    const elapsed = Date.now() - started;
    assert.ok(elapsed < 8000, `Hung metadata API blocked the page for ${elapsed}ms`);
    assert.match(body, /اطلاعات محصول مزه‌دونه/);
    console.log(`Production storefront: new product deep link and bounded metadata failure passed (${elapsed}ms)`);
  } finally {
    if (server && server.exitCode === null) {
      server.kill('SIGTERM');
      await new Promise(resolve => { server.once('exit', resolve); setTimeout(resolve, 5000).unref(); });
    }
    fixture.closeAllConnections();
    await new Promise(resolve => fixture.close(resolve));
  }
}
main().catch(error => { console.error(error); console.error(log); process.exitCode = 1; });
