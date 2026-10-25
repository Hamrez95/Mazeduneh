"use client";

import { useEffect, useRef } from "react";
import { cartLineMatchesProduct, useCart } from "./cart-context";
import type { DemoProduct } from "./demo/catalog";
import { formatNumber } from "./formatters";
import styles from "./product-cart-control.module.css";

export function ProductCartControl({ product, detail = false }: { product: DemoProduct; detail?: boolean }) {
  const { cart, add, change, ready } = useCart();
  const line = cart.find(item => cartLineMatchesProduct(item, product));
  const quantity = ready ? line?.quantity ?? 0 : 0;
  const description = `${product.title}، ${product.packageLabel}`;
  const increaseRef = useRef<HTMLButtonElement>(null);
  const controlRef = useRef<HTMLDivElement>(null);
  const restoreFocus = useRef(false);

  useEffect(() => {
    if (restoreFocus.current && quantity === 0) {
      if (increaseRef.current?.disabled) controlRef.current?.focus();
      else increaseRef.current?.focus();
      restoreFocus.current = false;
    }
  }, [quantity]);

  return <div ref={controlRef} tabIndex={-1} className={`${styles.control} ${detail ? styles.detail : ""}`} role="group" aria-label={`انتخاب تعداد ${description}`}>
    <div className={`${styles.row} ${quantity > 0 ? styles.hasQuantity : ""}`}>
      <button ref={increaseRef} className={styles.increase} type="button"
        disabled={!ready || product.stock <= 0 || quantity >= product.stock}
        aria-label={quantity > 0 ? `افزایش تعداد ${description}` : detail ? "افزودن به سبد خرید" : `افزودن ${product.title} به سبد`}
        title={quantity >= product.stock && quantity > 0 ? "همهٔ موجودی این بسته در سبد شماست" : undefined}
        onClick={() => add(product)}>
        {quantity > 0 ? <span aria-hidden="true">+</span> : !ready ? "آماده‌سازی سبد…" : product.stock <= 0 ? "ناموجود" : detail ? "افزودن به سبد خرید" : <>افزودن <span aria-hidden="true">+</span></>}
      </button>
      {quantity > 0 && <>
        <output className={styles.quantity} aria-live="polite" aria-atomic="true" aria-label={`تعداد ${description} در سبد خرید`}>{formatNumber(quantity)}</output>
        <button className={styles.decrease} type="button" disabled={!ready} aria-label={`کاهش تعداد ${description}`}
          title={quantity === 1 ? "حذف این بسته از سبد" : "یک بسته کمتر"}
          onClick={() => { if (line) { restoreFocus.current = quantity === 1; change(line.sku ?? line.id, -1); } }}><span aria-hidden="true">−</span></button>
      </>}
    </div>
    {quantity > 0 && <span className={styles.caption}>در سبد شما</span>}
  </div>;
}
