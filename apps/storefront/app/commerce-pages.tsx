"use client";

import { useEffect, useMemo, useState } from "react";
import type { FormEvent } from "react";
import { demoProducts, categories, toman, type DemoProduct } from "./demo/catalog";
import { ProductArtwork } from "./demo/ProductArtwork";
import { useCart } from "./cart-context";
import { ProductCard, RelatedProducts, ShopShell, StoreFooter, StoreHeader } from "./store-chrome";
import styles from "./store-pages.module.css";

export function CatalogPage() {
  const [category, setCategory] = useState("همه");
  const [query, setQuery] = useState("");
  const [sort, setSort] = useState("popular");
  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    setQuery(params.get("q") ?? "");
    setCategory(params.get("category") ?? "همه");
  }, []);
  const products = useMemo(() => {
    const normalized = query.trim().toLocaleLowerCase();
    const filtered = demoProducts.filter((product) =>
      (category === "همه" || product.category === category)
      && (!normalized || `${product.title} ${product.subtitle} ${product.category} ${product.origin}`.toLocaleLowerCase().includes(normalized)),
    );
    return filtered.sort((a, b) => sort === "price-asc" ? a.price - b.price : sort === "price-desc" ? b.price - a.price : demoProducts.indexOf(a) - demoProducts.indexOf(b));
  }, [category, query, sort]);

  return <ShopShell kicker="از قفسهٔ مزه‌دونه" title="هر روز، یک مزهٔ خوب" description="محصول‌ها را ببین، دسته‌بندی کن و جزئیات هر بسته را پیش از انتخاب بخوان.">
    <section className={styles.content}>
      <div className={styles.toolbar}>
        <div className={styles.categoryList} aria-label="فیلتر دسته‌بندی">
          {categories.map((item) => <button key={item} type="button" aria-pressed={category === item} onClick={() => setCategory(item)}>{item}</button>)}
        </div>
        <label className={styles.sortSelect}>مرتب‌سازی <select aria-label="مرتب‌سازی محصولات" value={sort} onChange={(event) => setSort(event.target.value)}><option value="popular">پیشنهادی</option><option value="price-asc">ارزان‌ترین</option><option value="price-desc">گران‌ترین</option></select></label>
      </div>
      <p className={styles.resultCount}>{toman(products.length)} محصول {query ? `برای «${query}»` : "در این فهرست"}</p>
      {products.length ? <div className={styles.productGrid}>{products.map((product) => <ProductCard key={product.id} product={product} />)}</div> : <div className={styles.emptyState}>محصولی با این جست‌وجو پیدا نشد. <a href="/shop">همهٔ محصولات را ببین</a></div>}
    </section>
  </ShopShell>;
}

const productFacts = [
  ["مبدأ", "روی بستهٔ محصول درج می‌شود"],
  ["ترکیبات و حساسیت‌زاها", "پیش از فروش هر محصول تأیید می‌شود"],
  ["شرایط نگهداری", "در جای خشک و خنک، دور از نور مستقیم"],
  ["بسته‌بندی", "بسته‌بندی مناسب نگهداری خوراکی"],
];

export function ProductPage({ product }: { product: DemoProduct }) {
  const { add } = useCart();
  const [reviews, setReviews] = useState<{ name: string; rating: string; text: string }[]>([]);
  function addReview(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const data = new FormData(event.currentTarget);
    setReviews((current) => [{
      name: String(data.get("reviewer") ?? "خریدار"),
      rating: String(data.get("rating") ?? "۵"),
      text: String(data.get("review") ?? ""),
    }, ...current]);
    event.currentTarget.reset();
  }
  return <main className={styles.page}>
    <StoreHeader />
    <div className={styles.detailLayout}>
      <div className={`${styles.detailVisual} ${styles[product.accent]}`}><ProductArtwork product={product} hero /></div>
      <div className={styles.detailInfo}>
        <div className={styles.breadcrumbs}><a href="/">خانه</a> ← <a href="/shop">فروشگاه</a> ← <a href={`/shop?category=${encodeURIComponent(product.category)}`}>{product.category}</a></div>
        <span className={styles.detailKicker}>{product.badge ?? "انتخاب مزه‌دونه"}</span>
        <h1>{product.title}</h1>
        <p className={styles.detailSubtitle}>{product.subtitle}</p>
        <div className={styles.rating} aria-label="بدون امتیاز ثبت‌شده">☆☆☆☆☆ <span>هنوز امتیاز تأییدشده‌ای ثبت نشده</span></div>
        <div className={styles.detailPrice}>{toman(product.price)} <small>تومان</small></div>
        <p className={styles.variantTitle}>بستهٔ قابل انتخاب</p>
        <span className={styles.variantChoice}>{product.packageLabel} <span aria-hidden="true">✓</span></span>
        <div className={styles.detailBuy}><button type="button" onClick={() => add(product)}>افزودن به سبد خرید</button><a href="/cart">رفتن به سبد</a></div>
        <div className={styles.facts}>{productFacts.map(([label, value]) => <div className={styles.fact} key={label}><small>{label}</small><b>{label === "مبدأ" ? product.origin : value}</b></div>)}</div>
        <div className={styles.detailNotice}>اطلاعات و قیمت‌های این نسخه نمونه‌اند. مشخصات قطعی ترکیبات، حساسیت‌زاها و وزن باید پیش از فروش از پنل محصول تأیید شوند.</div>
      </div>
    </div>
    <section className={styles.detailTabs}>
      <h2>دربارهٔ این محصول</h2><p>{product.subtitle} · {product.note}. برای خرید واقعی باید اطلاعات کامل ترکیبات، وزن خالص، تاریخ تولید و شرایط نگهداری روی همین صفحه و بسته‌بندی نمایش داده شود.</p>
      <div className={styles.reviewHeading}><h2>دیدگاه خریداران</h2><span>{toman(reviews.length)} دیدگاه این نشست</span></div>
      {reviews.length ? <div className={styles.reviewList}>{reviews.map((review, index) => <article className={styles.reviewCard} key={`${review.name}-${index}`}><div><strong>{review.name}</strong><span>{"★".repeat(Number(review.rating))}{"☆".repeat(5 - Number(review.rating))}</span></div><p>{review.text}</p><small>پیش‌نمایش محلی · برای دیگران ذخیره نمی‌شود</small></article>)}</div> : <div className={styles.reviewEmpty}>هنوز دیدگاه تأییدشده‌ای ثبت نشده است. دیدگاهی که اینجا بنویسی فقط در همین نشست دیده می‌شود.</div>}
      <form className={styles.reviewForm} onSubmit={addReview}>
        <h3>تجربه‌ات را بنویس</h3>
        <p>برای انتشار عمومی، اتصال حساب خریدار و تأیید سفارش لازم است.</p>
        <div className={styles.reviewFields}>
          <label>نام نمایشی<input name="reviewer" required maxLength={60} placeholder="مثلاً سارا" /></label>
          <label>امتیاز<select name="rating" defaultValue="5"><option value="5">۵ · عالی</option><option value="4">۴ · خوب</option><option value="3">۳ · معمولی</option><option value="2">۲ · ضعیف</option><option value="1">۱ · خیلی ضعیف</option></select></label>
          <label className={styles.reviewText}>دیدگاه<textarea name="review" required minLength={4} maxLength={600} placeholder="از طعم، بسته‌بندی یا تجربه‌ات بگو…" /></label>
        </div>
        <button className={styles.primaryAction} type="submit">ثبت دیدگاه در پیش‌نمایش</button>
      </form>
    </section>
    <RelatedProducts currentId={product.id} />
    <StoreFooter />
  </main>;
}

export function CartPage() {
  const { cart, subtotal, shipping, total, change, remove } = useCart();
  return <ShopShell kicker="انتخاب‌های تو" title="سبد خرید" description="قبل از ادامه، تعداد و جمع سبد را بررسی کن.">
    <section className={styles.cartLayout}>
      <div className={styles.cartPanel}>
        <h2>{cart.length ? `محصول‌ها (${toman(cart.reduce((n, line) => n + line.quantity, 0))})` : "سبد خرید خالی است"}</h2>
        {cart.length ? cart.map((line) => <article className={styles.cartLine} key={line.id}>
          <a href={`/product/${line.id}`} className={`${styles.cartThumb} ${styles[line.accent]}`}><ProductArtwork product={line} /></a>
          <div><a href={`/product/${line.id}`}><h3>{line.title}</h3></a><p>{line.packageLabel}</p><button className={styles.remove} type="button" onClick={() => remove(line.id)}>حذف از سبد</button></div>
          <strong className={styles.linePrice}>{toman(line.price * line.quantity)} تومان</strong>
          <div className={styles.quantity} aria-label={`تعداد ${line.title}`}><button type="button" onClick={() => change(line.id, 1)} aria-label="افزایش تعداد">+</button><span>{toman(line.quantity)}</span><button type="button" onClick={() => change(line.id, -1)} aria-label="کاهش تعداد">−</button></div>
        </article>) : <div className={styles.emptyCart}><span className={styles.cartIcon}>د</span><strong>یک چیز خوشمزه انتخاب کن.</strong><p>سبد خریدت فعلاً منتظر انتخاب‌های توست.</p><a href="/shop" className={styles.primaryAction}>رفتن به فروشگاه</a></div>}
      </div>
      <aside className={styles.summaryPanel}><h2>خلاصهٔ سفارش</h2><div className={styles.summaryRow}><span>جمع محصولات</span><strong>{toman(subtotal)} تومان</strong></div><div className={styles.summaryRow}><span>ارسال</span><strong>{shipping ? `${toman(shipping)} تومان` : "رایگان"}</strong></div><p className={styles.summaryNote}>هزینه و روش ارسال در این نسخه نمونه است و باید هنگام تسویه از سرویس فروش تأیید شود.</p><div className={`${styles.summaryRow} ${styles.summaryTotal}`}><span>مبلغ فعلی</span><strong>{toman(total)} تومان</strong></div><a className={styles.primaryAction} href={cart.length ? "/checkout" : "/shop"}>{cart.length ? "ادامه و ثبت اطلاعات" : "دیدن محصولات"}</a><a className={styles.secondaryAction} href="/shop">ادامهٔ خرید</a></aside>
    </section>
  </ShopShell>;
}

type CheckoutOrderResponse = {
  id: string;
  payable: number;
  state: string;
  reservationExpiresAt: string;
};

const apiSkusByProductId: Record<string, string> = {
  "pistachio-akbari": "PI-AKB-500",
  "pistachio-ahmad": "PI-AHM-500",
  almond: "NU-ALM-500",
  walnut: "NU-WAL-500",
  "pumpkin-seeds": "SE-PUM-500",
  "protein-cookie": "CK-PRO-4",
};

const checkoutStateLabels: Record<string, string> = {
  AwaitingPayment: "در انتظار پرداخت",
  Paid: "پرداخت تأییدشده",
  Preparing: "در حال آماده‌سازی",
  Shipped: "ارسال‌شده",
  Delivered: "تحویل‌شده",
  Cancelled: "لغوشده",
  Expired: "مهلت پرداخت پایان‌یافته",
};

const checkoutIdempotencyStorageKey = "mazedooneh-checkout-key-v1";

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
  return value.replace(/[۰-۹]/g, (digit) => String("۰۱۲۳۴۵۶۷۸۹".indexOf(digit)));
}

export function CheckoutPage() {
  const { cart, subtotal, shipping, total } = useCart();
  const [receipt, setReceipt] = useState<{ name: string; orderId: string; payable: number; expiresAt: string; state: string } | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");
  const apiBaseUrl = process.env.NEXT_PUBLIC_MAZEDUNEH_API_URL?.trim().replace(/\/+$/, "") ?? "";
  const unsupportedLines = cart.filter((line) => !apiSkusByProductId[line.id]);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    if (!apiBaseUrl) {
      setError("ثبت آنلاین سفارش هنوز برای این سایت فعال نشده است.");
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
      lines: cart.map((line) => ({ sku: apiSkusByProductId[line.id], quantity: line.quantity })),
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
      setReceipt({ name, orderId: body.id, payable: body.payable, expiresAt: body.reservationExpiresAt, state: body.state ?? "AwaitingPayment" });
    } catch (submitError) {
      setError(submitError instanceof TypeError
        ? "ارتباط با سرویس سفارش برقرار نشد. نشانی سرویس یا دسترسی ارسال را بررسی کن و دوباره تلاش کن."
        : submitError instanceof Error ? submitError.message : "ارتباط با سرویس سفارش برقرار نشد. دوباره تلاش کن.");
    } finally {
      setSubmitting(false);
    }
  }

  if (receipt) return <main className={styles.page}><StoreHeader /><section className={styles.content}><div className={styles.pageHero}><span>{checkoutStateLabels[receipt.state] ?? "وضعیت سفارش"}</span><h1>{receipt.state === "Paid" ? `ممنون ${receipt.name}، پرداخت سفارش تأیید شد.` : `ممنون ${receipt.name}، سفارش ثبت شد.`}</h1><p>شناسهٔ سفارش: {receipt.orderId}</p><p>مبلغ تأییدشدهٔ سرور: {toman(Math.round(receipt.payable / 10))} تومان</p>{receipt.state === "AwaitingPayment" && <p>رزرو کالا تا {new Intl.DateTimeFormat("fa-IR", { dateStyle: "short", timeStyle: "short" }).format(new Date(receipt.expiresAt))} اعتبار دارد. پرداخت هنوز انجام نشده است و خرید تا تأیید درگاه کامل نمی‌شود.</p>}<a className={styles.primaryAction} href="/shop">بازگشت به فروشگاه</a></div></section><StoreFooter /></main>;
  if (!cart.length) return <ShopShell kicker="تکمیل سفارش" title="سبد خرید خالی است" description="برای شروع، محصولی از فروشگاه انتخاب کن."><section className={styles.content}><a className={styles.primaryAction} href="/shop">رفتن به فروشگاه</a></section></ShopShell>;
  return <main className={styles.page}><StoreHeader />
    <div className={styles.pageHero}><span>یک قدم تا خوشمزگی</span><h1>اطلاعات تحویل سفارش</h1><p>نشانی را وارد کن؛ سرویس سفارش قیمت و موجودی نهایی را بررسی می‌کند.</p></div>
    <div className={styles.checkoutSteps}><b>۱. اطلاعات تحویل</b><i /> <span>۲. مرور سفارش</span><i /> <span>۳. پرداخت</span></div>
    <section className={styles.checkoutLayout}>
      <form className={styles.checkoutForm} onSubmit={submit}>
        <h2>گیرنده و نشانی</h2><p>اطلاعات تحویل فقط برای ثبت سفارش به سرویس فروش ارسال می‌شود.</p>
        <div className={styles.fieldGrid}>
          <div className={styles.field}><label htmlFor="name">نام و نام خانوادگی</label><input id="name" name="name" autoComplete="name" required placeholder="نام گیرنده" /></div>
          <div className={styles.field}><label htmlFor="phone">شماره موبایل</label><input id="phone" name="phone" autoComplete="tel" inputMode="tel" pattern="09[0-9۰-۹]{9}" required placeholder="۰۹۱۲۱۲۳۴۵۶۷" /></div>
          <div className={styles.field}><label htmlFor="province">استان</label><select id="province" name="province" required defaultValue=""><option value="" disabled>انتخاب استان</option><option>تهران</option><option>اصفهان</option><option>خراسان رضوی</option><option>فارس</option></select></div>
          <div className={styles.field}><label htmlFor="city">شهر</label><input id="city" name="city" autoComplete="address-level2" required placeholder="شهر" /></div>
          <div className={`${styles.field} ${styles.fieldWide}`}><label htmlFor="address">نشانی کامل</label><textarea id="address" name="address" autoComplete="street-address" required placeholder="خیابان، کوچه، پلاک و واحد" /></div>
          <div className={styles.field}><label htmlFor="postal">کد پستی</label><input id="postal" name="postal" inputMode="numeric" autoComplete="postal-code" pattern="[0-9۰-۹]{10}" required placeholder="۱۰ رقم" /></div>
        </div>
        <div className={styles.paymentInfo}><b>ارسال پستی برای این مرحله در نظر گرفته شده است.</b><br />هزینهٔ ارسال نهایی را سرور محاسبه می‌کند. ثبت سفارش به‌معنی پرداخت نیست؛ خرید پس از اتصال و تأیید درگاه کامل می‌شود.</div>
        {error && <p role="alert" className={styles.paymentInfo}>{error}</p>}
        {unsupportedLines.length > 0 && <p className={styles.summaryNote}>برای ثبت آنلاین، فعلاً این کالاها را از سبد بردار: {unsupportedLines.map((line) => line.title).join("، ")}.</p>}
        {!apiBaseUrl && <p className={styles.summaryNote}>ثبت سفارش آنلاین هنوز برای این سایت فعال نشده است.</p>}
        <button className={styles.primaryAction} type="submit" disabled={submitting || !apiBaseUrl || unsupportedLines.length > 0}>{submitting ? "در حال ثبت سفارش…" : "ثبت سفارش و بررسی مبلغ نهایی"}</button>
      </form>
      <aside className={styles.checkoutSummary}><h2>مرور سفارش</h2>{cart.map((line) => <div className={styles.summaryProduct} key={line.id}><span>{line.title} × {toman(line.quantity)}</span><b>{toman(line.price * line.quantity)} تومان</b></div>)}<div className={styles.summaryRow}><span>جمع محصولات</span><strong>{toman(subtotal)} تومان</strong></div><div className={styles.summaryRow}><span>ارسال</span><strong>{shipping ? `${toman(shipping)} تومان` : "رایگان"}</strong></div><div className={`${styles.summaryRow} ${styles.summaryTotal}`}><span>برآورد اولیه</span><strong>{toman(total)} تومان</strong></div><p className={styles.summaryNote}>مبلغ نهایی و موجودی فقط پس از پاسخ سرور تأیید می‌شود.</p></aside>
    </section><StoreFooter />
  </main>;
}

export function InfoPage({ page }: { page: "about" | "shipping" | "returns" | "faq" | "contact" }) {
  const content = {
    about: { kicker:"داستان مزه‌دونه", title:"مزه‌های کوچک، با حوصله انتخاب می‌شوند.", intro:"مزه‌دونه برای انتخاب‌های روزمره ساخته شده؛ از یک مشت آجیل تا کوکی خانگی کنار چای.", facts:[["انتخاب دقیق","تازگی، کیفیت و ترکیبات روشن باید پیش از خرید قابل بررسی باشند."],["آماده‌سازی باحوصله","برای خوراکی‌های خانگی، زمان تولید و شیوهٔ نگهداری شفاف خواهد بود."],["سفارش ساده","از انتخاب محصول تا دریافت، اطلاعات هزینه و ارسال باید روشن باشد."]] },
    shipping: { kicker:"تحویل سفارش", title:"روش و زمان ارسال", intro:"هزینه و زمان تحویل باید پیش از پرداخت با توجه به شهر و شیوهٔ ارسال مشخص شود.", facts:[["پست پیشتاز","روش سراسری پیش‌بینی‌شده برای ارسال بسته‌ها؛ نرخ و زمان نهایی به سرویس ارسال وابسته است."],["پیک شهری","برای محدوده‌های قابل پوشش، پس از ثبت قوانین ارسال در پنل فعال می‌شود."],["رهگیری","پس از آماده‌سازی و تحویل به شرکت ارسال، کد رهگیری در اختیار خریدار قرار می‌گیرد."]] },
    returns: { kicker:"پشتیبانی خرید", title:"پیگیری و بازگشت سفارش", intro:"شرایط قطعی رسیدگی و بازگشت باید پیش از شروع فروش نهایی و در این صفحه منتشر شود.", facts:[["پیگیری","شمارهٔ سفارش و راه تماس پشتیبانی را برای پیگیری آماده داشته باش."],["آسیب یا مغایرت","از بسته و کالا عکس بگیر و موضوع را در اولین فرصت اطلاع بده."],["شرایط نهایی","مهلت و ضوابط بازگشت پس از تعیین فرایند عملیاتی مزه‌دونه به این صفحه اضافه می‌شود."]] },
    faq: { kicker:"پاسخ‌های کوتاه", title:"پرسش‌های پرتکرار", intro:"راهنمای سریع برای انتخاب محصول و روند سفارش.", facts:[] },
    contact: { kicker:"کنارت هستیم", title:"تماس با مزه‌دونه", intro:"راه‌های ارتباطی قطعی پس از تعیین شماره و کانال پشتیبانی فروشگاه اینجا قرار می‌گیرند.", facts:[["پشتیبانی","در نسخهٔ واقعی شماره، ساعت پاسخ‌گویی و پیوند پیام‌رسان نمایش داده خواهد شد."],["سفارش سازمانی","برای پک‌های چندتایی و هدیهٔ سازمانی، درخواست و تعداد مقصدها را بفرست."],["نسخهٔ فعلی","این وب‌سایت نمونهٔ طراحی است و سفارش واقعی نمی‌پذیرد."]] },
  }[page];
  return <ShopShell kicker={content.kicker} title={content.title} description={content.intro}>
    {page === "faq" ? <section className={styles.content}><div className={styles.faqList}><details className={styles.faqItem}><summary>چطور سفارشم را ثبت کنم؟</summary><p>محصول را انتخاب کن، به سبد اضافه کن و اطلاعات تحویل را وارد کن. در این پیش‌نمایش پرداخت و ثبت سفارش واقعی فعال نیست.</p></details><details className={styles.faqItem}><summary>چطور وزن و ترکیبات را ببینم؟</summary><p>در صفحهٔ هر محصول، بسته و اطلاعات ثبت‌شدهٔ همان محصول نمایش داده می‌شود. اطلاعات نمونه تا زمان تأیید فروش واقعی نیست.</p></details><details className={styles.faqItem}><summary>هزینه و زمان ارسال چطور مشخص می‌شود؟</summary><p>در فروش واقعی، هزینه و روش قابل انتخاب باید پیش از پرداخت بر اساس آدرس محاسبه و نمایش داده شود.</p></details><details className={styles.faqItem}><summary>آیا پرداخت این نسخه واقعی است؟</summary><p>خیر؛ نسخهٔ فعلی فقط نمونهٔ مسیر خرید است و اطلاعات پرداخت دریافت نمی‌کند.</p></details></div></section> : <section className={styles.content}><div className={styles.infoGrid}>{content.facts.map(([title, text]) => <article className={styles.infoCard} key={title}><span>{page === "about" ? "مزه‌دونه" : "راهنمای مزه‌دونه"}</span><strong>{title}</strong><p>{text}</p></article>)}</div>{page === "about" && <div className={styles.storyBlock}><h2>خوش‌خوراکِ هر روز</h2><p>آجیل و مغزها، میوه خشک، لواشک و شیرینی خانگی کم‌شکر؛ با توضیح روشن و انتخاب آسان.</p></div>}</section>}
  </ShopShell>;
}
