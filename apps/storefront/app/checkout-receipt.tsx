"use client";

import { formatRialsAsTomans, toPersianDigits } from "./formatters";
import { paymentIsConfirmed, receiptClosingLine, type CheckoutReceipt } from "./order-receipt";
import styles from "./checkout-receipt.module.css";

type Props = {
  receipt: CheckoutReceipt; message: string; paying: boolean; downloading: boolean; revoking: boolean; consentRevoked: boolean;
  onPay: () => void; onRefresh: () => void; onSandbox: () => void; onDownload: () => void; onRevokeConsent: () => void;
};

export function CheckoutReceiptView({ receipt, message, paying, downloading, revoking, consentRevoked, onPay, onRefresh, onSandbox, onDownload, onRevokeConsent }: Props) {
  const confirmed = paymentIsConfirmed(receipt.state);
  const awaiting = receipt.state === "AwaitingPayment";
  const name = receipt.name.trim() || "دوست خوش‌سلیقهٔ ما";
  const stateLabel: Record<string, string> = { Paid: "پرداخت تأییدشده", Preparing: "در حال آماده‌سازی", Shipped: "ارسال‌شده", Delivered: "تحویل‌شده", AwaitingPayment: "در انتظار پرداخت", Cancelled: "لغوشده", Expired: "مهلت پرداخت پایان‌یافته" };
  const headline = confirmed ? "خریدت کامل شد؛ به جمع خوش‌خوراک‌ها خوش آمدی!" : awaiting ? (receipt.paymentOutcome === "failed" ? "پرداختت تأیید نشد؛ سفارشت اینجاست." : "سفارش ثبت شد؛ یک قدم تا تکمیل خرید.") : receipt.state === "Cancelled" ? "این سفارش لغو شده است." : receipt.state === "Expired" ? "مهلت پرداخت این سفارش تمام شده است." : "وضعیت سفارشت را بررسی کن.";
  const expiry = new Date(receipt.expiresAt);
  return <section className={styles.receipt} aria-labelledby="receipt-title">
    <div className={`${styles.hero} ${confirmed ? styles.confirmed : styles.pending}`}>
      <span className={styles.status}>{stateLabel[receipt.state] ?? "وضعیت سفارش"}</span>
      <div className={styles.emblem} aria-hidden="true"><svg viewBox="0 0 48 48" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">{confirmed ? <><path d="m14 24 7 7 14-15" /><path d="M39 23v12a5 5 0 0 1-5 5H14a5 5 0 0 1-5-5V15a5 5 0 0 1 5-5h14" /></> : <><circle cx="24" cy="24" r="16" /><path d="M24 14v11l7 4" /></>}</svg></div>
      <p className={styles.greeting}>{name} عزیز،</p>
      <h1 id="receipt-title" tabIndex={-1}>{headline}</h1>
      <p className={styles.intro}>{confirmed ? "ممنون که برای خوشمزه‌تر شدن لحظه‌هایت به مزه‌دونه اعتماد کردی. جزئیات خریدت همین‌جاست؛ فاکتورت را هم می‌توانی نگه داری." : awaiting ? "جزئیات سفارش ثبت شده است. خرید وقتی کامل می‌شود که تأیید پرداخت را از درگاه دریافت کنیم." : "جزئیات این سفارش برای پیگیری در دسترس است. برای یک خرید تازه می‌توانی به فروشگاه برگردی."}</p>
      {confirmed && <p className={styles.personalNote}>{receiptClosingLine(receipt.orderId)}</p>}
    </div>

    <div className={styles.body}>
      <div className={styles.orderMeta}><div><span>شناسهٔ سفارش برای پیگیری</span><bdi dir="ltr">{receipt.orderId}</bdi></div><div><span>{confirmed ? "مبلغ پرداخت‌شده" : awaiting ? "مبلغ قابل پرداخت" : "مبلغ سفارش"}</span><strong>{formatRialsAsTomans(receipt.payable)} <small>تومان</small></strong></div></div>
      {confirmed && <ol className={styles.steps} aria-label="مراحل سفارش"><li className={styles.done}><b>۱</b><span>ثبت و تأیید پرداخت</span></li><li className={["Preparing", "Shipped", "Delivered"].includes(receipt.state) ? styles.done : ""}><b>۲</b><span>آماده‌سازی سفارش</span></li><li className={["Shipped", "Delivered"].includes(receipt.state) ? styles.done : ""}><b>۳</b><span>{receipt.state === "Delivered" ? "تحویل‌شده" : "تحویل به شرکت ارسال"}</span></li></ol>}
      {message && <p className={styles.message} role="status" aria-live="polite">{message}</p>}
      {awaiting && Number.isFinite(expiry.getTime()) && <p className={styles.expiry}>کالاهای سفارشت تا {new Intl.DateTimeFormat("fa-IR", { dateStyle: "medium", timeStyle: "short" }).format(expiry)} رزرو هستند.</p>}

      <div className={styles.details}>
        {!!receipt.lines?.length && <section className={styles.items}><h2>انتخاب‌های خوشمزهٔ تو</h2><ul>{receipt.lines.map((line, index) => <li key={`${line.sku}-${index}`}><div><strong>{line.productTitle}</strong><span>{toPersianDigits(line.variantLabel)} · {toPersianDigits(String(line.quantity))} بسته</span></div><b>{formatRialsAsTomans(line.lineTotal)} <small>تومان</small></b></li>)}</ul></section>}
        <section className={styles.summary}><h2>خلاصهٔ پرداخت</h2><dl>{receipt.subtotal != null && <div><dt>جمع کالاها</dt><dd>{formatRialsAsTomans(receipt.subtotal)} تومان</dd></div>}{receipt.discount != null && receipt.discount > 0 && <div><dt>تخفیف خریدت</dt><dd>{formatRialsAsTomans(receipt.discount)} تومان</dd></div>}<div><dt>هزینهٔ ارسال</dt><dd>{receipt.shipping ? `${formatRialsAsTomans(receipt.shipping)} تومان` : "رایگان"}</dd></div><div><dt>مالیات</dt><dd>{formatRialsAsTomans(receipt.tax)} تومان</dd></div><div className={styles.total}><dt>مبلغ نهایی</dt><dd>{formatRialsAsTomans(receipt.payable)} تومان</dd></div></dl></section>
      </div>

      <div className={styles.actions}>
        {awaiting && receipt.sandboxAuthority && <button type="button" className={styles.primary} disabled={paying} onClick={onSandbox}>{paying ? "در حال تأیید…" : "تأیید پرداخت آزمایشی (بدون برداشت وجه)"}</button>}
        {awaiting && receipt.paymentOutcome === "review" && <button type="button" className={styles.primary} onClick={onRefresh}>بررسی دوبارهٔ وضعیت پرداخت</button>}
        {awaiting && receipt.paymentOutcome !== "review" && !receipt.sandboxAuthority && <button type="button" className={styles.primary} disabled={paying} onClick={onPay}>ادامهٔ پرداخت</button>}
        <button className={confirmed ? styles.primary : styles.secondary} type="button" onClick={onDownload} disabled={downloading || !receipt.receiptToken}>{downloading ? "در حال آماده‌سازی فاکتور…" : "دانلود فاکتور خرید"}</button>
        <a className={styles.secondary} href="/shop">بازگشت به فروشگاه</a>
      </div>
      <p className={styles.downloadHint}>فاکتور را باز کن و با گزینهٔ «چاپ / ذخیره به PDF» نسخهٔ چاپی یا PDF آن را بگیر.</p>
      <footer className={styles.footer}><p>از اینکه مزه‌دونه را به لحظه‌هایت راه دادی، خوشحالیم.</p><span>با مهر، تیم مزه‌دونه</span><details><summary>تنظیم پیامک‌های معرفی و تخفیف</summary><button className={styles.consent} type="button" onClick={onRevokeConsent} disabled={revoking || consentRevoked || !receipt.receiptToken}>{consentRevoked ? "دریافت پیامک تبلیغاتی لغو شد" : revoking ? "در حال ثبت لغو…" : "لغو رضایت پیامکی"}</button></details></footer>
    </div>
  </section>;
}
