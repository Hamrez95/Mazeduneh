"use client";

import { FormEvent, useEffect, useMemo, useState } from "react";

type UnitType = "Weight" | "Count";

type ProductVariant = {
  sku: string;
  quantity: number;
  baseUnit: "gram" | "piece";
  displayLabel: string;
  price: number;
  availablePackages: number;
};

type Product = {
  id: string;
  title: string;
  slug: string;
  category: string;
  origin: string;
  currency: string;
  unitType: UnitType;
  isPublished: boolean;
  variants: ProductVariant[];
};

type CartItem = {
  sku: string;
  productTitle: string;
  variantLabel: string;
  unitPrice: number;
  quantity: number;
  maxQuantity: number;
};

type CheckoutOrder = {
  id: string;
  receiptToken: string;
  customerName: string;
  currency: string;
  subtotal: number;
  shipping: number;
  discount: number;
  payable: number;
  state: string;
  reservationExpiresAt: string;
};

type CheckoutForm = {
  customerName: string;
  mobile: string;
  province: string;
  city: string;
  address: string;
  postalCode: string;
};

const API_BASE = (
  process.env.NEXT_PUBLIC_MAZEDUNEH_API_URL?.trim()
  || process.env.NEXT_PUBLIC_MAZEDUNEH_API_BASE_URL?.trim()
  || ""
).replace(/\/$/, "");
const CART_KEY = "mazeduneh-cart-v1";

const previewProducts: Product[] = [
  {
    id: "preview-pistachio",
    title: "پسته اکبری ممتاز",
    slug: "pistachio-akbari-premium",
    category: "پسته و مغزیجات",
    origin: "رفسنجان",
    currency: "IRR",
    unitType: "Weight",
    isPublished: true,
    variants: [
      { sku: "PI-AKB-250", quantity: 250, baseUnit: "gram", displayLabel: "۲۵۰ گرم", price: 2_450_000, availablePackages: 18 },
      { sku: "PI-AKB-500", quantity: 500, baseUnit: "gram", displayLabel: "۵۰۰ گرم", price: 4_650_000, availablePackages: 12 },
      { sku: "PI-AKB-1000", quantity: 1000, baseUnit: "gram", displayLabel: "۱۰۰۰ گرم", price: 8_900_000, availablePackages: 6 },
    ],
  },
  {
    id: "preview-seeds",
    title: "تخمه کدو گوشتی",
    slug: "pumpkin-seeds",
    category: "تخمه و تنقلات",
    origin: "ایران",
    currency: "IRR",
    unitType: "Weight",
    isPublished: true,
    variants: [
      { sku: "SE-PUM-250", quantity: 250, baseUnit: "gram", displayLabel: "۲۵۰ گرم", price: 950_000, availablePackages: 22 },
      { sku: "SE-PUM-500", quantity: 500, baseUnit: "gram", displayLabel: "۵۰۰ گرم", price: 1_800_000, availablePackages: 14 },
      { sku: "SE-PUM-1000", quantity: 1000, baseUnit: "gram", displayLabel: "۱۰۰۰ گرم", price: 3_400_000, availablePackages: 7 },
    ],
  },
  {
    id: "preview-almond",
    title: "بادام درختی خام",
    slug: "raw-almond",
    category: "پسته و مغزیجات",
    origin: "چهارمحال",
    currency: "IRR",
    unitType: "Weight",
    isPublished: true,
    variants: [
      { sku: "NU-ALM-250", quantity: 250, baseUnit: "gram", displayLabel: "۲۵۰ گرم", price: 1_750_000, availablePackages: 25 },
      { sku: "NU-ALM-500", quantity: 500, baseUnit: "gram", displayLabel: "۵۰۰ گرم", price: 3_300_000, availablePackages: 16 },
      { sku: "NU-ALM-1000", quantity: 1000, baseUnit: "gram", displayLabel: "۱۰۰۰ گرم", price: 6_400_000, availablePackages: 8 },
    ],
  },
  {
    id: "preview-cookie",
    title: "کوکی پروتئینی مزه‌دونه",
    slug: "mazeduneh-protein-cookie",
    category: "کوکی و کیک سالم",
    origin: "تولید روز",
    currency: "IRR",
    unitType: "Count",
    isPublished: true,
    variants: [
      { sku: "CK-PRO-1", quantity: 1, baseUnit: "piece", displayLabel: "۱ عدد", price: 950_000, availablePackages: 48 },
      { sku: "CK-PRO-4", quantity: 4, baseUnit: "piece", displayLabel: "پک ۴ عددی", price: 3_600_000, availablePackages: 20 },
      { sku: "CK-PRO-8", quantity: 8, baseUnit: "piece", displayLabel: "پک ۸ عددی", price: 6_900_000, availablePackages: 10 },
    ],
  },
];

const emptyForm: CheckoutForm = {
  customerName: "",
  mobile: "",
  province: "",
  city: "",
  address: "",
  postalCode: "",
};

function formatToman(irr: number) {
  return new Intl.NumberFormat("fa-IR").format(Math.round(irr / 10));
}

function productIcon(product: Product) {
  if (product.unitType === "Count") return "🍪";
  if (product.title.includes("پسته")) return "🟢";
  if (product.title.includes("تخمه")) return "🎃";
  if (product.title.includes("گردو")) return "🧠";
  return "🌰";
}

function createIdempotencyKey() {
  if (typeof crypto !== "undefined" && "randomUUID" in crypto) {
    return `checkout-${crypto.randomUUID()}`;
  }
  return `checkout-${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

export default function StorefrontApp() {
  const [products, setProducts] = useState<Product[]>(previewProducts);
  const [catalogMode, setCatalogMode] = useState<"loading" | "live" | "preview" | "error">(
    API_BASE ? "loading" : "preview",
  );
  const [selectedVariants, setSelectedVariants] = useState<Record<string, string>>({});
  const [cart, setCart] = useState<CartItem[]>([]);
  const [cartOpen, setCartOpen] = useState(false);
  const [checkoutOpen, setCheckoutOpen] = useState(false);
  const [form, setForm] = useState<CheckoutForm>(emptyForm);
  const [submitting, setSubmitting] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [order, setOrder] = useState<CheckoutOrder | null>(null);

  useEffect(() => {
    try {
      const stored = localStorage.getItem(CART_KEY);
      if (stored) setCart(JSON.parse(stored) as CartItem[]);
    } catch {
      localStorage.removeItem(CART_KEY);
    }
  }, []);

  useEffect(() => {
    localStorage.setItem(CART_KEY, JSON.stringify(cart));
  }, [cart]);

  useEffect(() => {
    if (!API_BASE) return;
    const controller = new AbortController();
    fetch(`${API_BASE}/api/v1/products`, { signal: controller.signal })
      .then(async (response) => {
        if (!response.ok) throw new Error(`catalog-${response.status}`);
        return (await response.json()) as Product[];
      })
      .then((items) => {
        setProducts(items);
        setCatalogMode("live");
      })
      .catch((error: unknown) => {
        if (error instanceof DOMException && error.name === "AbortError") return;
        setProducts(previewProducts);
        setCatalogMode("error");
      });
    return () => controller.abort();
  }, []);

  useEffect(() => {
    setSelectedVariants((current) => {
      const next = { ...current };
      for (const product of products) {
        if (!next[product.id] && product.variants.length > 0) next[product.id] = product.variants[0].sku;
      }
      return next;
    });
  }, [products]);

  const cartCount = cart.reduce((total, item) => total + item.quantity, 0);
  const estimatedSubtotal = cart.reduce((total, item) => total + item.unitPrice * item.quantity, 0);
  const estimatedShipping = estimatedSubtotal >= 15_000_000 || estimatedSubtotal === 0 ? 0 : 750_000;
  const estimatedPayable = estimatedSubtotal + estimatedShipping;

  const categories = useMemo(() => Array.from(new Set(products.map((item) => item.category))), [products]);

  function addToCart(product: Product) {
    const sku = selectedVariants[product.id] ?? product.variants[0]?.sku;
    const variant = product.variants.find((item) => item.sku === sku);
    if (!variant || variant.availablePackages <= 0) return;

    setCart((items) => {
      const existing = items.find((item) => item.sku === variant.sku);
      if (existing) {
        return items.map((item) =>
          item.sku === variant.sku
            ? { ...item, quantity: Math.min(item.quantity + 1, item.maxQuantity) }
            : item,
        );
      }
      return [
        ...items,
        {
          sku: variant.sku,
          productTitle: product.title,
          variantLabel: variant.displayLabel,
          unitPrice: variant.price,
          quantity: 1,
          maxQuantity: variant.availablePackages,
        },
      ];
    });
    setCartOpen(true);
  }

  function updateQuantity(sku: string, quantity: number) {
    setCart((items) =>
      items
        .map((item) => (item.sku === sku ? { ...item, quantity: Math.max(0, Math.min(quantity, item.maxQuantity)) } : item))
        .filter((item) => item.quantity > 0),
    );
  }

  async function submitCheckout(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setMessage(null);
    setOrder(null);

    if (!API_BASE || catalogMode !== "live") {
      setMessage("این نسخه در حالت پیش‌نمایش است؛ برای ثبت سفارش باید API آنلاین مزه‌دونه تنظیم شود.");
      return;
    }
    if (cart.length === 0) {
      setMessage("سبد خرید خالی است.");
      return;
    }

    setSubmitting(true);
    try {
      const response = await fetch(`${API_BASE}/api/v1/checkout/orders`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Idempotency-Key": createIdempotencyKey(),
        },
        body: JSON.stringify({
          ...form,
          lines: cart.map((item) => ({ sku: item.sku, quantity: item.quantity })),
        }),
      });

      const payload = (await response.json()) as CheckoutOrder & { message?: string; errors?: Record<string, string[]> };
      if (!response.ok) {
        const validation = payload.errors ? Object.values(payload.errors).flat().join(" ") : null;
        throw new Error(validation || payload.message || "ثبت سفارش ناموفق بود.");
      }

      setOrder(payload);
      setCart([]);
      setForm(emptyForm);
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "ارتباط با سرور برقرار نشد.");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <main>
      <div className="announcement">ارسال به سراسر ایران · ارسال رایگان سفارش‌های بالای ۱٬۵۰۰٬۰۰۰ تومان</div>

      <header className="siteHeader shell">
        <a className="brand" href="#top" aria-label="صفحه اصلی مزه‌دونه">
          <span className="brandMark" aria-hidden="true">ن</span>
          <span><strong>مزه‌دونه</strong><small>دست‌چین لحظه‌های خوش</small></span>
        </a>
        <nav aria-label="منوی اصلی">
          <a href="#products">فروشگاه</a>
          <a href="#gift">هدیه</a>
          <a href="#story">استاندارد کیفیت</a>
        </nav>
        <div className="headerActions">
          <button className="cartButton" type="button" onClick={() => setCartOpen(true)}>
            سبد خرید <span>{new Intl.NumberFormat("fa-IR").format(cartCount)}</span>
          </button>
        </div>
      </header>

      <section className="hero shell" id="top">
        <div className="heroCopy">
          <span className="eyebrow">تازه، شفاف، خوش‌هدیه</span>
          <h1>هر دانه، یک انتخاب خوب</h1>
          <p>آجیل، مغزیجات و خوراکی‌های سالم با واحد فروش شفاف، موجودی قابل کنترل و سفارش امن.</p>
          <div className="heroActions">
            <a className="primaryButton" href="#products">خرید محصولات</a>
            <button className="secondaryButton" type="button" onClick={() => setCartOpen(true)}>دیدن سبد</button>
          </div>
          <ul className="trustList"><li>ضمانت تازگی</li><li>قیمت نهایی در سرور</li><li>رزرو امن موجودی</li></ul>
        </div>
        <div className="heroVisual" aria-label="تصویر مفهومی مغزیجات مزه‌دونه">
          <div className="sun" />
          <div className="bowl"><span>🥜</span><span>🌰</span><span>🍪</span><span>🎃</span></div>
        </div>
      </section>

      <section className="catalogStatus shell" role="status">
        <span className={`statusDot ${catalogMode}`} />
        {catalogMode === "live" && "کاتالوگ زنده و متصل به API"}
        {catalogMode === "loading" && "در حال دریافت کاتالوگ زنده…"}
        {catalogMode === "preview" && "حالت پیش‌نمایش؛ قیمت و موجودی نمونه هستند"}
        {catalogMode === "error" && "API در دسترس نبود؛ داده نمونه برای بازبینی نمایش داده می‌شود"}
      </section>

      <section className="section shell" aria-labelledby="category-title">
        <div className="sectionHeading"><div><span className="eyebrow">انتخاب سریع</span><h2 id="category-title">دسته‌بندی‌ها</h2></div></div>
        <div className="categoryGrid">
          {categories.map((category, index) => (
            <a className="categoryCard" href="#products" key={category}>
              <span className="categoryIcon">{["🥜", "🎃", "🍪", "🎁"][index % 4]}</span>
              <strong>{category}</strong><small>مشاهده بسته‌های قابل فروش</small><span className="roundArrow">←</span>
            </a>
          ))}
        </div>
      </section>

      <section className="section shell" id="products" aria-labelledby="products-title">
        <div className="sectionHeading">
          <div><span className="eyebrow">کاتالوگ مزه‌دونه</span><h2 id="products-title">محصولات قابل سفارش</h2></div>
          <small>مبالغ به تومان نمایش داده می‌شوند</small>
        </div>
        <div className="productGrid">
          {products.map((product) => {
            const selectedSku = selectedVariants[product.id] ?? product.variants[0]?.sku;
            const variant = product.variants.find((item) => item.sku === selectedSku) ?? product.variants[0];
            return (
              <article className="productCard" key={product.id}>
                <div className="productImage">
                  <span className="badge">{product.unitType === "Weight" ? "وزنی" : "عددی"}</span>
                  <span className="productEmoji" aria-hidden="true">{productIcon(product)}</span>
                </div>
                <div className="productBody">
                  <small>{product.origin} · {product.category}</small>
                  <h3>{product.title}</h3>
                  <div className="weightRow" aria-label={`انتخاب بسته ${product.title}`}>
                    {product.variants.map((item) => (
                      <button
                        className={item.sku === selectedSku ? "selected" : ""}
                        type="button"
                        key={item.sku}
                        disabled={item.availablePackages <= 0}
                        onClick={() => setSelectedVariants((current) => ({ ...current, [product.id]: item.sku }))}
                      >
                        {item.displayLabel}
                      </button>
                    ))}
                  </div>
                  <div className="stockLine">
                    {variant?.availablePackages ? `${new Intl.NumberFormat("fa-IR").format(variant.availablePackages)} بسته موجود` : "ناموجود"}
                  </div>
                  <div className="priceRow">
                    <p><strong>{variant ? formatToman(variant.price) : "—"}</strong> تومان</p>
                    <button className="addButton" type="button" disabled={!variant || variant.availablePackages <= 0} onClick={() => addToCart(product)} aria-label={`افزودن ${product.title} به سبد`}>＋</button>
                  </div>
                </div>
              </article>
            );
          })}
        </div>
      </section>

      <section className="story shell" id="story">
        <div className="storyCopy"><span className="eyebrow">استاندارد مزه‌دونه</span><h2>فاکتور باید ثابت و موجودی باید قابل اعتماد باشد</h2><p>قیمت نهایی از Backend محاسبه می‌شود، سفارش تکراری ساخته نمی‌شود و موجودی هر بسته برای مدت محدود رزرو می‌ماند.</p></div>
        <div className="qualityCard"><div><strong>۲۰ دقیقه</strong><span>مهلت رزرو سفارش</span></div><div><strong>۱۰۰٪</strong><span>قیمت‌گذاری سمت سرور</span></div><div><strong>سراسری</strong><span>ارسال اولیه در ایران</span></div></div>
      </section>

      <section className="campaignGrid shell" id="gift">
        <article className="campaign giftCampaign"><span>مزه‌دونه هدیه</span><h2>پک‌های مناسبتی و سازمانی</h2><p>زیرساخت محصول و سفارش آماده توسعه پک‌های سفارشی است.</p></article>
        <article className="campaign healthCampaign"><span>مزه‌دونه سلامت</span><h2>کیک و کوکی رژیمی</h2><p>فروش عددی و پک چندتایی در همان سبد مغزیجات پشتیبانی می‌شود.</p></article>
      </section>

      <footer><div className="footerInner shell"><div className="footerBrand"><a className="brand" href="#top"><span className="brandMark">ن</span><span><strong>مزه‌دونه</strong><small>دست‌چین لحظه‌های خوش</small></span></a><p>فروش آنلاین آجیل، مغزیجات و خوراکی سالم با مدل شفاف واحد و بسته‌بندی.</p></div><div><strong>خرید</strong><a href="#products">محصولات</a><a href="#gift">پک هدیه</a></div><div><strong>پشتیبانی</strong><a href="mailto:Hamidrezapakpour95@gmail.com">ارتباط با مدیر</a></div></div><div className="copyright shell">© ۲۰۲۶ مزه‌دونه — نسخه توسعه متصل</div></footer>

      {cartOpen && <div className="drawerBackdrop" onMouseDown={() => setCartOpen(false)}><aside className="cartDrawer" onMouseDown={(event) => event.stopPropagation()} aria-label="سبد خرید">
        <div className="drawerHeader"><div><small>سبد خرید</small><h2>{cartCount ? `${new Intl.NumberFormat("fa-IR").format(cartCount)} کالا` : "سبد خالی است"}</h2></div><button type="button" onClick={() => setCartOpen(false)} aria-label="بستن">×</button></div>
        <div className="cartItems">
          {cart.map((item) => <article className="cartItem" key={item.sku}><div><strong>{item.productTitle}</strong><small>{item.variantLabel} · {item.sku}</small><b>{formatToman(item.unitPrice * item.quantity)} تومان</b></div><div className="quantityControl"><button type="button" onClick={() => updateQuantity(item.sku, item.quantity - 1)}>−</button><span>{new Intl.NumberFormat("fa-IR").format(item.quantity)}</span><button type="button" onClick={() => updateQuantity(item.sku, item.quantity + 1)} disabled={item.quantity >= item.maxQuantity}>＋</button></div></article>)}
          {!cart.length && <div className="emptyCart">هنوز محصولی انتخاب نکرده‌ای.</div>}
        </div>
        <div className="cartSummary"><p><span>جمع کالاها</span><b>{formatToman(estimatedSubtotal)} تومان</b></p><p><span>ارسال تخمینی</span><b>{estimatedShipping ? `${formatToman(estimatedShipping)} تومان` : "رایگان"}</b></p><p className="total"><span>مبلغ تخمینی</span><b>{formatToman(estimatedPayable)} تومان</b></p><small>عدد قطعی هنگام Checkout توسط سرور محاسبه می‌شود.</small><button className="checkoutButton" type="button" disabled={!cart.length} onClick={() => { setCartOpen(false); setCheckoutOpen(true); }}>ادامه و ثبت اطلاعات ارسال</button></div>
      </aside></div>}

      {checkoutOpen && <div className="modalBackdrop"><section className="checkoutModal" aria-label="ثبت سفارش">
        <div className="drawerHeader"><div><small>Checkout امن</small><h2>{order ? "سفارش ثبت شد" : "اطلاعات تحویل"}</h2></div><button type="button" onClick={() => { setCheckoutOpen(false); setMessage(null); setOrder(null); }} aria-label="بستن">×</button></div>
        {order ? <div className="receipt"><span className="successMark">✓</span><h3>سفارش با موفقیت رزرو شد</h3><p>شماره سفارش: <b dir="ltr">{order.id}</b></p><div className="receiptGrid"><div><small>مبلغ قابل پرداخت</small><strong>{formatToman(order.payable)} تومان</strong></div><div><small>وضعیت</small><strong>{order.state}</strong></div><div><small>انقضای رزرو</small><strong>{new Date(order.reservationExpiresAt).toLocaleString("fa-IR")}</strong></div></div><div className="previewNotice">درگاه پرداخت هنوز فعال نیست؛ این مرحله فقط رزرو و ثبت سفارش را اثبات می‌کند.</div></div> : <form className="checkoutForm" onSubmit={submitCheckout}>
          <label>نام تحویل‌گیرنده<input required value={form.customerName} onChange={(event) => setForm({ ...form, customerName: event.target.value })} /></label>
          <label>شماره موبایل<input required inputMode="tel" dir="ltr" value={form.mobile} onChange={(event) => setForm({ ...form, mobile: event.target.value })} /></label>
          <label>استان<input required value={form.province} onChange={(event) => setForm({ ...form, province: event.target.value })} /></label>
          <label>شهر<input required value={form.city} onChange={(event) => setForm({ ...form, city: event.target.value })} /></label>
          <label className="fullField">نشانی<textarea required rows={3} value={form.address} onChange={(event) => setForm({ ...form, address: event.target.value })} /></label>
          <label>کدپستی<input required inputMode="numeric" dir="ltr" value={form.postalCode} onChange={(event) => setForm({ ...form, postalCode: event.target.value })} /></label>
          <div className="checkoutTotal"><span>مبلغ تخمینی</span><b>{formatToman(estimatedPayable)} تومان</b></div>
          {message && <div className="formError" role="alert">{message}</div>}
          <button className="checkoutButton fullField" type="submit" disabled={submitting}>{submitting ? "در حال ثبت امن سفارش…" : "ثبت سفارش و رزرو موجودی"}</button>
          <small className="fullField">پرداخت واقعی در این نسخه غیرفعال است. هیچ مبلغی از شما دریافت نمی‌شود.</small>
        </form>}
      </section></div>}
    </main>
  );
}
