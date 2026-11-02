import { cp, readFile } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { parseEnv } from 'node:util';
import { storefrontReleaseErrors } from '../apps/storefront/release-config.mjs';

const root = new URL('../', import.meta.url);
const app = new URL('apps/storefront/', root);
const profile = parseEnv(await readFile(new URL('infra/storefront-release.env', root), 'utf8'));
const errors = storefrontReleaseErrors(profile, true);
if (errors.length) throw new Error(errors.join('\n'));
// Release inputs override inherited local demo/static settings deliberately.
const build = spawnSync(process.execPath, ['node_modules/next/dist/bin/next', 'build'], {
  cwd: fileURLToPath(app), env: { ...process.env, ...profile }, stdio: 'inherit',
});
if (build.status !== 0) throw new Error('Production storefront build failed. Preview was not changed.');
await cp(new URL('public/', app), new URL('.next/standalone/public/', app), { recursive: true });
await cp(new URL('.next/static/', app), new URL('.next/standalone/.next/static/', app), { recursive: true });
console.log('Live-mode Next.js server prepared in apps/storefront/.next/standalone. API/DNS/payment acceptance remains pending.');
