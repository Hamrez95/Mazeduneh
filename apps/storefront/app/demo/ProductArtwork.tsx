import type { DemoProduct, ProductArt } from "./catalog";
import styles from "./professional-storefront.module.css";

const imageByArt: Record<ProductArt, string> = {
  pistachio: "/products/pistachio-pouch-new.webp",
  almond: "/products/almond-pouch-new.webp",
  walnut: "/products/walnut-character-new.webp",
  fruit: "/products/dried-fruit.webp",
  seed: "/products/pumpkin-seeds.webp",
  cookie: "/products/oat-cookie.webp",
  gift: "/products/gift-box.webp",
};

const galleryByArt: Partial<Record<ProductArt, string[]>> = {
  pistachio: ["/products/pistachio-pouch-new.webp", "/products/pistachio-scene-new.webp", "/products/pistachio-pouch.webp"],
  almond: ["/products/almond-pouch-new.webp", "/products/almond-pouch.webp"],
  walnut: ["/products/walnut-character-new.webp", "/products/walnut-character.webp"],
  fruit: ["/products/dried-fruit.webp", "/products/fruit-leather.webp"],
  cookie: ["/products/oat-cookie.webp", "/products/protein-cookie.webp", "/products/dragon-box-new.webp"],
  gift: ["/products/gift-box.webp", "/products/mixed-nuts-character.webp", "/products/one-kilo-box-packaging.webp"],
};

function imageFor(product: DemoProduct) {
  return product.primaryImage || imageByArt[product.art];
}

export function getProductArtworkGallery(
  product: DemoProduct,
  { live = false }: { live?: boolean } = {},
) {
  const primary = live ? product.primaryImage?.trim() ?? "" : imageFor(product);
  const managedGallery = product.galleryImages ?? [];
  // Demo artwork is illustrative. A live catalog product must never inherit
  // sample photos just because it has no uploaded media of its own.
  const fallbackGallery = live || managedGallery.length || product.primaryImage?.trim()
    ? []
    : galleryByArt[product.art] ?? [];
  return Array.from(new Set([primary, ...managedGallery, ...fallbackGallery].filter(Boolean)));
}

export function ProductArtwork({
  product,
  hero = false,
  src,
  live = false,
}: {
  product: DemoProduct;
  hero?: boolean;
  src?: string;
  live?: boolean;
}) {
  if (live && !src && !product.primaryImage?.trim()) {
    return <div className={styles.missingProductImage} role="img" aria-label={`تصویر ${product.title} ثبت نشده`}>
      <span>تصویری ثبت نشده</span>
    </div>;
  }
  return (
    <img
      className={hero ? styles.heroProductImage : styles.productImage}
      src={src ?? imageFor(product)}
      alt={`تصویرسازی ${product.title}`}
      loading={hero ? "eager" : "lazy"}
      decoding="async"
    />
  );
}
