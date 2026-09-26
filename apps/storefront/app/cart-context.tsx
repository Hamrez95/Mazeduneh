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
  change: (id: string, delta: number) => void;
  remove: (id: string) => void;
  clear: () => void;
};

const CartContext = createContext<CartValue | null>(null);
const storageKey = "mazedooneh-cart-v1";
const freeShippingLimit = 1_500_000;
const shippingFee = 75_000;

export function CartProvider({ children }: { children: ReactNode }) {
  const [cart, setCart] = useState<CartLine[]>([]);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    try {
      const saved = window.localStorage.getItem(storageKey);
      if (saved) {
        const parsed: unknown = JSON.parse(saved);
        if (Array.isArray(parsed)) setCart(parsed.filter((line) => line && typeof line.id === "string" && Number.isFinite(line.quantity) && line.quantity > 0));
      }
    } catch {
      window.localStorage.removeItem(storageKey);
    }
    setReady(true);
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
          const found = current.find((line) => line.id === product.id);
          if (!found) return [...current, { ...product, quantity: 1 }];
          return current.map((line) => line.id === product.id
            ? { ...line, quantity: Math.min(line.quantity + 1, product.stock) }
            : line);
        });
      },
      change(id, delta) {
        setCart((current) => current
          .map((line) => line.id === id ? { ...line, quantity: Math.max(0, Math.min(line.quantity + delta, line.stock)) } : line)
          .filter((line) => line.quantity > 0));
      },
      remove(id) { setCart((current) => current.filter((line) => line.id !== id)); },
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
