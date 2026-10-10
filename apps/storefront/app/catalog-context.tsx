"use client";

import { createContext, useCallback, useContext, useEffect, useRef, useState } from "react";
import type { ReactNode } from "react";
import { API_BASE, fetchLiveProducts, fetchLiveCategories } from "./api-catalog";
import { demoProducts, categories } from "./demo/catalog";
import { catalogFailure, catalogSuccess, initialCatalog, type CatalogState } from "./catalog-state";

type CatalogValue = CatalogState & { refresh: () => void };
const CatalogContext = createContext<CatalogValue | null>(null);

export function CatalogProvider({ children }: { children: ReactNode }) {
  const [catalog, setCatalog] = useState(() => initialCatalog(Boolean(API_BASE), demoProducts, categories));
  const request = useRef<AbortController | null>(null);
  const generation = useRef(0);
  const refresh = useCallback(() => {
    if (!API_BASE) return;
    request.current?.abort();
    const controller = new AbortController();
    request.current = controller;
    const current = ++generation.current;
    Promise.all([fetchLiveProducts(controller.signal), fetchLiveCategories(controller.signal)])
      .then(([products, names]) => {
        if (current === generation.current && !controller.signal.aborted) {
          setCatalog(catalogSuccess(products ?? [], names ?? []));
        }
      })
      .catch(() => {
        if (current === generation.current && !controller.signal.aborted) setCatalog(catalogFailure);
      });
  }, []);
  useEffect(() => {
    refresh();
    window.addEventListener("focus", refresh);
    window.addEventListener("online", refresh);
    return () => {
      generation.current++;
      request.current?.abort();
      window.removeEventListener("focus", refresh);
      window.removeEventListener("online", refresh);
    };
  }, [refresh]);
  return <CatalogContext.Provider value={{ ...catalog, refresh }}>{children}</CatalogContext.Provider>;
}

export function useCatalog() {
  const catalog = useContext(CatalogContext);
  if (!catalog) throw new Error("useCatalog requires CatalogProvider");
  return catalog;
}

export function CatalogFeedback() {
  const { status, refresh } = useCatalog();
  if (status === "live" || status === "preview") return null;
  return <div role="status" aria-live="polite" style={{ padding: "1rem", overflowWrap: "anywhere" }}>
    {status === "loading" && "در حال دریافت محصولات…"}
    {status === "error" && "محصولات دریافت نشد. اتصال را بررسی کنید و دوباره تلاش کنید."}
    {status === "stale" && "اتصال قطع شده؛ آخرین محصولات دریافت‌شده نمایش داده می‌شوند. قیمت و موجودی هنگام ثبت سفارش دوباره بررسی می‌شوند."}
    {(status === "error" || status === "stale") && <button type="button" onClick={refresh}>دریافت دوباره</button>}
  </div>;
}
