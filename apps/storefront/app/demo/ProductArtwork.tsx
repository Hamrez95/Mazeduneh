import type { DemoProduct, ProductArt } from "./catalog";
import styles from "./professional-storefront.module.css";

const imageByProductId: Record<string, string> = {
  "pistachio-akbari": "/products/pistachio-pouch.webp",
  "pistachio-ahmad": "/products/pistachio-pouch.webp",
  almond: "/products/almond-pouch.webp",
  walnut: "/products/walnut-character.webp",
  "dried-fruit": "/products/gift-wrap-packaging.webp",
  "pumpkin-seeds": "/products/pumpkin-seeds.webp",
  "protein-cookie": "/products/cocoa-cookie-dragon.webp",
  "fruit-leather": "/products/gift-wrap-packaging.webp",
  "oat-cookie": "/products/cookie-mouth-packaging.webp",
  "gift-box": "/products/one-kilo-box-packaging.webp",
};

const imageByArt: Record<ProductArt, string> = {
  pistachio: "/products/pistachio-pouch.webp",
  almond: "/products/almond-pouch.webp",
  walnut: "/products/walnut-character.webp",
  fruit: "/products/gift-wrap-packaging.webp",
  seed: "/products/pumpkin-seeds.webp",
  cookie: "/products/cocoa-cookie-dragon.webp",
  gift: "/products/one-kilo-box-packaging.webp",
};

export function ProductArtwork({
  product,
  hero = false,
}: {
  product: DemoProduct;
  hero?: boolean;
}) {
  const src = imageByProductId[product.id] ?? imageByArt[product.art];
  return (
    <img
      className={hero ? styles.heroProductImage : styles.productImage}
      src={src}
      alt={`تصویرسازی ${product.title}`}
      loading={hero ? "eager" : "lazy"}
      decoding="async"
    />
  );
}
