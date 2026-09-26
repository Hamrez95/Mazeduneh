"use client";

import { FormEvent, useMemo, useState } from "react";
import styles from "./PartnerDemoApp.module.css";

type Product = {
  id: string;
  title: string;
  subtitle: string;
  category: string;
  origin: string;
  icon: string;
  tone: string;
  price: number;
  oldPrice?: number;
  packageLabel: string;
  stock: number;
  badge?: string;
};

type CartLine = Product & { quantity: number };

type DemoOrder = {
  code: string;
  customer: string;
  payable: number;
  createdAt: string;
};

const ADMIN_URL = process.env.NEXT_PUBLIC_MAZEDUNEH_ADMIN_URL ?? "https://mazeduneh-admin.vercel.app";

const products: Product[] = [
  {
    id: "pistachio-akbari",
    title: "پسته اکبری ممتاز",
    subtitle: "دست‌چین، خندان و یکدست",
    category: "مغزیجات",
    origin: "رفسنجان",
    icon: "🥜",
    tone: "pistachio",
    price: 465000,
    oldPrice: 495000,
    packageLabel: "بسته ۵۰۰ گرمی",
    stock: 12,
    badge: "پرفروش",
  },
  {
    id: "pistachio-ahmad",
    title: "پسته احمدآقایی",
    subtitle: "کشیده، خوش‌رنگ و شور ملایم",
    category: "مغزیجات",
    origin: "کرمان",
    icon: "🟢",
    tone: "mint",
    price: 445000,
    packageLabel: "بسته ۵۰۰ گرمی",
    stock: 10,
    badge: "محبوب",
  },
  {
    id: "almond",
    title: "بادام درختی خام",
    subtitle: "بدون نمک، مناسب میان‌وعده",
    category: "مغزیجات",
    origin: "چهارمحال",
    icon: "🌰",
    tone: "almond",
    price: 330000,
    packageLabel: "بسته ۵۰۰ گرمی",
    stock: 16,
  },
  {
    id: "walnut",
    title: "مغز گردوی ایرانی",
    subtitle: "روشن، تازه و مناسب صبحانه",
    category: "مغزیجات",
    origin: "تویسرکان",
    icon: "🧠",
    tone: "peach",
    price: 305000,
    packageLabel: "بسته ۵۰۰ گرمی",
    stock: 8,
  },
  {
    id: "dried-fruit",
    title: "میکس میوه خشک",
    subtitle: "سیب، پرتقال، کیوی و توت‌فرنگی",
    category: "میوه خشک",
    origin: "تولید مزه‌دونه",
    icon: "🍊",
    tone: "apricot",
    price: 238000,
    oldPrice: 255000,
    packageLabel: "بسته ۳۰۰ گرمی",
    stock: 21,
    badge: "جدید",
  },
  {
    id: "pumpkin-seeds",
    title: "تخمه کدو گوشتی",
    subtitle: "درشت، تازه و کم‌نمک",
    category: "تنقلات",
    origin: "ایران",
    icon: "🎃",
    tone: "sage",
    price: 180000,
    packageLabel: "بسته ۵۰۰ گرمی",
    stock: 14,
  },
  {
    id: "protein-cookie",
    title: "کوکی پروتئینی",
    subtitle: "جو دوسر، کره بادام‌زمینی و شکلات تلخ",
    category: "خوراکی سالم",
    origin: "تولید روز",
    icon: "🍪",
    tone: "lavender",
    price: 360000,
    packageLabel: "پک ۴ عددی",
    stock: 20,
    badge: "بدون شکر افزوده",
  },
  {
    id: "gift-box",
    title: "جعبه هدیه دورهمی",
    subtitle: "ترکیب آجیل ممتاز با بسته‌بندی هدیه",
    category: "هدیه",
    origin: "مزه‌دونه",
    icon: "🎁",
    tone: "rose",
    price: 1290000,
    oldPrice: 1380000,
    packageLabel: "جعبه ۱٫۲ کیلوگرمی",
    stock: 7,
    badge: "ویژه هدیه",
  },
];

const categories = ["همه", "مغزیجات", "میوه خشک", "تنقلات", "خوراکی سالم", "هدیه"];

function money(value: number) {
  return new Intl.NumberFormat("fa-IR").format(value);
}

export default function PartnerDemoApp() {
  const [category, setCategory] = useState("همه");
  const [cart, setCart] = useState<CartLine[]>([]);
  const [cartOpen, setCartOpen] = useState(false);
  const [checkoutOpen, setCheckoutOpen] = useState(false);
  const [order, setOrder] = useState<DemoOrder | null>(null);

  const visibleProducts = useMemo(
    () => (category === "همه" ? products : products.filter((product) => product.category === category)),
    [category],
  );

  const cartCount = cart.reduce((sum, line) => sum + line.quantity, 0);
  const subtotal = cart.reduce((sum, line) => sum + line.price * line.quantity, 0);
  const shipping = subtotal === 0 || subtotal >= 1500000 ? 0 : 75000;
  const payable = subtotal + shipping;

  function addToCart(product: Product) {
    setCart((current) => {
      const existing = current.find((line) => line.id === product.id);
      if (!existing) return [...current, { ...product, quantity: 1 }];
      return current.map((line) =>
        line.id === product.id
          ? { ...line, quantity: Math.min(line.quantity + 1, product.stock) }
          : line,
      );
    });
    setCartOpen(true);
  }

  function changeQuantity(id: string, delta: number) {
    setCart((current) =>
      current
        .map((line) =>
          line.id === id
            ? { ...line, quantity: Math.max(0, Math.min(line.quantity + delta, line.stock)) }
            : line,
        )
        .filter((line) => line.quantity > 0),
    );
  }

  function submitDemoOrder(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    const customer = String(form.get("customer") ?? "مشتری دمو");
    const code = `NS-${new Intl.NumberFormat("fa-IR", { useGrouping: false }).format(
      Math.floor(100000 + Math.random() * 900000),
    )}`;
    setOrder({
      code,
      customer,
      payable,
      createdAt: new Intl.DateTimeFormat("fa-IR", { dateStyle: "medium", timeStyle: "short" }).format(new Date()),
    });
    setCart([]);
    setCheckoutOpen(false);
    setCartOpen(false);
  }

  return (
    <main className={styles.page}>
      <div className={styles.demoBar}>
        <strong>نسخه نمایشی مزه‌دونه</strong>
        <span>تمام داده‌ها آزمایشی‌اند و هیچ پرداخت واقعی انجام نمی‌شود.</span>
      </div>

      <header className={styles.header}>
        <a href="#top" className={styles.brand} aria-label="مزه‌دونه">
          <span className={styles.brandMark}>ن</span>
          <span><b>مزه‌دونه</b><small>دست‌چینِ لحظه‌های خوش</small></span>
        </a>
        <nav className={styles.nav}>
          <a href="#products">فروشگاه</a>
          <a href="#gift">هدیه سازمانی</a>
          <a href="#quality">کیفیت و تازگی</a>
        </nav>
        <div className={styles.headerActions}>
          <a className={styles.adminLink} href={ADMIN_URL} target="_blank" rel="noreferrer">پنل مدیریت</a>
          <button className={styles.cartButton} type="button" onClick={() => setCartOpen(true)}>
            سبد خرید <span>{money(cartCount)}</span>
          </button>
        </div>
      </header>

      <section className={styles.hero} id="top">
        <div className={styles.heroCopy}>
          <span className={styles.eyebrow}>تازه، شفاف، خوش‌هدیه</span>
          <h1>طعم خوب، انتخاب مطمئن</h1>
          <p>
            خشکبار و خوراکی‌های سالم با منشأ مشخص، بسته‌بندی تمیز و تجربه خریدی که از انتخاب محصول تا تحویل قابل پیگیری است.
          </p>
          <div className={styles.heroButtons}>
            <a href="#products" className={styles.primaryButton}>دیدن محصولات</a>
            <a href="#gift" className={styles.secondaryButton}>سفارش هدیه</a>
          </div>
          <div className={styles.trustRow}>
            <span>✓ ضمانت تازگی</span><span>✓ بسته‌بندی بهداشتی</span><span>✓ ارسال به سراسر ایران</span>
          </div>
        </div>
        <div className={styles.heroArt} aria-hidden="true">
          <div className={styles.heroGlow} />
          <div className={styles.bowl}>🥜<span>🌰</span><i>🍊</i></div>
          <div className={styles.floatingCard}><b>۴٫۹</b><small>رضایت مشتریان دمو</small></div>
          <div className={styles.floatingLeaf}>✦</div>
        </div>
      </section>

      <section className={styles.stats} aria-label="شاخص‌های نمونه">
        <article><b>۲۴</b><span>محصول قابل فروش</span></article>
        <article><b>۹۸٪</b><span>ارسال بدون مغایرت</span></article>
        <article><b>۴٫۹/۵</b><span>امتیاز تجربه خرید</span></article>
        <article><b>۴۸ ساعت</b><span>تعهد تازگی بسته‌بندی</span></article>
      </section>

      <section className={styles.productsSection} id="products">
        <div className={styles.sectionHeading}>
          <div><span>فروشگاه مزه‌دونه</span><h2>محصولات دست‌چین‌شده</h2></div>
          <p>قیمت‌ها و موجودی این صفحه برای ارائه دمو هستند.</p>
        </div>
        <div className={styles.categories}>
          {categories.map((item) => (
            <button
              key={item}
              type="button"
              className={category === item ? styles.activeCategory : ""}
              onClick={() => setCategory(item)}
            >
              {item}
            </button>
          ))}
        </div>
        <div className={styles.productGrid}>
          {visibleProducts.map((product) => (
            <article className={styles.productCard} key={product.id}>
              <div className={`${styles.productVisual} ${styles[product.tone]}`}>
                {product.badge && <span className={styles.badge}>{product.badge}</span>}
                <span className={styles.productIcon}>{product.icon}</span>
                <small>{product.origin}</small>
              </div>
              <div className={styles.productBody}>
                <span className={styles.productCategory}>{product.category}</span>
                <h3>{product.title}</h3>
                <p>{product.subtitle}</p>
                <div className={styles.packageRow}>
                  <span>{product.packageLabel}</span><small>{money(product.stock)} بسته موجود</small>
                </div>
                <div className={styles.priceRow}>
                  <div>
                    {product.oldPrice && <del>{money(product.oldPrice)}</del>}
                    <b>{money(product.price)} <small>تومان</small></b>
                  </div>
                  <button type="button" onClick={() => addToCart(product)} aria-label={`افزودن ${product.title}`}>
                    +
                  </button>
                </div>
              </div>
            </article>
          ))}
        </div>
      </section>

      <section className={styles.giftSection} id="gift">
        <div className={styles.giftCopy}>
          <span>هدیه‌ای که مصرف می‌شود و به یاد می‌ماند</span>
          <h2>جعبه‌های هدیه شخصی و سازمانی</h2>
          <p>انتخاب ترکیب، کارت تبریک، رنگ‌بندی بسته و زمان تحویل در پنل سفارش مدیریت می‌شود.</p>
          <button type="button" onClick={() => addToCart(products[7])}>افزودن جعبه نمونه به سبد</button>
        </div>
        <div className={styles.giftArt}>🎁<span>🥜</span><i>🌿</i></div>
      </section>

      <section className={styles.qualitySection} id="quality">
        <div className={styles.sectionHeading}>
          <div><span>پشت صحنه محصول</span><h2>اعتماد، فقط یک شعار نیست</h2></div>
        </div>
        <div className={styles.qualityGrid}>
          <article><span>01</span><h3>ورود و کنترل بچ</h3><p>تأمین‌کننده، تاریخ ورود، هزینه خرید و تاریخ مصرف در نسخه عملیاتی ثبت می‌شوند.</p></article>
          <article><span>02</span><h3>بسته‌بندی و موجودی</h3><p>هر وزن یا پک، SKU و موجودی مستقل دارد و سفارش بیش از موجودی پذیرفته نمی‌شود.</p></article>
          <article><span>03</span><h3>سفارش قابل پیگیری</h3><p>پرداخت، آماده‌سازی، ارسال و تحویل با تاریخچه تغییر وضعیت در پنل دیده می‌شوند.</p></article>
        </div>
      </section>

      <footer className={styles.footer}>
        <div className={styles.brand}><span className={styles.brandMark}>ن</span><span><b>مزه‌دونه</b><small>دموی ارائه شریک تجاری</small></span></div>
        <p>این نسخه برای نمایش تجربه محصول ساخته شده و داده‌های آن واقعی نیست.</p>
        <a href={ADMIN_URL} target="_blank" rel="noreferrer">ورود به دموی پنل مدیریت ←</a>
      </footer>

      {cartOpen && (
        <div className={styles.overlay} onMouseDown={() => setCartOpen(false)}>
          <aside className={styles.cartDrawer} onMouseDown={(event) => event.stopPropagation()}>
            <div className={styles.drawerHeader}>
              <div><span>سبد خرید دمو</span><h2>{money(cartCount)} قلم</h2></div>
              <button type="button" onClick={() => setCartOpen(false)}>×</button>
            </div>
            <div className={styles.cartLines}>
              {cart.length === 0 ? (
                <div className={styles.emptyCart}><span>🛍️</span><h3>سبد هنوز خالی است</h3><p>یکی از محصولات نمونه را اضافه کن.</p></div>
              ) : cart.map((line) => (
                <article key={line.id} className={styles.cartLine}>
                  <span className={styles.cartIcon}>{line.icon}</span>
                  <div><b>{line.title}</b><small>{line.packageLabel}</small><em>{money(line.price)} تومان</em></div>
                  <div className={styles.quantity}>
                    <button type="button" onClick={() => changeQuantity(line.id, -1)}>−</button>
                    <span>{money(line.quantity)}</span>
                    <button type="button" onClick={() => changeQuantity(line.id, 1)}>+</button>
                  </div>
                </article>
              ))}
            </div>
            <div className={styles.cartSummary}>
              <div><span>جمع کالاها</span><b>{money(subtotal)} تومان</b></div>
              <div><span>ارسال</span><b>{shipping === 0 ? "رایگان" : `${money(shipping)} تومان`}</b></div>
              <div className={styles.total}><span>مبلغ قابل پرداخت</span><b>{money(payable)} تومان</b></div>
              <button
                type="button"
                disabled={cart.length === 0}
                onClick={() => { setCheckoutOpen(true); setCartOpen(false); }}
              >
                ادامه و ثبت سفارش دمو
              </button>
            </div>
          </aside>
        </div>
      )}

      {checkoutOpen && (
        <div className={styles.overlay} onMouseDown={() => setCheckoutOpen(false)}>
          <section className={styles.checkoutModal} onMouseDown={(event) => event.stopPropagation()}>
            <div className={styles.drawerHeader}>
              <div><span>مرحله نهایی دمو</span><h2>اطلاعات تحویل</h2></div>
              <button type="button" onClick={() => setCheckoutOpen(false)}>×</button>
            </div>
            <form onSubmit={submitDemoOrder} className={styles.checkoutForm}>
              <label>نام تحویل‌گیرنده<input name="customer" defaultValue="سارا احمدی" required /></label>
              <label>شماره موبایل<input name="mobile" defaultValue="09121234567" required /></label>
              <label>استان<input name="province" defaultValue="تهران" required /></label>
              <label>شهر<input name="city" defaultValue="تهران" required /></label>
              <label className={styles.wideField}>نشانی<textarea name="address" defaultValue="خیابان ولیعصر، کوچه نمونه، پلاک ۱۲" required /></label>
              <label>کدپستی<input name="postal" defaultValue="1234567890" required /></label>
              <div className={styles.demoPayment}><span>پرداخت آزمایشی</span><b>{money(payable)} تومان</b><small>هیچ تراکنش بانکی انجام نمی‌شود.</small></div>
              <button className={styles.submitOrder} type="submit">ثبت سفارش و شبیه‌سازی پرداخت موفق</button>
            </form>
          </section>
        </div>
      )}

      {order && (
        <div className={styles.orderToast} role="status">
          <button type="button" onClick={() => setOrder(null)}>×</button>
          <span>✓</span>
          <div><b>سفارش دمو با موفقیت ثبت شد</b><p>{order.customer} · کد {order.code}</p><small>{order.createdAt} · {money(order.payable)} تومان</small></div>
        </div>
      )}
    </main>
  );
}
