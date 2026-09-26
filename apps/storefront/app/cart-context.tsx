"use client";

import { createContext, useContext, useEffect, useMemo, useState } from "react";
import type { ReactNode } from "react";
import type { DemoProduct } from "./demo/catalog";

export type CartLine = DemoProduct & { quantity: number };
type CartValue = {
  cart: CartLine[];
  count: number;
  subtotal: number;
  shipping: number;
  total: number;
  add: (product: DemoProduct) => void;
  change: (key: string, delta: number) => void;
  remove: (key: string) => void;
  clear: () => void;
};

const CartContext = createContext<CartValue | null>(null);
const storageKey = "mazedooneh-cart-v1";
const freeShippingLimit = 1_500_000;
const shippingFee = 75_000;

function normalizeStoredCart(value: unknown): CartLine[] {
  if (!Array.isArray(value)) return [];
  return value.flatMap((line) => {
    if (!line || typeof line !== "object") return [];
    const item = line as Record<string, unknown>;
    if (typeof item.id === "string" && typeof item.title === "string") {
      return Number.isFinite(item.quantity) && Number(item.quantity) > 0 ? [{ ...item, quantity: Number(item.quantity) } as CartLine] : [];
    }
    if (typeof item.sku === "string" && typeof item.productTitle === "string") {
      const quantity = Number(item.quantity);
      const unitPrice = Number(item.unitPrice);
      const stock = Number(item.maxQuantity);
      if (!Number.isFinite(quantity) || quantity <= 0 || !Number.isFinite(unitPrice) || !Number.isFinite(stock)) return [];
      return [{
        id: typeof item.productSlug === "string" && item.productSlug ? item.productSlug : item.sku,
        sku: item.sku,
        title: item.productTitle,
        subtitle: item.variantLabel,
        category: "کاتالوگ مزه‌دونه",
        origin: "مزه‌دونه",
        art: "almond",
        accent: "sage",
        price: Math.max(0, Math.round(unitPrice / 10)),
        packageLabel: item.variantLabel,
        stock,
        note: "محصول کاتالوگ آنلاین",
        quantity,
      }];
    }
    return [];
  });
}

export function CartProvider({ children }: { children: ReactNode }) {
  const [cart, setCart] = useState<CartLine[]>([]);
  const [ready, setReady] = useState(false);

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
    window.addEventListener("mazeduneh-cart-updated", readStoredCart);
    return () => window.removeEventListener("mazeduneh-cart-updated", readStoredCart);
  }, []);

  useEffect(() => {
    if (ready) window.localStorage.setItem(storageKey, JSON.stringify(cart));
  }, [cart, ready]);

  const value = useMemo<CartValue>(() => {
    const count = cart.reduce((sum, line) => sum + line.quantity, 0);
    const subtotal = cart.reduce((sum, line) => sum + line.price * line.quantity, 0);
    const shipping = subtotal === 0 || subtotal >= freeShippingLimit ? 0 : shippingFee;
    return {
      cart,
      count,
      subtotal,
      shipping,
      total: subtotal + shipping,
      add(product) {
        setCart((current) => {
          const found = current.find((line) => product.sku ? line.sku === product.sku : line.id === product.id);
          if (!found) return [...current, { ...product, quantity: 1 }];
          return current.map((line) => (product.sku ? line.sku === product.sku : line.id === product.id)
            ? { ...line, quantity: Math.min(line.quantity + 1, product.stock) }
            : line);
        });
      },
      change(key, delta) {
        setCart((current) => current
          .map((line) => (line.sku ?? line.id) === key ? { ...line, quantity: Math.max(0, Math.min(line.quantity + delta, line.stock)) } : line)
          .filter((line) => line.quantity > 0));
      },
      remove(key) { setCart((current) => current.filter((line) => (line.sku ?? line.id) !== key)); },
      clear() { setCart([]); },
    };
  }, [cart]);

  return <CartContext.Provider value={value}>{children}</CartContext.Provider>;
}

export function useCart() {
  const value = useContext(CartContext);
  if (!value) throw new Error("useCart must be used inside CartProvider");
  return value;
}
