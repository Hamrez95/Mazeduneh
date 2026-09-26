import type { DemoProduct, ProductArt } from "./catalog";
import styles from "./professional-storefront.module.css";

const imageByProductId: Record<string, string> = {
  "pistachio-akbari": "/products/pistachio-pouch-new.webp",
  "pistachio-ahmad": "/products/pistachio-pouch-new.webp",
  almond: "/products/almond-pouch-new.webp",
  walnut: "/products/walnut-character-new.webp",
  "dried-fruit": "/products/dried-fruit.webp",
  "pumpkin-seeds": "/products/pumpkin-seeds.webp",
  "protein-cookie": "/products/protein-cookie.webp",
  "fruit-leather": "/products/fruit-leather.webp",
  "oat-cookie": "/products/oat-cookie.webp",
  "gift-box": "/products/gift-box.webp",
};

const imageByArt: Record<ProductArt, string> = {
  pistachio: "/products/pistachio-pouch-new.webp",
  almond: "/products/almond-pouch-new.webp",
  walnut: "/products/walnut-character-new.webp",
  fruit: "/products/dried-fruit.webp",
  seed: "/products/pumpkin-seeds.webp",
  cookie: "/products/oat-cookie.webp",
  gift: "/products/gift-box.webp",
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
    "/products/dried-fruit.webp",
  ],
  "protein-cookie": [
    "/products/protein-cookie.webp",
    "/products/cocoa-cookie-dragon.webp",
    "/products/dragon-box-new.webp",
  ],
  "fruit-leather": [
    "/products/fruit-leather.webp",
  ],
  "oat-cookie": [
    "/products/oat-cookie.webp",
    "/products/cookie-mouth-packaging.webp",
  ],
  "gift-box": [
    "/products/gift-box.webp",
    "/products/one-kilo-box-packaging.webp",
    "/products/mixed-nuts-character.webp",
    "/products/gift-boxes-new.webp",
  ],
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
