"use client";

import { useEffect, useMemo, useState } from "react";
import type { FormEvent } from "react";
import { demoProducts, toman, type DemoProduct } from "./demo/catalog";
import { API_BASE, fetchLiveProduct } from "./api-catalog";
import { getProductArtworkGallery, ProductArtwork } from "./demo/ProductArtwork";
import { useCart } from "./cart-context";
import { ProductCard, RelatedProducts, ShopShell, StoreFooter, StoreHeader } from "./store-chrome";
import { formatInventory, formatRialsAsTomans, toPersianDigits } from "./formatters";
import styles from "./store-pages.module.css";
import { useCatalog, CatalogFeedback } from "./catalog-context";
import { CheckoutReceiptView } from "./checkout-receipt";
import { paymentIsConfirmed, type CheckoutReceipt, type ReceiptLine } from "./order-receipt";
import { defaultShippingMethod, estimateCommerce } from "./commerce-settings";
import { SocialSupport } from "./social-support";
import { GuestOrders } from "./guest-orders";
import { ProductCartControl } from "./product-cart-control";

export function CatalogPage() {
  const { products: catalogProducts } = useCatalog();
  const [category, setCategory] = useState("همه");
  const [query, setQuery] = useState("");
  const [sort, setSort] = useState("popular");
  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    setQuery(params.get("q") ?? "");
    setCategory(params.get("category") ?? "همه");
  }, []);
  const categoryOptions = useMemo(
    () => ["همه", ...Array.from(new Set(catalogProducts.map((product) => product.category)))],
    [catalogProducts],
  );
  const products = useMemo(() => {
    const normalized = query.trim().toLocaleLowerCase();
    const filtered = catalogProducts.filter((product) =>
      (category === "همه" || product.category === category)
      && (!normalized || `${product.title} ${product.subtitle} ${product.category} ${product.origin}`.toLocaleLowerCase().includes(normalized)),
    );
    return filtered.sort((a, b) => sort === "price-asc" ? a.price - b.price : sort === "price-desc" ? b.price - a.price : catalogProducts.indexOf(a) - catalogProducts.indexOf(b));
  }, [catalogProducts, category, query, sort]);

  return <ShopShell kicker="از قفسهٔ مزه‌دونه" title="هر روز، یک مزهٔ خوب" description="محصول‌ها را ببین، دسته‌بندی کن و جزئیات هر بسته را پیش از انتخاب بخوان.">
    <section className={styles.content}>
      <CatalogFeedback />
      <div className={styles.toolbar}>
        <div className={styles.categoryList} aria-label="فیلتر دسته‌بندی">
          {categoryOptions.map((item) => <button key={item} type="button" aria-pressed={category === item} onClick={() => setCategory(item)}>{item}</button>)}
        </div>
        <label className={styles.sortSelect}>مرتب‌سازی <select aria-label="مرتب‌سازی محصولات" value={sort} onChange={(event) => setSort(event.target.value)}><option value="popular">پیشنهادی</option><option value="price-asc">ارزان‌ترین</option><option value="price-desc">گران‌ترین</option></select></label>
      </div>
      <p className={styles.resultCount}>{toman(products.length)} محصول {query ? `برای «${query}»` : "در این فهرست"}</p>
      {products.length ? <div className={styles.productGrid}>{products.map((product) => <ProductCard key={product.id} product={product} />)}</div> : <div className={styles.emptyState}>محصولی با این جست‌وجو پیدا نشد. <a href="/shop">همهٔ محصولات را ببین</a></div>}
    </section>
  </ShopShell>;
}

function productFacts(product: DemoProduct) {
  const details = Object.entries(product.specifications ?? {})
    .filter(([label]) => label !== "مبدأ")
    .slice(0, 3);
  const weight = product.netWeight && product.netWeightUnit
    ? [["وزن خالص", toPersianDigits(product.netWeight) + " " + toPersianDigits(product.netWeightUnit)]]
    : [];
  return [["مبدأ", product.origin], ...weight, ...details] as Array<[string, string]>;
}

export function ProductPage({ product, live = false }: { product: DemoProduct; live?: boolean }) {
  const variants = product.variants?.length
    ? product.variants
    : [{ sku: product.sku ?? `${product.id}-preview`, packageLabel: product.packageLabel, price: product.price, stock: product.stock }];
  const [selectedSku, setSelectedSku] = useState(product.sku ?? variants[0].sku);
  useEffect(() => setSelectedSku(product.sku ?? variants[0].sku), [product.id, product.sku]);
  const selectedVariant = variants.find((variant) => variant.sku === selectedSku) ?? variants[0];
  const selectedProduct: DemoProduct = {
    ...product,
    sku: product.variants?.length ? selectedVariant.sku : product.sku,
    packageLabel: selectedVariant.packageLabel,
    price: selectedVariant.price,
    stock: selectedVariant.stock,
  };
  const gallery = getProductArtworkGallery(product, { live });
  const [activeImage, setActiveImage] = useState(gallery[0]);
  useEffect(() => setActiveImage(gallery[0]), [product.id]);

  return <main className={styles.page}>
    <StoreHeader />
    <div className={styles.detailLayout}>
      <div className={`${styles.detailVisual} ${styles[product.accent]}`}>
        <div className={styles.detailImageStage}>
          <ProductArtwork product={product} hero src={activeImage} live={live} />
        </div>
        {gallery.length > 1 && <div className={styles.detailGallery} aria-label={`تصاویر ${product.title}`}>
          {gallery.map((image, index) => (
            <button
              key={image}
              type="button"
              className={activeImage === image ? styles.detailGalleryActive : styles.detailGalleryButton}
              aria-label={`نمایش تصویر ${toman(index + 1)} از ${toman(gallery.length)}`}
              aria-pressed={activeImage === image}
              onClick={() => setActiveImage(image)}
            >
              <img src={image} alt="" loading={index === 0 ? "eager" : "lazy"} />
            </button>
          ))}
        </div>}
      </div>
      <div className={styles.detailInfo}>
        <div className={styles.breadcrumbs}><a href="/">خانه</a> ← <a href="/shop">فروشگاه</a> ← <a href={`/shop?category=${encodeURIComponent(product.category)}`}>{product.category}</a></div>
        <span className={styles.detailKicker}>{product.badge ?? "انتخاب مزه‌دونه"}</span>
        <h1>{product.title}</h1>
        <p className={styles.detailSubtitle}>{product.variants?.length ? product.subtitle.replace(product.packageLabel, selectedVariant.packageLabel) : product.subtitle}</p>
        {product.description && <p className={styles.detailDescription}>{product.description}</p>}
        <div className={styles.rating} aria-label="بدون امتیاز ثبت‌شده">☆☆☆☆☆ <span>هنوز امتیاز تأییدشده‌ای ثبت نشده</span></div>
        <div className={styles.detailPrice} role="status" aria-label="قیمت بستهٔ انتخاب‌شده" aria-live="polite" aria-atomic="true">{toman(selectedProduct.price)} <small>تومان</small></div>
        <p className={styles.variantTitle}>بستهٔ قابل انتخاب</p>
        <div className={styles.variantChoices} role="listbox" aria-label="انتخاب بسته">
          {variants.map((variant) => (
            <button
              key={variant.sku}
              type="button"
              role="option"
              aria-selected={variant.sku === selectedVariant.sku}
              className={variant.sku === selectedVariant.sku ? styles.variantOptionActive : styles.variantOption}
              onClick={() => setSelectedSku(variant.sku)}
            >
              <span>{variant.packageLabel}</span>
              <small>{toman(variant.price)} تومان · {formatInventory(variant.stock)}</small>
            </button>
          ))}
        </div>
        <div className={styles.detailBuy}><ProductCartControl product={selectedProduct} detail /><a href="/cart">رفتن به سبد</a></div>
        <div className={styles.facts}>{productFacts(product).map(([label, value]) => <div className={styles.fact} key={label}><small>{toPersianDigits(label)}</small><b>{toPersianDigits(value)}</b></div>)}</div>
        {(product.ingredients || product.allergens?.length || product.storageInstructions || (product.nutritionFacts && Object.keys(product.nutritionFacts).length) || product.shelfLifeDays || product.earliestAvailableExpiryAt) && (
          <section className={styles.foodDetails} aria-labelledby="food-details-title">
            <h2 id="food-details-title">اطلاعات خوراکی و نگهداری</h2>
            {product.ingredients && <div><h3>مواد تشکیل‌دهنده</h3><p>{product.ingredients}</p></div>}
            {product.allergens?.length ? <div><h3>آلرژن‌ها</h3><p>{product.allergens.join("، ")}</p></div> : null}
            {product.nutritionFacts && Object.keys(product.nutritionFacts).length > 0 && <div><h3>ارزش غذایی</h3><dl>{Object.entries(product.nutritionFacts).map(([label, value]) => <div key={label}><dt>{label}</dt><dd>{toPersianDigits(value)}</dd></div>)}</dl></div>}
            {product.storageInstructions && <div><h3>نحوه نگهداری</h3><p>{product.storageInstructions}</p></div>}
            {product.shelfLifeDays ? <div><h3>تاریخ و ماندگاری</h3><p>{toPersianDigits(product.expiryLabel || "best-before")} · {toPersianDigits(product.shelfLifeDays)} روز از تاریخ تولید، تاریخ دقیق روی بسته ثبت می‌شود.</p></div> : null}
            {product.earliestAvailableExpiryAt ? <div><h3>نزدیک‌ترین انقضای موجود</h3><p>{new Intl.DateTimeFormat("fa-IR", { dateStyle: "medium" }).format(new Date(product.earliestAvailableExpiryAt))}</p></div> : null}
          </section>
        )}
        <div className={styles.detailNotice}>{live ? "این اطلاعات از کاتالوگ منتشرشدهٔ سرویس فروش خوانده شده‌اند؛ جزئیات غذایی نهایی باید با بسته‌بندی تطبیق داده شوند." : "اطلاعات و قیمت‌های این نسخه نمونه‌اند. مشخصات قطعی ترکیبات، حساسیت‌زاها و وزن باید پیش از فروش از پنل محصول تأیید شوند."}</div>
      </div>
    </div>
    <section className={styles.detailTabs}>
      <h2>دربارهٔ این محصول</h2><p>{product.description || `${product.subtitle} · ${product.note}.`}</p>
      {product.specifications && Object.keys(product.specifications).length > 0 && <div className={styles.specGrid}>{Object.entries(product.specifications).map(([label, value]) => <div className={styles.specItem} key={label}><small>{label}</small><strong>{value}</strong></div>)}</div>}
      <div className={styles.reviewHeading}><h2>دیدگاه خریداران</h2></div>
      <div className={styles.reviewEmpty}>هنوز دیدگاه تأییدشده‌ای برای این محصول ثبت نشده است.</div>
    </section>
    <RelatedProducts currentId={product.id} />
    <StoreFooter />
  </main>;
}

export function LiveProductPage({ slug }: { slug: string }) {
  const fallback = API_BASE ? undefined : demoProducts.find((item) => item.id === slug);
  const [product, setProduct] = useState<DemoProduct | undefined>(fallback);
  const [live, setLive] = useState(false);
  const [loading, setLoading] = useState(Boolean(API_BASE));
  const [error, setError] = useState(false);

  useEffect(() => {
    if (!API_BASE) return;
    const controller = new AbortController();
    fetchLiveProduct(slug, controller.signal)
      .then((item) => {
        if (item) {
          setProduct(item);
          setLive(true);
        }
      })
      .catch((error: unknown) => {
        if (error instanceof DOMException && error.name === "AbortError") return;
        setProduct(undefined);
        setError(true);
      })
      .finally(() => setLoading(false));
    return () => controller.abort();
  }, [slug]);

  if (loading && !product) {
    return <ShopShell kicker="محصول" title="در حال دریافت اطلاعات…" description="اطلاعات محصول منتشرشده در حال بارگذاری است."><span /></ShopShell>;
  }
  if (!product) {
    return <ShopShell kicker="محصول پیدا نشد" title="این محصول در کاتالوگ موجود نیست." description="ممکن است محصول از فروش خارج شده باشد یا نشانی آن اشتباه باشد."><section className={styles.content}><a className={styles.primaryAction} href="/shop">بازگشت به فروشگاه</a></section></ShopShell>;
  }
  return <ProductPage product={product} live={live} />;
}

export function CartPage() {
  const { cart, ready, subtotal, shipping, tax, total, pricingReady, pricingLoading, refreshPricing, change, remove } = useCart();
  if (!ready) return <ShopShell kicker="سبد خرید" title="در حال بارگذاری سبد…" description="انتخاب‌های قبلی‌ات را بررسی می‌کنیم."><section className={styles.content} role="status">سبد خرید در حال بازیابی است…</section></ShopShell>;
  return <ShopShell kicker="انتخاب‌های تو" title="سبد خرید" description="قبل از ادامه، تعداد و جمع سبد را بررسی کن.">
    <section className={styles.cartLayout}>
      <div className={styles.cartPanel}>
        <h2>{cart.length ? `محصول‌ها (${toman(cart.reduce((n, line) => n + line.quantity, 0))})` : "سبد خرید خالی است"}</h2>
        {cart.length ? cart.map((line) => <article className={styles.cartLine} key={line.sku ?? line.id}>
          <a href={`/product/${line.id}`} className={`${styles.cartThumb} ${styles[line.accent]}`}><ProductArtwork product={line} /></a>
          <div><a href={`/product/${line.id}`}><h3>{line.title}</h3></a><p>{line.packageLabel}</p><button className={styles.remove} type="button" onClick={() => remove(line.sku ?? line.id)}>حذف از سبد</button></div>
          <strong className={styles.linePrice}>{toman(line.price * line.quantity)} تومان</strong>
          <div className={styles.quantity} aria-label={`تعداد ${line.title}`}><button type="button" onClick={() => change(line.sku ?? line.id, 1)} aria-label="افزایش تعداد">+</button><span>{toman(line.quantity)}</span><button type="button" onClick={() => change(line.sku ?? line.id, -1)} aria-label="کاهش تعداد">−</button></div>
        </article>) : <div className={styles.emptyCart}><span className={styles.cartIcon}>د</span><strong>یک چیز خوشمزه انتخاب کن.</strong><p>سبد خریدت فعلاً منتظر انتخاب‌های توست.</p><a href="/shop" className={styles.primaryAction}>رفتن به فروشگاه</a></div>}
      </div>
      <aside className={styles.summaryPanel}><h2>خلاصهٔ سفارش</h2><div className={styles.summaryRow}><span>جمع محصولات</span><strong>{toman(subtotal)} تومان</strong></div><div className={styles.summaryRow}><span>ارسال</span><strong>{pricingReady ? (shipping ? `${toman(shipping)} تومان` : "رایگان") : "در حال بررسی"}</strong></div>{pricingReady && <div className={styles.summaryRow}><span>مالیات</span><strong>{toman(tax)} تومان</strong></div>}<p className={styles.summaryNote}>روش ارسال و تخفیف را در مرحلهٔ بعد انتخاب کنید.</p>{!pricingReady && !pricingLoading && <button type="button" className={styles.secondaryAction} onClick={refreshPricing}>دریافت دوبارهٔ هزینهٔ ارسال</button>}<div className={`${styles.summaryRow} ${styles.summaryTotal}`}><span>برآورد سفارش</span><strong>{pricingReady ? `${toman(total)} تومان` : "در حال بررسی"}</strong></div><a className={styles.primaryAction} href={cart.length ? "/checkout" : "/shop"}>{cart.length ? "ادامه و ثبت اطلاعات" : "دیدن محصولات"}</a><a className={styles.secondaryAction} href="/shop">ادامهٔ خرید</a></aside>
    </section>
  </ShopShell>;
}

type CheckoutOrderResponse = {
  id: string;
  receiptToken: string;
  payable: number;
  tax: number;
  shipping: number;
  shippingMethod: string;
  state: string;
  reservationExpiresAt: string;
  subtotal?: number;
  discount?: number;
  lines?: ReceiptLine[];
};

type PaymentIntentResponse = { redirectUrl?: string | null; provider?: string; authority?: string };
function withOrderDetails(receipt: CheckoutReceipt, order: Partial<CheckoutOrderResponse>): CheckoutReceipt {
  return { ...receipt, payable: order.payable ?? receipt.payable, tax: order.tax ?? receipt.tax,
    shipping: order.shipping ?? receipt.shipping, subtotal: order.subtotal ?? receipt.subtotal,
    discount: order.discount ?? receipt.discount, shippingMethod: order.shippingMethod ?? receipt.shippingMethod,
    // Store only customer-facing line data, never cost snapshots or batch allocations.
    lines: order.lines?.map(({ productTitle, variantLabel, quantity, lineTotal, sku }) => ({ productTitle, variantLabel, quantity, lineTotal, sku })) ?? receipt.lines };
}

const checkoutIdempotencyStorageKey = "mazedooneh-checkout-key-v1";
const checkoutReceiptStorageKey = "mazedooneh-checkout-receipt-v1";

function getCheckoutIdempotencyKey(fingerprint: string) {
  const current = window.sessionStorage.getItem(checkoutIdempotencyStorageKey);
  if (current) {
    try {
      const saved = JSON.parse(current) as { fingerprint?: unknown; key?: unknown };
      if (saved.fingerprint === fingerprint && typeof saved.key === "string") return saved.key;
    } catch {
      window.sessionStorage.removeItem(checkoutIdempotencyStorageKey);
    }
  }
  const key = window.crypto.randomUUID();
  window.sessionStorage.setItem(checkoutIdempotencyStorageKey, JSON.stringify({ fingerprint, key }));
  return key;
}

function toAsciiDigits(value: string) {
  return value.replace(/[۰-۹]/g, (digit) => String("۰۱۲۳۴۵۶۷۸۹".indexOf(digit)))
    .replace(/[٠-٩]/g, (digit) => String("٠١٢٣٤٥٦٧٨٩".indexOf(digit)));
}

export function CheckoutPage() {
  const { cart, ready, subtotal, commerce, pricingReady, pricingLoading, refreshPricing, clear } = useCart();
  const [receipt, setReceipt] = useState<CheckoutReceipt | null>(null);
  const shippingMethods = useMemo(() => commerce?.shippingMethods.filter(item => item.isActive) ?? [], [commerce]);
  const [shippingMethod, setShippingMethod] = useState("post");
  const estimate = estimateCommerce(subtotal, commerce, shippingMethod);
  const [submitting, setSubmitting] = useState(false);
  const [revokingConsent, setRevokingConsent] = useState(false);
  const [downloadingInvoice, setDownloadingInvoice] = useState(false);
  const [consentRevoked, setConsentRevoked] = useState(false);
  const [error, setError] = useState("");
  const apiBaseUrl = API_BASE;
  const unsupportedLines = cart.filter((line) => !line.sku);
  const [couponCode, setCouponCode] = useState("");
  const [discountMobile, setDiscountMobile] = useState("");
  const [postalCode, setPostalCode] = useState("");
  const [discountCity, setDiscountCity] = useState("");
  const [couponBusy, setCouponBusy] = useState(false);
  const [couponError, setCouponError] = useState("");
  const [couponResult, setCouponResult] = useState<{ key: string; subtotal?: number; discount: number; shipping: number; tax: number; payable: number; code?: string; name?: string; automatic?: boolean } | null>(null);
  const couponKey = JSON.stringify({ code: couponCode.trim(), mobile: toAsciiDigits(discountMobile), city: discountCity, shippingMethod, lines: cart.map(line => ({sku: line.sku, quantity: line.quantity})) });
  const couponQuote = couponResult?.key === couponKey ? couponResult : null;
  useEffect(() => {
    if (!receipt?.orderId) return;
    document.getElementById("receipt-title")?.focus({ preventScroll: true });
    window.scrollTo({ top: 0, behavior: "instant" });
  }, [receipt?.orderId]);
  async function applyCoupon() {
    setCouponError(""); setCouponResult(null); setCouponBusy(true);
    const key = couponKey;
    try {
      const response = await fetch(`${apiBaseUrl}/api/v1/checkout/coupon-preview`, {method: "POST", headers: {"Content-Type": "application/json"}, body: couponKey, cache: "no-store"});
      const result = await response.json();
      if (!response.ok) throw new Error(result.message || result.title || "کد تخفیف تأیید نشد.");
      setCouponResult({...result, key});
    } catch(e) { setCouponError(e instanceof Error ? e.message : "ارتباط با سرویس تخفیف برقرار نشد."); }
    finally { setCouponBusy(false); }
  }

  useEffect(() => {
    if (!apiBaseUrl || couponCode.trim() || !cart.length || unsupportedLines.length) return;
    const controller = new AbortController();
    const timer = window.setTimeout(() => {
      fetch(`${apiBaseUrl}/api/v1/checkout/coupon-preview`, { method: "POST", headers: { "Content-Type": "application/json" }, body: couponKey, cache: "no-store", signal: controller.signal })
        .then(async response => { if (!response.ok) return; const result = await response.json(); if (!controller.signal.aborted) setCouponResult({ ...result, key: couponKey }); })
        .catch(() => { /* Final checkout still validates discounts on the server. */ });
    }, 500);
    return () => { window.clearTimeout(timer); controller.abort(); };
  }, [apiBaseUrl, couponKey, couponCode, cart.length, unsupportedLines.length]);

  function rememberReceipt(nextReceipt: CheckoutReceipt) {
    window.sessionStorage.setItem(checkoutReceiptStorageKey, JSON.stringify(nextReceipt));
  }

  async function completeSandbox(nextReceipt: CheckoutReceipt) {
    if (couponBusy) return;
    setCouponBusy(true); setError("");
    try {
      const response = await fetch(`${apiBaseUrl}/api/v1/payments/sandbox/${encodeURIComponent(nextReceipt.sandboxAuthority ?? "")}/complete`, {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ receiptToken: nextReceipt.receiptToken }), cache: "no-store",
      });
      if (!response.ok) throw new Error("تأیید پرداخت آزمایشی انجام نشد.");
      await refreshPaymentStatus(nextReceipt);
    } catch (paymentError) { setError(paymentError instanceof Error ? paymentError.message : "خطا در پرداخت آزمایشی"); }
    finally { setCouponBusy(false); }
  }

  async function beginPayment(nextReceipt: CheckoutReceipt) {
    const response = await fetch(`${apiBaseUrl}/api/v1/payments/orders/${nextReceipt.orderId}/intent`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ receiptToken: nextReceipt.receiptToken }),
      cache: "no-store",
    });
    const body = await response.json().catch(() => ({})) as PaymentIntentResponse & { message?: string; title?: string };
    if (response.ok && body.provider === "Sandbox" && body.authority) {
      const sandboxReceipt = { ...nextReceipt, sandboxAuthority: body.authority };
      rememberReceipt(sandboxReceipt);
      setReceipt(sandboxReceipt);
      window.history.replaceState(null, "", `?orderId=${encodeURIComponent(nextReceipt.orderId)}&payment=review`);
      return;
    }
    if (!response.ok || !body.redirectUrl) throw new Error(body.message || body.title || "اتصال به درگاه پرداخت هنوز آماده نیست.");
    rememberReceipt(nextReceipt);
    window.location.assign(body.redirectUrl);
  }

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const payment = params.get("payment");
    const orderId = params.get("orderId");
    if (!payment || !orderId) return;
    try {
      const saved = JSON.parse(window.sessionStorage.getItem(checkoutReceiptStorageKey) ?? "null") as CheckoutReceipt | null;
      if (saved?.orderId.toLowerCase() === orderId.toLowerCase()) {
        const returnedReceipt = { ...saved, paymentOutcome: payment === "failed" ? "failed" as const : payment === "success" ? "success" as const : "review" as const };
        setReceipt(returnedReceipt);
        if (payment === "success" || payment === "review") {
          setError(payment === "success" ? "پرداخت در حال تأیید نهایی است." : "در حال بررسی وضعیت پرداخت با سرویس زیبال…");
          fetch(`${apiBaseUrl}/api/v1/checkout/orders/${saved.orderId}`, {
            headers: { "X-Order-Receipt-Token": saved.receiptToken },
            cache: "no-store",
          })
            .then((response) => response.ok ? response.json() as Promise<CheckoutOrderResponse> : Promise.reject(new Error("order-status")))
            .then((order) => {
              const paid = paymentIsConfirmed(order.state);
              if (paid) clear();
              const verifiedReceipt = withOrderDetails({ ...returnedReceipt, state: order.state, paymentOutcome: paid ? "success" : "review" }, order);
              rememberReceipt(verifiedReceipt);
              setReceipt(verifiedReceipt);
              setError(paid ? "پرداخت با موفقیت تأیید شد." : order.state === "AwaitingPayment" ? "وضعیت پرداخت هنوز قطعی نیست. پیش از تلاش دوباره، وضعیت سفارش را بررسی کن." : "");
            }).catch(() => setError("وضعیت پرداخت هنوز از سرویس فروش دریافت نشده است. چند لحظه دیگر دوباره بررسی کن."));
        } else {
          setError("پرداخت تأیید نشد؛ می‌توانی دوباره تلاش کنی.");
        }
      }
    } catch {
      setError("نتیجهٔ پرداخت دریافت شد، اما اطلاعات سفارش در این دستگاه پیدا نشد. با پشتیبانی تماس بگیر.");
    }
  }, [apiBaseUrl, clear]);

  useEffect(() => {
    if (shippingMethods.length && !shippingMethods.some(item => item.code === shippingMethod)) {
      setShippingMethod(defaultShippingMethod(commerce)!.code);
    }
  }, [commerce, shippingMethods, shippingMethod]);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (submitting) return;
    setError("");
    if (!apiBaseUrl) {
      setError("ثبت آنلاین سفارش هنوز برای این سایت فعال نشده است.");
      return;
    }
    if (!pricingReady || !estimate) {
      setError("روش و هزینهٔ ارسال دریافت نشده است؛ دوباره تلاش کنید.");
      return;
    }
    if (unsupportedLines.length > 0) {
      setError(`این کالاها هنوز برای ثبت سفارش آنلاین آماده نیستند: ${unsupportedLines.map((line) => line.title).join("، ")}.`);
      return;
    }

    const data = new FormData(event.currentTarget);
    const name = String(data.get("name") ?? "مشتری");
    const payload = {
      customerName: name,
      mobile: toAsciiDigits(String(data.get("phone") ?? "")),
      province: String(data.get("province") ?? ""),
      city: String(data.get("city") ?? ""),
      address: String(data.get("address") ?? ""),
      postalCode: toAsciiDigits(String(data.get("postal") ?? "")),
      shippingMethod: String(data.get("shippingMethod") ?? shippingMethod),
      marketingConsent: data.get("marketingConsent") === "on",
      ...(couponCode.trim() ? { couponCode: couponCode.trim() } : {}),
      lines: cart.map((line) => ({ sku: line.sku!, quantity: line.quantity })),
    };

    setSubmitting(true);
    try {
      const response = await fetch(`${apiBaseUrl}/api/v1/checkout/orders`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Idempotency-Key": getCheckoutIdempotencyKey(JSON.stringify(payload)),
        },
        body: JSON.stringify(payload),
        cache: "no-store",
      });
      const body = await response.json().catch(() => ({})) as Partial<CheckoutOrderResponse> & { message?: string; title?: string; errors?: Record<string, string[]> };
      if (!response.ok) {
        const validationMessage = body.errors ? Object.values(body.errors).flat().join(" ") : "";
        throw new Error(body.message || body.title || validationMessage || "ثبت سفارش انجام نشد. سبد خرید را بررسی کن و دوباره تلاش کن.");
      }
      if (!body.id || typeof body.payable !== "number" || !body.reservationExpiresAt) {
        throw new Error("پاسخ سرویس سفارش کامل نبود؛ وضعیت سفارش را پیش از تلاش دوباره بررسی کن.");
      }
      const nextReceipt = withOrderDetails({ name, orderId: body.id, receiptToken: body.receiptToken ?? "", payable: body.payable, tax: body.tax ?? 0, shipping: body.shipping ?? 0, expiresAt: body.reservationExpiresAt, state: body.state ?? "AwaitingPayment" }, body);
      if (paymentIsConfirmed(nextReceipt.state)) {
        clear();
        window.history.replaceState(null, "", `?orderId=${encodeURIComponent(nextReceipt.orderId)}&payment=success`);
      }
      rememberReceipt(nextReceipt);
      setReceipt(nextReceipt);
      if (nextReceipt.state === "AwaitingPayment") await beginPayment(nextReceipt);
    } catch (submitError) {
      setError(submitError instanceof TypeError
        ? "ارتباط با سرویس سفارش برقرار نشد. نشانی سرویس یا دسترسی ارسال را بررسی کن و دوباره تلاش کن."
        : submitError instanceof Error ? submitError.message : "ارتباط با سرویس سفارش برقرار نشد. دوباره تلاش کن.");
    } finally {
      setSubmitting(false);
    }
  }

  async function downloadInvoice() {
    if (!receipt || !receipt.receiptToken || !apiBaseUrl) {
      setError("برای دانلود فاکتور، رسید سفارش در این دستگاه در دسترس نیست.");
      return;
    }

    setDownloadingInvoice(true);
    setError("");
    try {
      const response = await fetch(`${apiBaseUrl}/api/v1/checkout/orders/${receipt.orderId}/invoice`, {
        headers: { "X-Order-Receipt-Token": receipt.receiptToken },
        cache: "no-store",
      });
      if (!response.ok) {
        const body = await response.json().catch(() => ({})) as { message?: string };
        throw new Error(body.message || "دانلود فاکتور انجام نشد؛ دوباره تلاش کن.");
      }
      const downloadUrl = URL.createObjectURL(await response.blob());
      const link = document.createElement("a");
      link.href = downloadUrl;
      link.download = `mazeduneh-invoice-${receipt.orderId}.html`;
      document.body.appendChild(link);
      link.click();
      link.remove();
      window.setTimeout(() => URL.revokeObjectURL(downloadUrl), 1000);
    } catch (downloadError) {
      setError(downloadError instanceof Error ? downloadError.message : "دانلود فاکتور انجام نشد؛ دوباره تلاش کن.");
    } finally {
      setDownloadingInvoice(false);
    }
  }

  async function revokeMarketingConsent() {
    if (!receipt || !receipt.receiptToken || !apiBaseUrl) {
      setError("برای لغو رضایت، رسید سفارش در این دستگاه در دسترس نیست.");
      return;
    }

    setRevokingConsent(true);
    setError("");
    try {
      const response = await fetch(
        `${apiBaseUrl}/api/v1/checkout/orders/${receipt.orderId}/marketing-consent/revoke`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ receiptToken: receipt.receiptToken }),
          cache: "no-store",
        },
      );
      const body = await response.json().catch(() => ({})) as { message?: string };
      if (!response.ok) throw new Error(body.message || "لغو پیامک‌های بازاریابی انجام نشد.");
      setConsentRevoked(true);
      setError("رضایت دریافت پیامک‌های بازاریابی لغو شد.");
    } catch (revokeError) {
      setError(revokeError instanceof Error ? revokeError.message : "لغو رضایت انجام نشد؛ دوباره تلاش کن.");
    } finally {
      setRevokingConsent(false);
    }
  }

  async function refreshPaymentStatus(nextReceipt: CheckoutReceipt) {
    setError("در حال بررسی وضعیت پرداخت…");
    try {
      const response = await fetch(`${apiBaseUrl}/api/v1/checkout/orders/${nextReceipt.orderId}`, {
        headers: { "X-Order-Receipt-Token": nextReceipt.receiptToken },
        cache: "no-store",
      });
      if (!response.ok) throw new Error("order-status");
      const order = await response.json() as CheckoutOrderResponse;
      const paid = paymentIsConfirmed(order.state);
      const refreshedReceipt = withOrderDetails({ ...nextReceipt, state: order.state, paymentOutcome: paid ? "success" : "review" }, order);
      if (paid) clear();
      rememberReceipt(refreshedReceipt);
      setReceipt(refreshedReceipt);
      if (nextReceipt.sandboxAuthority) window.history.replaceState(null, "", `?orderId=${encodeURIComponent(nextReceipt.orderId)}&payment=${paid ? "success" : "review"}`);
      setError(paid ? "پرداخت با موفقیت تأیید شد." : order.state === "AwaitingPayment" ? "وضعیت پرداخت هنوز قطعی نیست؛ چند لحظه دیگر دوباره بررسی کن." : "");
    } catch {
      setError("وضعیت پرداخت از سرویس فروش دریافت نشد؛ چند لحظه دیگر دوباره بررسی کن.");
    }
  }

  async function retryPayment() {
    if (!receipt || submitting) return;
    setSubmitting(true);
    setError("");
    try { await beginPayment(receipt); }
    catch (paymentError) { setError(paymentError instanceof Error ? paymentError.message : "شروع دوبارهٔ پرداخت انجام نشد."); }
    finally { setSubmitting(false); }
  }

  if (receipt) return <main className={styles.page}><StoreHeader /><section className={styles.content}>
    <CheckoutReceiptView receipt={receipt} message={error} paying={couponBusy || submitting}
      downloading={downloadingInvoice} revoking={revokingConsent} consentRevoked={consentRevoked}
      onPay={retryPayment} onRefresh={() => refreshPaymentStatus(receipt)} onSandbox={() => completeSandbox(receipt)}
      onDownload={downloadInvoice} onRevokeConsent={revokeMarketingConsent} />
  </section><StoreFooter /></main>;
  if (!ready) return <ShopShell kicker="تکمیل سفارش" title="در حال بارگذاری سبد…" description="پیش از ثبت سفارش، سبد ذخیره‌شده را بازیابی می‌کنیم."><section className={styles.content} role="status">سبد خرید در حال بازیابی است…</section></ShopShell>;
  if (!cart.length) return <ShopShell kicker="تکمیل سفارش" title="سبد خرید خالی است" description="برای شروع، محصولی از فروشگاه انتخاب کن."><section className={styles.content}><a className={styles.primaryAction} href="/shop">رفتن به فروشگاه</a></section></ShopShell>;
  return <main className={styles.page}><StoreHeader />
    <div className={styles.pageHero}><span>یک قدم تا خوشمزگی</span><h1>اطلاعات تحویل سفارش</h1><p>نشانی را وارد کن؛ سرویس سفارش قیمت و موجودی نهایی را بررسی می‌کند.</p></div>
    <div className={styles.checkoutSteps}><b>۱. اطلاعات تحویل</b><i /> <span>۲. مرور سفارش</span><i /> <span>۳. پرداخت</span></div>
    <section className={styles.checkoutLayout}>
      <form className={styles.checkoutForm} onSubmit={submit}>
        <h2>گیرنده و نشانی</h2><p>اطلاعات تحویل فقط برای ثبت سفارش به سرویس فروش ارسال می‌شود.</p>
        <div className={styles.fieldGrid}>
          <div className={styles.field}><label htmlFor="name">نام و نام خانوادگی</label><input id="name" name="name" autoComplete="name" required placeholder="نام گیرنده" /></div>
          <div className={styles.field}><label htmlFor="phone">شماره موبایل</label><input id="phone" name="phone" value={discountMobile} onChange={e => setDiscountMobile(toPersianDigits(e.target.value))} autoComplete="tel" inputMode="tel" pattern="[0۰٠][9۹٩][0-9۰-۹٠-٩]{9}" required placeholder="۰۹۱۲۱۲۳۴۵۶۷" /></div>
          <div className={styles.field}><label htmlFor="province">استان</label><select id="province" name="province" required defaultValue=""><option value="" disabled>انتخاب استان</option><option>تهران</option><option>اصفهان</option><option>خراسان رضوی</option><option>فارس</option></select></div>
          <div className={styles.field}><label htmlFor="city">شهر</label><input id="city" name="city" value={discountCity} onChange={e => setDiscountCity(e.target.value)} autoComplete="address-level2" required placeholder="شهر" /></div>
          <div className={`${styles.field} ${styles.fieldWide}`}><label htmlFor="address">نشانی کامل</label><textarea id="address" name="address" autoComplete="street-address" required placeholder="خیابان، کوچه، پلاک و واحد" /></div>
          <div className={styles.field}><label htmlFor="shippingMethod">روش ارسال</label><select id="shippingMethod" name="shippingMethod" value={shippingMethod} onChange={(event) => setShippingMethod(event.target.value)} required>{shippingMethods.length ? shippingMethods.map((item) => { const quote = estimateCommerce(subtotal, commerce, item.code); return <option key={item.code} value={item.code}>{item.title} · {quote?.shipping ? `${toman(quote.shipping)} تومان` : "رایگان"}</option>; }) : <option value="">{pricingLoading ? "در حال دریافت روش‌های ارسال…" : "روش ارسال در دسترس نیست"}</option>}</select></div>
          <div className={styles.field}><label htmlFor="postal">کد پستی</label><input id="postal" name="postal" value={postalCode} onChange={e => setPostalCode(toPersianDigits(e.target.value))} inputMode="numeric" autoComplete="postal-code" pattern="[0-9۰-۹٠-٩]{10}" required placeholder="۱۰ رقم" /></div>
        </div>
        <label className={`${styles.deliveryOption} ${styles.fieldWide}`}>
          <input id="marketingConsent" name="marketingConsent" type="checkbox" />
          <span><b>دریافت پیامک‌های معرفی و تخفیف</b>این انتخاب اختیاری است و ثبت یا هزینهٔ سفارش را تغییر نمی‌دهد.</span>
        </label>
        {!pricingReady && !pricingLoading && <p role="alert">روش‌های ارسال دریافت نشد یا فعلاً فعال نیست. <button type="button" className={styles.secondaryAction} onClick={refreshPricing}>تلاش دوباره</button></p>}
        {error && <p role="alert" className={styles.paymentInfo}>{error}</p>}
        {unsupportedLines.length > 0 && <p className={styles.summaryNote}>برای ثبت آنلاین، فعلاً این کالاها را از سبد بردار: {unsupportedLines.map((line) => line.title).join("، ")}.</p>}
        {!apiBaseUrl && <p className={styles.summaryNote}>ثبت سفارش آنلاین هنوز برای این سایت فعال نشده است.</p>}
        <button className={styles.primaryAction} type="submit" disabled={submitting || !apiBaseUrl || unsupportedLines.length > 0 || !pricingReady || !estimate}>{submitting ? "در حال ثبت سفارش…" : "ثبت سفارش و بررسی مبلغ نهایی"}</button>
      </form>
      <aside className={styles.checkoutSummary}><h2>مرور سفارش</h2>
        <div className={styles.field}><label htmlFor="couponCode">کد تخفیف</label><input id="couponCode" value={couponCode} maxLength={40} dir="ltr" autoComplete="off" placeholder="WELCOME10" onChange={e => {setCouponCode(e.target.value); setCouponError("");}} />
          <button type="button" className={styles.secondaryAction} disabled={couponBusy || !apiBaseUrl || unsupportedLines.length > 0} onClick={applyCoupon}>{couponBusy ? "در حال بررسی…" : (couponCode.trim() ? "بررسی کد تخفیف" : "بررسی تخفیف‌ها")}</button>
          {couponError && <p role="alert">{couponError}</p>}
          {couponQuote?.name && <p role="status">{couponQuote.name}؛ هنگام ثبت سفارش دوباره بررسی می‌شود.</p>}
        </div>{cart.map((line) => <div className={styles.summaryProduct} key={line.sku ?? line.id}><span>{line.title}، {line.packageLabel} × {toman(line.quantity)}</span><b>{toman(line.price * line.quantity)} تومان</b></div>)}<div className={styles.summaryRow}><span>جمع محصولات</span><strong>{couponQuote?.subtotal != null ? formatRialsAsTomans(couponQuote.subtotal) : toman(subtotal)} تومان</strong></div><div className={styles.summaryRow}><span>ارسال</span><strong>{couponQuote ? `${formatRialsAsTomans(couponQuote.shipping)} تومان` : estimate && pricingReady ? (estimate.shipping ? `${toman(estimate.shipping)} تومان` : "رایگان") : "در حال بررسی"}</strong></div>
        {couponQuote && <div className={styles.summaryRow}><span>تخفیف</span><strong>{formatRialsAsTomans(couponQuote.discount)} تومان</strong></div>}{(couponQuote || (estimate && pricingReady)) && <div className={styles.summaryRow}><span>مالیات</span><strong>{couponQuote ? formatRialsAsTomans(couponQuote.tax) : toman(estimate!.tax)} تومان</strong></div>}
        <div className={`${styles.summaryRow} ${styles.summaryTotal}`}><span>{couponQuote ? "مبلغ تأییدشدهٔ سبد" : "برآورد اولیه"}</span><strong>{couponQuote ? `${formatRialsAsTomans(couponQuote.payable)} تومان` : estimate && pricingReady ? `${toman(estimate.total)} تومان` : "در حال بررسی"}</strong></div></aside>
    </section><StoreFooter />
  </main>;
}

export function InfoPage({ page }: { page: "about" | "shipping" | "returns" | "faq" | "contact" | "profile" | "privacy" | "terms" }) {
  const { commerce, pricingReady, refreshPricing } = useCart();
  if (page === "profile") return <GuestOrders />;
  const content = {
    about: { kicker: "داستان مزه‌دونه", title: "مزه‌های کوچک، با حوصله انتخاب می‌شوند.", intro: "مزه‌دونه برای انتخاب‌های روزمره ساخته شده؛ از یک مشت آجیل تا کوکی کنار چای.", facts: [["انتخاب روشن", "وزن، ترکیبات و اطلاعات هر بسته را پیش از انتخاب در صفحهٔ محصول ببینید."], ["بستهٔ مناسب شما", "وزن‌ها و تعدادهای مختلف یک محصول در همان صفحه کنار هم قرار دارند."], ["خرید ساده", "بدون ساخت حساب خرید کنید و رسید و وضعیت سفارش را در همان مرورگر ببینید."]] },
    shipping: { kicker: "تحویل سفارش", title: "روش و هزینهٔ ارسال", intro: "روش ارسال را در مرحلهٔ تکمیل سفارش انتخاب کنید؛ مبلغ همان‌جا بر اساس تنظیمات فروشگاه مشخص می‌شود.", facts: [["مبلغ روشن", "هزینهٔ ارسال، تخفیف و مالیات پیش از پرداخت جداگانه نمایش داده می‌شوند."], ["آماده‌سازی و تحویل", "پس از تأیید پرداخت، سفارش آماده می‌شود و وضعیت آن در رسید خرید به‌روز خواهد شد."], ["پیگیری", "برای هماهنگی تحویل یا پیگیری بسته، شمارهٔ سفارش را در بله یا تلگرام بفرستید."]] },
    returns: { kicker: "ضمانت کیفیت", title: "بازگشت و رسیدگی به سفارش", intro: "اگر کالا فاسد، منقضی یا با مشخصات و تاریخ‌های اعلام‌شده مغایر بود، برای بررسی و تعویض یا بازپرداخت به ما پیام بدهید.", facts: [["گزارش مشکل", "در اولین فرصت شمارهٔ سفارش و عکس واضح کالا، تاریخ‌ها و بسته‌بندی را در بله یا تلگرام بفرستید و تا پایان بررسی، کالا و بسته‌بندی را نگه دارید."], ["رسیدگی و بازگشت", "پیش از ارسال کالا با ما هماهنگ کنید. در صورت تأیید ایراد، تعویض یا بازپرداخت انجام می‌شود و هزینهٔ بازگشت بر عهدهٔ مزه‌دونه است."], ["شرایط نگهداری", "آسیب ناشی از استفاده یا نگهداری نامناسب پس از تحویل، پس از بررسی مشمول این ضمانت نیست. این ضمانت، حقوق قانونی خریدار را محدود نمی‌کند."]] },
    faq: { kicker: "پاسخ‌های کوتاه", title: "پرسش‌های پرتکرار", intro: "راهنمای انتخاب محصول، خرید و پیگیری سفارش.", facts: [] },
    contact: { kicker: "کنارتان هستیم", title: "تماس با مزه‌دونه", intro: "برای پرسش دربارهٔ محصول، پیگیری سفارش یا درخواست مرجوعی، از راه‌های ارتباطی زیر استفاده کنید.", facts: [["پیگیری سفارش", "شمارهٔ سفارش و موضوع درخواست را بنویسید تا بتوانیم دقیق‌تر بررسی کنیم."], ["هدیه و سفارش سازمانی", "برای تعداد بالا، ترکیب دلخواه یا بسته‌بندی اختصاصی، از صفحهٔ فروش سازمانی درخواست بفرستید."]] },
    privacy: { kicker: "اطلاعات شما", title: "حریم خصوصی خرید", intro: "اطلاعات تحویل برای ثبت، ارسال و پیگیری سفارش استفاده می‌شود.", facts: [["اطلاعات موردنیاز", "نام، شمارهٔ همراه، نشانی و کد پستی برای تحویل و پیگیری سفارش دریافت می‌شوند. اطلاعات کارت بانکی در فروشگاه نگهداری نمی‌شود؛ پرداخت در صفحهٔ ارائه‌دهندهٔ درگاه انجام می‌شود."], ["مرورگر و پیام‌رسان‌ها", "سبد و علاقه‌مندی‌ها در مرورگر ذخیره می‌شوند و رسید مهمان به نشست همان مرورگر وابسته است. با بازکردن پیوند بله یا تلگرام وارد سرویس همان پیام‌رسان می‌شوید."], ["انتخاب و پیگیری شما", "دریافت پیامک معرفی و تخفیف اختیاری است و از رسید سفارش قابل لغو است. برای پرسش دربارهٔ اطلاعات یا درخواست اصلاح آن، در پیام‌رسان‌ها تماس بگیرید؛ پیش از تغییر، ارتباط درخواست‌کننده با سفارش بررسی می‌شود."]] },
    terms: { kicker: "راهنمای خرید", title: "شرایط ثبت و پیگیری سفارش", intro: "مشخصات کالا، روش ارسال و جمع نهایی را پیش از پرداخت بررسی کنید.", facts: [["قیمت و موجودی", "قیمت‌ها به تومان نمایش داده می‌شوند. مبلغ نهایی، مالیات، ارسال و تخفیف در سرویس فروشگاه بررسی و در رسید ثبت می‌شوند؛ پیش‌نمایش سبد رزرو کالا نیست."], ["ثبت و پرداخت", "ثبت سفارش به‌تنهایی به معنی پرداخت نیست. سفارش پرداخت‌نشده تا مهلت درج‌شده در رسید رزرو می‌ماند. نتیجهٔ نهایی پرداخت از درگاه و سرور فروشگاه تأیید می‌شود."], ["تحویل و رسیدگی", "اطلاعات تحویل را دقیق بنویسید. وضعیت سفارش در رسید قابل پیگیری است و درخواست مغایرت یا مرجوعی طبق صفحهٔ بازگشت و رسیدگی بررسی می‌شود."]] },
  }[page];
  return <ShopShell kicker={content.kicker} title={content.title} description={content.intro}>
    <section className={styles.content}>
      {page === "faq" ? <div className={styles.faqList}>
        <details className={styles.faqItem}><summary>برای خرید باید حساب بسازم؟</summary><p>خیر. محصول و بستهٔ دلخواه را انتخاب کنید، اطلاعات تحویل را بنویسید و مبلغ نهایی را پیش از پرداخت ببینید.</p></details>
        <details className={styles.faqItem}><summary>چطور وزن و ترکیبات را ببینم؟</summary><p>در صفحهٔ محصول، وزن یا تعداد بسته را انتخاب کنید؛ قیمت همان لحظه تغییر می‌کند. ترکیبات و شرایط نگهداری ثبت‌شده هم در همان صفحه قرار دارند.</p></details>
        <details className={styles.faqItem}><summary>هزینهٔ ارسال و تخفیف کجا مشخص می‌شود؟</summary><p>در مرحلهٔ تکمیل سفارش، روش ارسال را انتخاب کنید و در صورت داشتن کد، آن را وارد کنید. هزینهٔ ارسال، تخفیف، مالیات و جمع نهایی جدا نمایش داده می‌شوند.</p></details>
        <details className={styles.faqItem}><summary>چطور سفارش را پیگیری کنم؟</summary><p>رسید سفارش را در همان مرورگری که خرید کرده‌اید باز کنید. اگر به رسید دسترسی ندارید، از بخش «تماس با ما» در بله یا تلگرام پیام بدهید و شمارهٔ سفارش را بنویسید.</p></details>
      </div> : <div className={styles.infoGrid}>{content.facts.map(([title, text]) => <article className={styles.infoCard} key={title}><strong>{title}</strong><p>{text}</p></article>)}</div>}
      {page === "shipping" && <div className={styles.storyBlock}><h2>روش‌های فعال فروشگاه</h2>{pricingReady ? commerce?.shippingMethods.filter(method => method.isActive).map(method => <p key={method.code}><strong>{method.title}</strong>؛ {method.price ? `${formatRialsAsTomans(method.price)} تومان` : "رایگان"}{method.freeAbove > 0 ? `؛ رایگان از ${formatRialsAsTomans(method.freeAbove)} تومان` : ""}</p>) : <p>روش‌های ارسال فعلاً دریافت نشد. <button type="button" className={styles.secondaryAction} onClick={refreshPricing}>تلاش دوباره</button></p>}</div>}
      {page === "contact" && <div className={styles.storyBlock}><h2>شمارهٔ تماس</h2><a className={styles.secondaryAction} href="tel:+9893339870210" dir="ltr" aria-label="تماس تلفنی با مزه‌دونه">۰۹۳۳۹۸۷۰۲۱۰</a></div>}
      {(page === "contact" || page === "returns" || page === "privacy") && <div className={styles.storyBlock}><h2>پیام بدهید، پیگیری می‌کنیم</h2><SocialSupport /></div>}
      {page === "contact" && <a className={styles.secondaryAction} href="/corporate-sales">درخواست هدیه و خرید سازمانی</a>}
    </section>
  </ShopShell>;
}
