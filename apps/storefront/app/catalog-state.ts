import type { DemoProduct } from "./demo/catalog";

export type CatalogState = {
  products: DemoProduct[];
  categories: string[];
  status: "preview" | "loading" | "live" | "error" | "stale";
};

export function initialCatalog(apiConfigured: boolean, preview: DemoProduct[], categories: string[]): CatalogState {
  return apiConfigured
    ? { products: [], categories: [], status: "loading" }
    : { products: preview, categories: categories.filter((name) => name !== "همه"), status: "preview" };
}

export function catalogSuccess(products: DemoProduct[], categories: string[]): CatalogState {
  return { products, categories: [...new Set(categories)], status: "live" };
}

export function catalogFailure(previous: CatalogState): CatalogState {
  const hadLiveData = previous.status === "live" || previous.status === "stale";
  return hadLiveData ? { ...previous, status: "stale" } : { products: [], categories: [], status: "error" };
}
