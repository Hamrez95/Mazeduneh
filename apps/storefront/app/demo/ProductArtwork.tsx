import type { DemoProduct, ProductArt } from "./catalog";
import styles from "./professional-storefront.module.css";

const imageByProductId: Record<string, string> = {
  "pistachio-akbari": "/products/pistachio-akbari.webp",
  "pistachio-ahmad": "/products/pistachio-ahmad.webp",
  almond: "/products/almond.webp",
  walnut: "/products/walnut.webp",
  "dried-fruit": "/products/dried-fruit.webp",
  "pumpkin-seeds": "/products/pumpkin-seeds.webp",
  "protein-cookie": "/products/protein-cookie.webp",
  "fruit-leather": "/products/fruit-leather.webp",
  "oat-cookie": "/products/oat-cookie.webp",
  "gift-box": "/products/gift-box.webp",
};

const imageByArt: Record<ProductArt, string> = {
  pistachio: "/products/pistachio-akbari.webp",
  almond: "/products/almond.webp",
  walnut: "/products/walnut.webp",
  fruit: "/products/dried-fruit.webp",
  seed: "/products/pumpkin-seeds.webp",
  cookie: "/products/oat-cookie.webp",
  gift: "/products/gift-box.webp",
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
