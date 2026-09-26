import type { DemoProduct, ProductArt } from "./catalog";
import styles from "./professional-storefront.module.css";

const imageByProductId: Record<string, string> = {
  "pistachio-akbari": "/products/pistachio-pouch-new.webp",
  "pistachio-ahmad": "/products/pistachio-pouch-new.webp",
  almond: "/products/almond-pouch-new.webp",
  walnut: "/products/walnut-character-new.webp",
  "dried-fruit": "/products/gift-boxes-new.webp",
  "pumpkin-seeds": "/products/pumpkin-seeds.webp",
  "protein-cookie": "/products/dragon-box-new.webp",
  "fruit-leather": "/products/gift-boxes-new.webp",
  "oat-cookie": "/products/cookie-boxes-new.webp",
  "gift-box": "/products/gift-boxes-new.webp",
};

const imageByArt: Record<ProductArt, string> = {
  pistachio: "/products/pistachio-pouch-new.webp",
  almond: "/products/almond-pouch-new.webp",
  walnut: "/products/walnut-character-new.webp",
  fruit: "/products/gift-boxes-new.webp",
  seed: "/products/pumpkin-seeds.webp",
  cookie: "/products/dragon-box-new.webp",
  gift: "/products/gift-boxes-new.webp",
};

const galleryByProductId: Record<string, string[]> = {
  "pistachio-akbari": [
    "/products/pistachio-pouch-new.webp",
    "/products/pistachio-scene-new.webp",
    "/products/pistachio-pouch.webp",
    "/products/pistachio-akbari.webp",
  ],
  "pistachio-ahmad": [
    "/products/pistachio-pouch-new.webp",
    "/products/pistachio-scene-new.webp",
    "/products/pistachio-pouch.webp",
    "/products/pistachio-ahmad.webp",
  ],
  almond: [
    "/products/almond-pouch-new.webp",
    "/products/almond-pouch.webp",
    "/products/almond.webp",
  ],
  walnut: [
    "/products/walnut-character-new.webp",
    "/products/walnut-character.webp",
    "/products/walnut.webp",
  ],
  "dried-fruit": [
    "/products/gift-boxes-new.webp",
    "/products/gift-wrap-packaging.webp",
    "/products/dried-fruit.webp",
  ],
  "protein-cookie": [
    "/products/dragon-box-new.webp",
    "/products/cookie-boxes-new.webp",
    "/products/cocoa-cookie-dragon.webp",
    "/products/protein-cookie.webp",
  ],
  "fruit-leather": [
    "/products/gift-boxes-new.webp",
    "/products/gift-wrap-packaging.webp",
    "/products/fruit-leather.webp",
  ],
  "oat-cookie": [
    "/products/cookie-boxes-new.webp",
    "/products/cookie-mouth-packaging.webp",
    "/products/oat-cookie.webp",
  ],
  "gift-box": [
    "/products/gift-boxes-new.webp",
    "/products/one-kilo-box-packaging.webp",
    "/products/gift-wrap-packaging.webp",
    "/products/gift-box.webp",
  ],
};

const galleryByArt: Partial<Record<ProductArt, string[]>> = {
  pistachio: ["/products/pistachio-pouch-new.webp", "/products/pistachio-scene-new.webp", "/products/pistachio-pouch.webp"],
  almond: ["/products/almond-pouch-new.webp", "/products/almond-pouch.webp"],
  walnut: ["/products/walnut-character-new.webp", "/products/walnut-character.webp"],
  fruit: ["/products/gift-boxes-new.webp", "/products/gift-wrap-packaging.webp"],
  cookie: ["/products/dragon-box-new.webp", "/products/cookie-boxes-new.webp"],
  gift: ["/products/gift-boxes-new.webp", "/products/one-kilo-box-packaging.webp"],
};

function imageFor(product: DemoProduct) {
  return imageByProductId[product.id] ?? imageByArt[product.art];
}

export function getProductArtworkGallery(product: DemoProduct) {
  const primary = imageFor(product);
  return Array.from(new Set([primary, ...(galleryByProductId[product.id] ?? galleryByArt[product.art] ?? [])]));
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
