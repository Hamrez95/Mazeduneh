"use client";

import type { DemoProduct, ProductArt } from "./demo/catalog";

type ApiProductVariant = {
  sku: string;
  quantity: number;
  baseUnit: string;
  displayLabel: string;
  price: number;
  availablePackages: number;
};

export type ApiProduct = {
  id: string;
  title: string;
  slug: string;
  category: string;
  origin: string;
  currency: string;
  unitType: "Weight" | "Count";
  isPublished: boolean;
  variants: ApiProductVariant[];
};

export const API_BASE = (
  process.env.NEXT_PUBLIC_MAZEDUNEH_API_URL?.trim()
  || process.env.NEXT_PUBLIC_MAZEDUNEH_API_BASE_URL?.trim()
  || ""
).replace(/\/$/, "");

const artByKeyword: Array<[string, ProductArt]> = [
  ["پسته", "pistachio"],
  ["بادام", "almond"],
  ["گردو", "walnut"],
  ["میوه", "fruit"],
  ["لواشک", "fruit"],
  ["تخمه", "seed"],
  ["کوکی", "cookie"],
  ["شیرینی", "cookie"],
  ["هدیه", "gift"],
];

const accents = ["sage", "mint", "sand", "peach", "apricot", "olive", "lilac", "rose"] as const;

function inferArt(title: string): ProductArt {
  return artByKeyword.find(([keyword]) => title.includes(keyword))?.[1] ?? "almond";
}

function inferAccent(slug: string) {
  let hash = 0;
  for (const character of slug) hash = (hash * 31 + character.charCodeAt(0)) | 0;
  return accents[Math.abs(hash) % accents.length];
}

function tomanFromApiPrice(price: number) {
  return Math.max(0, Math.round(price / 10));
}

export function mapApiProduct(product: ApiProduct): DemoProduct | null {
  const variants = product.variants
    ?.filter((variant) => variant.availablePackages > 0)
    .sort((left, right) => left.quantity - right.quantity);
  const variant = variants?.[0];
  if (!variant || !product.isPublished) return null;

  return {
    id: product.slug,
    sku: variant.sku,
    variants: variants.map((item) => ({
      sku: item.sku,
      packageLabel: item.displayLabel,
      price: tomanFromApiPrice(item.price),
      stock: item.availablePackages,
    })),
    title: product.title,
    subtitle: `${variant.displayLabel} · ${product.unitType === "Weight" ? "فروش وزنی" : "فروش عددی"}`,
    category: product.category,
    origin: product.origin,
    art: inferArt(product.title),
    accent: inferAccent(product.slug),
    price: tomanFromApiPrice(variant.price),
    packageLabel: variant.displayLabel,
    stock: variant.availablePackages,
    note: `کد کالا: ${variant.sku}`,
  };
}

export async function fetchLiveProducts(signal?: AbortSignal) {
  if (!API_BASE) return null;
  const response = await fetch(`${API_BASE}/api/v1/products`, { signal, cache: "no-store" });
  if (!response.ok) throw new Error(`catalog-${response.status}`);
  const payload = await response.json() as ApiProduct[];
  return payload.map(mapApiProduct).filter((product): product is DemoProduct => product !== null);
}

export async function fetchLiveProduct(slug: string, signal?: AbortSignal) {
  if (!API_BASE) return null;
  const response = await fetch(`${API_BASE}/api/v1/products/${encodeURIComponent(slug)}`, { signal, cache: "no-store" });
  if (!response.ok) throw new Error(`product-${response.status}`);
  return mapApiProduct(await response.json() as ApiProduct);
}
