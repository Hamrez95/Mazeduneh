import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { publicOriginError, storefrontReleaseErrors } from '../apps/storefront/release-config.mjs';

// Read-only: validate the host environment without logging secrets or contacting services.
export function releasePreflightErrors(env, payments = false) {
  const errors = storefrontReleaseErrors(env, true);
  const configured = name => {
    const value = env[name]?.trim();
    return value && !/[<>]/.test(value) && !/^(change[-_]?me|replace[-_]?me)$/i.test(value);
  };
  const requireSetting = name => { if (!configured(name)) errors.push(`Configure ${name} in the host secret manager.`); };
  if (env.ASPNETCORE_ENVIRONMENT !== 'Production') errors.push('Set ASPNETCORE_ENVIRONMENT=Production.');
  for (const name of ['ConnectionStrings__Catalog', 'Admin__Email', 'Admin__PasswordHash', 'Admin__TokenSigningKey']) requireSetting(name);
  if (!/^[a-f0-9]{64}$/i.test(env.Admin__PasswordHash ?? '')) errors.push('Admin__PasswordHash must contain a SHA-256 password hash.');
  if ((env.Admin__TokenSigningKey?.length ?? 0) < 32) errors.push('Admin__TokenSigningKey needs at least 32 characters from a secure random source.');
  if (env.Admin__Mfa__SensitiveActionsRequired !== 'true') errors.push('Set Admin__Mfa__SensitiveActionsRequired=true.');
  if (!/^[A-Z2-7]{26,}={0,6}$/i.test(env.Admin__Mfa__TotpSecret ?? '')) errors.push('Configure a Base32 Admin__Mfa__TotpSecret with at least 16 random bytes.');
  const origins = Object.entries(env).filter(([name]) => /^Cors__AllowedOrigins__\d+$/.test(name)).map(([, value]) => value?.replace(/\/$/, ''));
  for (const name of ['NEXT_PUBLIC_SITE_URL', 'NEXT_PUBLIC_MAZEDUNEH_ADMIN_URL']) {
    if (!origins.includes(env[name]?.replace(/\/$/, ''))) errors.push(`Cors__AllowedOrigins must include ${name}.`);
  }
  if (origins.some(publicOriginError)) errors.push('CORS must contain only explicit public HTTPS origins.');
  if (publicOriginError(env.Media__PublicBaseUrl)) errors.push('Configure Media__PublicBaseUrl as the public HTTPS API origin.');
  const provider = env.Media__Provider?.toLowerCase();
  if (provider === 's3' || provider === 's3-compatible') {
    for (const name of ['Media__S3__Endpoint', 'Media__S3__Bucket', 'Media__S3__Region', 'Media__S3__AccessKey', 'Media__S3__SecretKey']) requireSetting(name);
    if (publicOriginError(env.Media__S3__Endpoint)) errors.push('Media__S3__Endpoint must use a public HTTPS origin.');
  } else if (provider === 'local') {
    if (!/^(\/|[A-Za-z]:[\\/])/.test(env.Media__RootPath ?? '') || !configured('Media__RootPath')) errors.push('Set Media__RootPath to an absolute persistent volume path included in backups.');
  } else errors.push('Explicitly configure Media__Provider as Local or S3.');
  if (env.Payments__SandboxEnabled !== 'false') errors.push('Set Payments__SandboxEnabled=false for production.');
  if (payments) {
    requireSetting('Payments__Zibal__Merchant');
    if (env.Payments__Zibal__Merchant?.trim().toLowerCase() === 'zibal') errors.push('Replace the test merchant with the real Zibal merchant.');
    for (const name of ['Payments__Zibal__CallbackUrl', 'Payments__Zibal__ReturnUrl']) {
      try {
        const url = new URL(env[name]);
        if (publicOriginError(url.origin) || url.username || url.password || url.search || url.hash) throw new Error();
        const expectedOrigin = name.endsWith('CallbackUrl') ? (env.NEXT_PUBLIC_MAZEDUNEH_API_URL || env.NEXT_PUBLIC_MAZEDUNEH_API_BASE_URL) : env.NEXT_PUBLIC_SITE_URL;
        const expectedPath = name.endsWith('CallbackUrl') ? '/api/v1/payments/zibal/callback' : '/checkout';
        if (url.origin !== new URL(expectedOrigin).origin || url.pathname !== expectedPath) throw new Error();
      } catch { errors.push(`${name} must match the release API callback or storefront checkout URL.`); }
    }
  }
  return [...new Set(errors)];
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const errors = releasePreflightErrors(process.env, process.argv.includes('--payments'));
  if (errors.length) {
    console.error('Release configuration is incomplete:\n' + errors.map(error => `- ${error}`).join('\n'));
    process.exitCode = 1;
  } else console.log('Release configuration passed. Server health, storage, restore, alerts and real payment acceptance still require staging evidence.');
}
