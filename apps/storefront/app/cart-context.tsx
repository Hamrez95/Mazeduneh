"use client";

import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from "react";
import type { ReactNode } from "react";
import type { DemoProduct } from "./demo/catalog";
import { rialsToTomans } from "./formatters";
import { API_BASE } from "./api-catalog";
import { defaultShippingMethod, estimateCommerce, parseCommerceSettings, previewCommerceSettings, type PublicCommerceSettings } from "./commerce-settings";
import { useCatalog } from "./catalog-context";

export type CartLine = DemoProduct & { quantity: number };

export function cartLineMatchesProduct(line: CartLine, product: DemoProduct) {
  return product.sku
    ? line.sku === product.sku || (!line.sku && line.id === product.id && line.packageLabel === product.packageLabel)
    : line.id === product.id && line.packageLabel === product.packageLabel;
}
type CartValue = {
  cart: CartLine[];
  ready: boolean;
  count: number;
  subtotal: number;
  shipping: number;
  total: number;
  tax: number;
  commerce: PublicCommerceSettings | null;
  pricingReady: boolean;
  pricingLoading: boolean;
  freeShippingLimit: number | null;
  refreshPricing: () => void;
  add: (product: DemoProduct) => void;
  change: (key: string, delta: number) => void;
  remove: (key: string) => void;
  clear: () => void;
};

const CartContext = createContext<CartValue | null>(null);
const storageKey = "mazedooneh-cart-v1";

function normalizeStoredCart(value: unknown): CartLine[] {
  if (!Array.isArray(value)) return [];
  return value.flatMap((line) => {
    if (!line || typeof line !== "object") return [];
    const item = line as Record<string, unknown>;
    if (typeof item.id === "string" && typeof item.title === "string") {
      const quantity = Number(item.quantity);
      const price = Number(item.price);
      const stock = Number(item.stock);
      return Number.isSafeInteger(quantity) && quantity > 0 && Number.isFinite(price) && price >= 0 && Number.isSafeInteger(stock) && stock >= 0
        ? [{ ...item, quantity, price, stock } as CartLine] : [];
    }
    if (typeof item.sku === "string" && typeof item.productTitle === "string") {
      const quantity = Number(item.quantity);
      const unitPrice = Number(item.unitPrice);
      const stock = Number(item.maxQuantity);
      if (!Number.isSafeInteger(quantity) || quantity <= 0 || !Number.isFinite(unitPrice) || unitPrice < 0 || !Number.isSafeInteger(stock) || stock < 0) return [];
      const variantLabel = typeof item.variantLabel === "string" ? item.variantLabel : "بستهٔ انتخابی";
      return [{
        id: typeof item.productSlug === "string" && item.productSlug ? item.productSlug : item.sku,
        sku: item.sku,
        title: item.productTitle,
        subtitle: variantLabel,
        category: "کاتالوگ مزه‌دونه",
        origin: "مزه‌دونه",
        art: "almond",
        accent: "sage",
        price: Math.max(0, rialsToTomans(unitPrice)),
        packageLabel: variantLabel,
        stock,
        note: "محصول کاتالوگ آنلاین",
        quantity,
      }];
    }
    return [];
  });
}

export function CartProvider({ children }: { children: ReactNode }) {
  const { products, status: catalogStatus } = useCatalog();
  const [cart, setCart] = useState<CartLine[]>([]);
  const [ready, setReady] = useState(false);
  const [commerce, setCommerce] = useState<PublicCommerceSettings | null>(API_BASE ? null : previewCommerceSettings);
  const [pricingLoading, setPricingLoading] = useState(Boolean(API_BASE));
  const pricingRequest = useRef<AbortController | null>(null);
  const refreshPricing = useCallback(() => {
    if (!API_BASE) return;
    pricingRequest.current?.abort();
    const controller = new AbortController();
    pricingRequest.current = controller;
    setPricingLoading(true);
    fetch(`${API_BASE}/api/v1/commerce/shipping-methods`, { cache: "no-store", signal: controller.signal })
      .then(async response => {
        if (!response.ok) throw new Error("commerce-settings");
        const settings = parseCommerceSettings(await response.json());
        if (!settings) throw new Error("commerce-settings");
        if (!controller.signal.aborted) setCommerce(settings);
      })
      .catch(() => { if (!controller.signal.aborted) setCommerce(null); })
      .finally(() => { if (!controller.signal.aborted) setPricingLoading(false); });
  }, []);

  useEffect(() => {
    refreshPricing();
    window.addEventListener("focus", refreshPricing);
    window.addEventListener("online", refreshPricing);
    return () => {
      pricingRequest.current?.abort();
      window.removeEventListener("focus", refreshPricing);
      window.removeEventListener("online", refreshPricing);
    };
  }, [refreshPricing]);

  useEffect(() => {
    const readStoredCart = () => {
      try {
        const saved = window.localStorage.getItem(storageKey);
        setCart(normalizeStoredCart(saved ? JSON.parse(saved) : []));
      } catch {
        window.localStorage.removeItem(storageKey);
        setCart([]);
      }
      setReady(true);
    };
    readStoredCart();
    const syncOtherTab = (event: StorageEvent) => {
      if (event.key === storageKey || event.key === null) readStoredCart();
    };
    window.addEventListener("mazeduneh-cart-updated", readStoredCart);
    window.addEventListener("storage", syncOtherTab);
    return () => {
      window.removeEventListener("mazeduneh-cart-updated", readStoredCart);
      window.removeEventListener("storage", syncOtherTab);
    };
  }, []);

  useEffect(() => {
    if (!ready || catalogStatus !== "live") return;
    setCart(current => {
      let changed = false;
      const updated = current.map(line => {
        const product = products.find(item => item.id === line.id);
        const variant = product?.variants?.find(item => item.sku === line.sku);
        const stock = variant?.stock ?? (line.sku ? 0 : product?.stock ?? 0);
        const price = variant?.price ?? line.price;
        if (price === line.price && stock === line.stock) return line;
        changed = true;
        return { ...line, price, stock };
      });
      return changed ? updated : current;
    });
  }, [ready, products, catalogStatus]);

  useEffect(() => {
    if (ready) window.localStorage.setItem(storageKey, JSON.stringify(cart));
  }, [cart, ready]);

  const clear = useCallback(() => {
    window.localStorage.removeItem(storageKey);
    setCart([]);
  }, []);

  const value = useMemo<CartValue>(() => {
    const count = cart.reduce((sum, line) => sum + line.quantity, 0);
    const subtotal = cart.reduce((sum, line) => sum + line.price * line.quantity, 0);
    const estimate = estimateCommerce(subtotal, commerce);
    const shipping = estimate?.shipping ?? 0;
    const method = defaultShippingMethod(commerce);
    return {
      cart,
      ready,
      count,
      subtotal,
      shipping,
      total: estimate?.total ?? subtotal,
      tax: estimate?.tax ?? 0,
      commerce,
      pricingReady: Boolean(estimate) && !pricingLoading,
      pricingLoading,
      freeShippingLimit: method && method.freeAbove > 0 ? method.freeAbove / 10 : null,
      refreshPricing,
      add(product) {
        if (!ready || product.stock <= 0) return;
        setCart((current) => {
          const matchesProduct = (line: CartLine) => cartLineMatchesProduct(line, product);
          const found = current.find(matchesProduct);
          if (!found) return [...current, { ...product, quantity: 1 }];
          return current.map((line) => matchesProduct(line)
            ? { ...line, ...product, quantity: Math.min(line.quantity + 1, product.stock) }
            : line);
        });
      },
      change(key, delta) {
        setCart((current) => current
          .map((line) => (line.sku ?? line.id) === key ? { ...line, quantity: delta > 0 ? Math.max(line.quantity, Math.min(line.quantity + delta, line.stock)) : Math.max(0, line.quantity + delta) } : line)
          .filter((line) => line.quantity > 0));
      },
      remove(key) { setCart((current) => current.filter((line) => (line.sku ?? line.id) !== key)); },
      clear,
    };
  }, [cart, clear, ready, commerce, pricingLoading, refreshPricing]);

  return <CartContext.Provider value={value}>{children}</CartContext.Provider>;
}

export function useCart() {
  const value = useContext(CartContext);
  if (!value) throw new Error("useCart must be used inside CartProvider");
  return value;
}
