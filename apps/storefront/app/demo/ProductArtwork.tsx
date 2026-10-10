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

export function getProductArtworkGallery(product: DemoProduct) {
  const primary = imageFor(product);
  const managedGallery = product.galleryImages ?? [];
  const fallbackGallery = galleryByArt[product.art] ?? [];
  return Array.from(new Set([primary, ...managedGallery, ...(managedGallery.length ? [] : fallbackGallery)]));
}

export function ProductArtwork({
  product,
  hero = false,
  src,
}: {
  product: DemoProduct;
  hero?: boolean;
  src?: string;
}) {
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
