// Run from apps/storefront after installing its locked dependencies.
const sharp = require('sharp');
const { mkdir, readFile, writeFile } = require('node:fs/promises');
const { createHash } = require('node:crypto');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
(async () => {
  const directory = path.join(root, 'public/products/responsive');
  await mkdir(directory, { recursive: true });
  const manifest = {};
  for (const name of ['dragon-box-new', 'almond-pouch-new', 'pistachio-pouch-new']) {
    const original = await readFile(path.join(root, `public/products/${name}.webp`));
    const metadata = await sharp(original).metadata();
    const variants = [];
    for (const width of [320, 512]) {
      const buffer = await sharp(original).resize({ width, withoutEnlargement: true }).webp({ quality: 80 }).toBuffer();
      const hash = createHash('sha256').update(buffer).digest('hex').slice(0, 12);
      const file = `${name}.${width}.${hash}.webp`;
      await writeFile(path.join(directory, file), buffer);
      variants.push({ src: `/products/responsive/${file}`, width });
      console.log(`${name}: ${original.length} -> ${buffer.length} bytes at ${width}px`);
    }
    manifest[`/products/${name}.webp`] = {
      src: variants[0].src,
      srcSet: variants.map(v => `${v.src} ${v.width}w`).join(', '),
      width: metadata.width,
      height: metadata.height,
    };
  }
  await writeFile(path.join(root, 'app/demo/hero-artwork.json'), JSON.stringify(manifest, null, 2) + '\n');
})().catch(error => { console.error(error); process.exitCode = 1; });
