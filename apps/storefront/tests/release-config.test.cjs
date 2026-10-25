const { test } = require('node:test');
const assert = require('node:assert/strict');
const modules = Promise.all([import('../release-config.mjs'), import('../../../scripts/release-preflight.mjs')]);
const valid = () => ({
  MAZEDUNEH_RELEASE_BUILD: 'true', NEXT_PUBLIC_MAZEDUNEH_DEMO_MODE: 'false',
  NEXT_PUBLIC_MAZEDUNEH_API_URL: 'https://api.mazeduneh.ir', NEXT_PUBLIC_SITE_URL: 'https://mazeduneh.ir',
  NEXT_PUBLIC_MAZEDUNEH_ADMIN_URL: 'https://admin.mazeduneh.ir', ASPNETCORE_ENVIRONMENT: 'Production',
  ConnectionStrings__Catalog: 'Host=db;Database=store;Username=owner;Password=private-test',
  Admin__Email: 'owner@mazeduneh.ir', Admin__PasswordHash: 'a'.repeat(64), Admin__TokenSigningKey: 'b'.repeat(64),
  Admin__Mfa__SensitiveActionsRequired: 'true', Admin__Mfa__TotpSecret: 'A'.repeat(32),
  Cors__AllowedOrigins__0: 'https://mazeduneh.ir', Cors__AllowedOrigins__1: 'https://admin.mazeduneh.ir',
  Media__Provider: 'Local', Media__PublicBaseUrl: 'https://api.mazeduneh.ir', Media__RootPath: '/data/media',
  Payments__SandboxEnabled: 'false', Payments__Zibal__Merchant: 'real-merchant-fixture',
  Payments__Zibal__CallbackUrl: 'https://api.mazeduneh.ir/api/v1/payments/zibal/callback',
  Payments__Zibal__ReturnUrl: 'https://mazeduneh.ir/checkout',
});
test('preview remains buildable, live static export is rejected, and release requires real origins', async () => {
  const [{ storefrontReleaseErrors, publicOriginError }] = await modules;
  assert.deepEqual(storefrontReleaseErrors({ MAZEDUNEH_STATIC_EXPORT: 'true', NEXT_PUBLIC_MAZEDUNEH_DEMO_MODE: 'true' }), []);
  assert.deepEqual(storefrontReleaseErrors({ MAZEDUNEH_STATIC_EXPORT: 'true', NEXT_PUBLIC_MAZEDUNEH_DEMO_MODE: 'true', NEXT_PUBLIC_MAZEDUNEH_API_URL: valid().NEXT_PUBLIC_MAZEDUNEH_API_URL }), []);
  assert.ok(storefrontReleaseErrors({ MAZEDUNEH_STATIC_EXPORT: 'true', NEXT_PUBLIC_MAZEDUNEH_API_URL: valid().NEXT_PUBLIC_MAZEDUNEH_API_URL }).length);
  assert.deepEqual(storefrontReleaseErrors(valid()), []);
  for (const value of ['http://api.mazeduneh.ir', 'https://user:secret@api.mazeduneh.ir', 'https://api.example.com', 'https://localhost', 'https://127.0.0.1', 'https://api.mazeduneh.ir/path', 'https://api.mazeduneh.ir?secret=x']) assert.equal(publicOriginError(value), true);
  for (const change of [{ NEXT_PUBLIC_MAZEDUNEH_DEMO_MODE: 'true' }, { NEXT_PUBLIC_MAZEDUNEH_API_URL: '' }, { NEXT_PUBLIC_MAZEDUNEH_API_BASE_URL: 'https://other.mazeduneh.ir' }]) assert.ok(storefrontReleaseErrors({ ...valid(), ...change }).length);
});
test('preflight rejects missing production security, storage and CORS without exposing values', async () => {
  const [, { releasePreflightErrors }] = await modules;
  assert.deepEqual(releasePreflightErrors(valid(), true), []);
  for (const change of [{ Admin__Mfa__SensitiveActionsRequired: 'false' }, { Admin__TokenSigningKey: 'private-short-secret' }, { Payments__SandboxEnabled: 'true' }, { Media__RootPath: 'relative' }, { Cors__AllowedOrigins__1: '*' }, { ConnectionStrings__Catalog: '<connection-string>' }]) {
    const errors = releasePreflightErrors({ ...valid(), ...change });
    assert.ok(errors.length, JSON.stringify(Object.keys(change)));
    assert.ok(!errors.join(' ').includes('private-short-secret'));
    assert.ok(!errors.join(' ').includes('Password=private-test'));
  }
  const s3 = { ...valid(), Media__Provider: 'S3', Media__S3__Endpoint: 'https://storage.mazeduneh.ir', Media__S3__Bucket: 'media', Media__S3__Region: 'region', Media__S3__AccessKey: 'private-key', Media__S3__SecretKey: 'private-secret' };
  assert.deepEqual(releasePreflightErrors(s3), []);
  assert.ok(releasePreflightErrors({ ...s3, Media__S3__SecretKey: '' }).length);
});
test('payment acceptance requires real merchant and exact release callback/return routes', async () => {
  const [, { releasePreflightErrors }] = await modules;
  assert.deepEqual(releasePreflightErrors({ ...valid(), Payments__Zibal__Merchant: '' }), []);
  assert.ok(releasePreflightErrors({ ...valid(), Payments__Zibal__Merchant: '' }, true).length);
  for (const change of [{ Payments__Zibal__Merchant: 'zibal' }, { Payments__Zibal__CallbackUrl: 'https://other.mazeduneh.ir/api/v1/payments/zibal/callback' }, { Payments__Zibal__ReturnUrl: 'https://mazeduneh.ir/wrong' }]) assert.ok(releasePreflightErrors({ ...valid(), ...change }, true).length);
});
