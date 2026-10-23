"use client";

import { useEffect, useState } from "react";
import { ShopShell } from "./store-chrome";
import { SocialSupport } from "./social-support";
import { formatRialsAsTomans } from "./formatters";
import type { CheckoutReceipt } from "./order-receipt";
import styles from "./store-pages.module.css";

export function GuestOrders() {
  const [receipt, setReceipt] = useState<CheckoutReceipt | null>(null);
  const [loading, setLoading] = useState(true);
  useEffect(() => {
    try {
      const value = JSON.parse(sessionStorage.getItem("mazedooneh-checkout-receipt-v1") ?? "null");
      if (value && typeof value.orderId === "string" && /^[0-9a-f-]{36}$/i.test(value.orderId) && typeof value.receiptToken === "string" && Number.isFinite(value.payable)) setReceipt(value);
    } catch { /* A missing local receipt never grants access to an order. */ }
    setLoading(false);
  }, []);
  return <ShopShell kicker="پیگیری خرید" title="سفارش من" description="خرید از مزه‌دونه به ساخت حساب نیاز ندارد؛ رسید همین مرورگر را اینجا باز کنید.">
    <section className={styles.content}>
      {loading ? <p role="status">در حال بازیابی رسید…</p> : receipt ? <article className={styles.infoCard}>
        <strong>آخرین سفارش این مرورگر</strong><p>شمارهٔ سفارش: <bdi>{receipt.orderId.slice(0, 8)}</bdi></p>
        <p>مبلغ ثبت‌شده: {formatRialsAsTomans(receipt.payable)} تومان</p>
        <a className={styles.primaryAction} href={`/checkout?orderId=${encodeURIComponent(receipt.orderId)}&payment=review`}>دیدن رسید و وضعیت فعلی سفارش</a>
        <p>وضعیت پرداخت و ارسال هنگام بازکردن رسید از فروشگاه دریافت می‌شود.</p>
      </article> : <article className={styles.infoCard}><strong>رسیدی در این مرورگر پیدا نشد.</strong><p>رسید را در همان مرورگر و نشستی باز کنید که خرید را ثبت کردید. اگر به آن دسترسی ندارید، شمارهٔ سفارش را در بله یا تلگرام برای مزه‌دونه بفرستید.</p><a className={styles.secondaryAction} href="/shop">رفتن به فروشگاه</a></article>}
      <div className={styles.storyBlock}><h2>برای پیگیری کنارتان هستیم</h2><SocialSupport /></div>
    </section>
  </ShopShell>;
}
