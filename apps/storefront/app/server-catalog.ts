import { cache } from "react";
import { mapApiProduct, type ApiProduct } from "./api-catalog";
import type { CatalogState } from "./catalog-state";

const configured = process.env.NEXT_PUBLIC_MAZEDUNEH_DEMO_MODE !== "true";
const api = configured ? (process.env.MAZEDUNEH_API_INTERNAL_URL?.trim()
  || process.env.NEXT_PUBLIC_MAZEDUNEH_API_URL?.trim()
  || process.env.NEXT_PUBLIC_MAZEDUNEH_API_BASE_URL?.trim() || "").replace(/\/$/, "") : "";

// Request-local deduplication plus Next's bounded revalidation cache. Checkout
// continues to calculate prices and reserve inventory against the live API.
export const readPublishedProduct = cache(async (slug: string): Promise<{ product?: ApiProduct; missing?: boolean }> => {
  if (!api) return {};
  try {
    const response = await fetch(`${api}/api/v1/products/${encodeURIComponent(slug)}`, {
      next: { revalidate: 60 }, signal: AbortSignal.timeout(3000),
    });
    if (response.status === 404) return { missing: true };
    if (!response.ok) return {};
    const product = await response.json() as ApiProduct;
    if (product.isPublished === false) return { missing: true };
    return product.isPublished === true && Array.isArray(product.variants) ? { product } : {};
  } catch { return {}; }
});

export const readServerCatalog = cache(async (): Promise<CatalogState | undefined> => {
  if (!api) return undefined;
  try {
    const response = await fetch(`${api}/api/v1/products`, {
      next: { revalidate: 60 }, signal: AbortSignal.timeout(3000),
    });
    if (!response.ok) return undefined;
    const raw = await response.json() as ApiProduct[];
    if (!Array.isArray(raw)) return undefined;
    const products = raw.map(mapApiProduct).filter((p): p is NonNullable<typeof p> => p !== null);
    return { products, categories: [...new Set(products.map(p => p.category))], status: "live" };
  } catch { return undefined; }
});

export const hasServerCatalog = Boolean(api);
