// Shared by Next's build and the deployment preflight. Never print env values.
export function publicOriginError(value) {
  try {
    const url = new URL(value);
    if (url.protocol !== 'https:' || url.username || url.password || url.search || url.hash
      || url.pathname !== '/' || url.hostname === 'localhost' || !url.hostname.includes('.')
      || /(^|\.)(example\.(com|org|net)|test|local|invalid)$/.test(url.hostname)
      || /^[\d.]+$/.test(url.hostname) || url.hostname.startsWith('[')) return true;
    return false;
  } catch { return true; }
}

export function storefrontReleaseErrors(env, requireRelease = false) {
  const errors = [];
  const api = env.NEXT_PUBLIC_MAZEDUNEH_API_URL?.trim() || env.NEXT_PUBLIC_MAZEDUNEH_API_BASE_URL?.trim();
  const demo = env.NEXT_PUBLIC_MAZEDUNEH_DEMO_MODE === 'true';
  if (env.MAZEDUNEH_STATIC_EXPORT === 'true' && api && !demo) {
    errors.push('Live products need the Next.js server; remove MAZEDUNEH_STATIC_EXPORT=true.');
  }
  if (!requireRelease && env.MAZEDUNEH_RELEASE_BUILD !== 'true') return errors;
  if (env.NEXT_PUBLIC_MAZEDUNEH_DEMO_MODE !== 'false') errors.push('Set NEXT_PUBLIC_MAZEDUNEH_DEMO_MODE=false for release.');
  for (const [name, value] of [
    ['NEXT_PUBLIC_MAZEDUNEH_API_URL', api],
    ['NEXT_PUBLIC_SITE_URL', env.NEXT_PUBLIC_SITE_URL],
    ['NEXT_PUBLIC_MAZEDUNEH_ADMIN_URL', env.NEXT_PUBLIC_MAZEDUNEH_ADMIN_URL],
  ]) {
    if (publicOriginError(value)) errors.push(`${name} must be a public HTTPS origin without a path, query or credentials.`);
  }
  if (env.NEXT_PUBLIC_MAZEDUNEH_API_URL && env.NEXT_PUBLIC_MAZEDUNEH_API_BASE_URL
    && env.NEXT_PUBLIC_MAZEDUNEH_API_URL.trim().replace(/\/$/, '') !== env.NEXT_PUBLIC_MAZEDUNEH_API_BASE_URL.trim().replace(/\/$/, '')) {
    errors.push('The two public API URL settings must match.');
  }
  if (env.MAZEDUNEH_STATIC_EXPORT === 'true' && !api) errors.push('Static preview output cannot be used as the live release.');
  return errors;
}
