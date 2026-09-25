"use client";

import { FormEvent, useMemo, useState } from "react";
import { categories, demoProducts, toman, type DemoProduct } from "./catalog";
import { ProductArtwork } from "./ProductArtwork";
import styles from "./professional-storefront.module.css";

type CartLine = DemoProduct & { quantity: number };
type DemoOrder = { code: string; customer: string; payable: number; createdAt: string };

const ADMIN_URL = process.env.NEXT_PUBLIC_NOOSHORA_ADMIN_URL ?? "https://nooshora-admin.vercel.app";

export default function ProfessionalStorefront() {
  const [category, setCategory] = useState("همه");
  const [query, setQuery] = useState("");
  const [cart, setCart] = useState<CartLine[]>([]);
  const [cartOpen, setCartOpen] = useState(false);
  const [checkoutOpen, setCheckoutOpen] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const [order, setOrder] = useState<DemoOrder | null>(null);

  const products = useMemo(() => {
    const normalized = query.trim();
    return demoProducts.filter((product) => {
      const matchesCategory = category === "همه" || product.category === category;
      const matchesQuery = !normalized || `${product.title} ${product.subtitle} ${product.origin}`.includes(normalized);
      return matchesCategory && matchesQuery;
    });
  }, [category, query]);

  const cartCount = cart.reduce((sum, line) => sum + line.quantity, 0);
  const subtotal = cart.reduce((sum, line) => sum + line.price * line.quantity, 0);
  const shipping = subtotal === 0 || subtotal >= 1500000 ? 0 : 75000;
  const payable = subtotal + shipping;

  function addToCart(product: DemoProduct) {
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
    const code = `DN-${new Intl.NumberFormat("fa-IR", { useGrouping: false }).format(
      Math.floor(100000 + Math.random() * 900000),
    )}`;
    setOrder({
      code,
      customer,
      payable,
      createdAt: new Intl.DateTimeFormat("fa-IR", {
        dateStyle: "medium",
        timeStyle: "short",
      }).format(new Date()),
    });
    setCart([]);
    setCheckoutOpen(false);
    setCartOpen(false);
  }

  return (
    <main className={styles.page}>
      <div className={styles.demoBar}>
        <span className={styles.demoDot} />
        <strong>پیش‌نمایش تعاملی مزه‌دونه</strong>
        <span>سبد و سفارش نمایشی‌اند؛ پرداخت واقعی انجام نمی‌شود.</span>
      </div>

      <header className={styles.header}>
        <a href="#top" className={styles.brand} aria-label="مزه‌دونه؛ صفحه نخست">
          <span className={styles.brandMark}>م</span>
          <span className={styles.brandType}>
            <b>مزه‌دونه</b>
            <small>خوش‌خوراکِ هر روز</small>
          </span>
        </a>

        <nav className={`${styles.nav} ${menuOpen ? styles.navOpen : ""}`} aria-label="ناوبری اصلی">
          <a href="#products" onClick={() => setMenuOpen(false)}>فروشگاه</a>
          <a href="#quality" onClick={() => setMenuOpen(false)}>چرا مزه‌دونه</a>
          <a href="#gift" onClick={() => setMenuOpen(false)}>جعبه‌های هدیه</a>
          <a href="#story" onClick={() => setMenuOpen(false)}>داستان برند</a>
          <a className={styles.mobileAdminLink} href={ADMIN_URL} target="_blank" rel="noreferrer">ورود به پنل مدیریت</a>
        </nav>

        <div className={styles.headerActions}>
          <label className={styles.searchBox}>
            <span aria-hidden="true">⌕</span>
            <input
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="جست‌وجوی محصول"
              aria-label="جست‌وجوی محصول"
            />
          </label>
          <a className={styles.adminLink} href={ADMIN_URL} target="_blank" rel="noreferrer">پنل مدیریت</a>
          <button className={styles.cartButton} type="button" onClick={() => setCartOpen(true)} aria-label={`سبد خرید، ${cartCount} کالا`}>
            <span aria-hidden="true">▢</span>
            <span className={styles.cartText}>سبد خرید</span>
            <b>{toman(cartCount)}</b>
          </button>
          <button
            className={styles.menuButton}
            type="button"
            aria-label={menuOpen ? "بستن منو" : "باز کردن منو"}
            aria-expanded={menuOpen}
            onClick={() => setMenuOpen((current) => !current)}
          >
            <span /><span />
          </button>
        </div>
      </header>

      <section className={styles.hero} id="top">
        <div className={styles.heroCopy}>
          <span className={styles.eyebrow}>یه مشت حالِ خوب، هر روز</span>
          <h1>خوشمزه‌هایی که<br /><em>حالِ دلت را خوب می‌کنند.</em></h1>
          <p>
            از مغزهای تازه تا میوه‌های آفتاب‌خورده و شیرینی‌های خونگیِ کم‌شکر؛ چیزهای ساده‌ای که روزت را خوش‌طعم می‌کنند.
          </p>
          <div className={styles.heroButtons}>
            <a href="#products" className={styles.primaryButton}>خوشمزه‌هامون رو ببین <span>←</span></a>
            <a href="#quality" className={styles.secondaryButton}>قصه‌ی خوشمزگی</a>
          </div>
          <div className={styles.heroProof}>
            <div><b>تازه</b><span>آماده‌سازی روزانه</span></div>
            <div><b>کم‌شکر</b><span>انتخاب‌های شیرین‌تر</span></div>
            <div><b>با عشق</b><span>بسته‌بندی مزه‌دونه</span></div>
          </div>
        </div>

        <div className={styles.heroVisual}>
          <span className={styles.heroCaption}>پرفروشِ این هفته</span>
          <ProductArtwork product={demoProducts[0]} hero />
          <div className={styles.heroPriceCard}>
            <small>پسته اکبری ممتاز</small>
            <b>{toman(demoProducts[0].price)} <span>تومان</span></b>
            <button type="button" onClick={() => addToCart(demoProducts[0])}>افزودن به سبد</button>
          </div>
          <div className={styles.heroOriginCard}>
            <span>مبدأ</span><b>رفسنجان</b><small>سری نمایشی NS-26</small>
          </div>
        </div>
      </section>

      <section className={styles.promiseStrip} aria-label="مزیت‌های خرید">
        <article><span>01</span><div><b>مواد اولیه ساده</b><small>خوش‌طعم و باکیفیت</small></div></article>
        <article><span>02</span><div><b>تازه آماده می‌شه</b><small>کوکی و لواشک روزانه</small></div></article>
        <article><span>03</span><div><b>کم‌شیرین و خوشمزه</b><small>برای میان‌وعده‌ی هر روز</small></div></article>
        <article><span>04</span><div><b>هدیه‌ی خوشحال‌کننده</b><small>ترکیب دلخواه برای عزیزانت</small></div></article>
      </section>

      <section className={styles.productsSection} id="products">
        <div className={styles.sectionHeading}>
          <div><span>خوشمزه‌های مزه‌دونه</span><h2>یه طعم خوب برای هر حال‌وهوا</h2></div>
          <p>محصول‌ها و قیمت‌ها در این پیش‌نمایش نمونه هستند.</p>
        </div>

        <div className={styles.catalogToolbar}>
          <div className={styles.categories} aria-label="فیلتر دسته‌بندی">
            {categories.map((item) => (
              <button
                key={item}
                type="button"
                className={category === item ? styles.activeCategory : ""}
                onClick={() => setCategory(item)}
              >{item}</button>
            ))}
          </div>
          <span className={styles.resultCount}>{toman(products.length)} محصول</span>
        </div>

        {products.length > 0 ? (
          <div className={styles.productGrid}>
            {products.map((product) => (
              <article className={styles.productCard} key={product.id}>
                <div className={`${styles.productVisual} ${styles[product.accent]}`}>
                  {product.badge && <span className={styles.badge}>{product.badge}</span>}
                  <ProductArtwork product={product} />
                  <span className={styles.originPill}>{product.origin}</span>
                </div>
                <div className={styles.productBody}>
                  <div className={styles.productMeta}><span>{product.category}</span><small>{product.packageLabel}</small></div>
                  <h3>{product.title}</h3>
                  <p>{product.subtitle}</p>
                  <div className={styles.productNote}>{product.note}</div>
                  <div className={styles.stockLine}>
                    <span><i style={{ width: `${Math.min(product.stock * 4, 100)}%` }} /></span>
                    <small>{toman(product.stock)} بسته آماده ارسال</small>
                  </div>
                  <div className={styles.priceRow}>
                    <div>
                      {product.oldPrice && <del>{toman(product.oldPrice)}</del>}
                      <b>{toman(product.price)} <small>تومان</small></b>
                    </div>
                    <button type="button" onClick={() => addToCart(product)} aria-label={`افزودن ${product.title} به سبد`}>
                      <span>افزودن</span><b>+</b>
                    </button>
                  </div>
                </div>
              </article>
            ))}
          </div>
        ) : (
          <div className={styles.emptyResults}>
            <b>محصولی با این جست‌وجو پیدا نشد.</b>
            <button type="button" onClick={() => { setQuery(""); setCategory("همه"); }}>نمایش همه محصولات</button>
          </div>
        )}
      </section>

      <section className={styles.qualitySection} id="quality">
        <div className={styles.qualityIntro}>
          <span>از انتخاب تا بسته‌بندی</span>
          <h2>خوشمزگی از مواد اولیه‌ی خوب شروع می‌شود.</h2>
          <p>مغزها را تازه انتخاب می‌کنیم، خوراکی‌های خونگی را با دقت آماده می‌کنیم و هر بسته را با عشق می‌فرستیم.</p>
          <a href={ADMIN_URL} target="_blank" rel="noreferrer">دیدن پنل مدیریتی <span>←</span></a>
        </div>
        <div className={styles.qualitySteps}>
          <article><b>۱</b><div><h3>دانه‌های خوب را دست‌چین می‌کنیم</h3><p>برای آجیل و مغزها سراغ محصول تازه و خوش‌طعم می‌رویم.</p></div></article>
          <article><b>۲</b><div><h3>با مواد ساده و خوش‌طعم</h3><p>در دستورهای خانگی، شیرینی را تا جای ممکن ملایم نگه می‌داریم.</p></div></article>
          <article><b>۳</b><div><h3>هر روز با حوصله آماده می‌کنیم</h3><p>کوکی و لواشک تازه، با بسته‌بندی مناسب راهی خانه‌ات می‌شوند.</p></div></article>
          <article><b>۴</b><div><h3>تا رسیدن به دست تو</h3><p>سفارش را مرتب و با دقت آماده می‌کنیم تا تجربه‌اش هم خوشمزه باشد.</p></div></article>
        </div>
      </section>

      <section className={styles.giftSection} id="gift">
        <div className={styles.giftVisual}>
          <ProductArtwork product={demoProducts[demoProducts.length - 1]} hero />
          <span className={styles.giftTag}>قابل شخصی‌سازی</span>
        </div>
        <div className={styles.giftCopy}>
          <span>هدیه شخصی و سازمانی</span>
          <h2>یک هدیه خوش‌ساخت، نه یک بسته آماده تکراری</h2>
          <p>ترکیب محصولات، بودجه، رنگ بسته، کارت تبریک و زمان تحویل را مشخص کن؛ درخواست از پنل پیگیری و قیمت‌گذاری می‌شود.</p>
          <div className={styles.giftOptions}><span>ترکیب اختصاصی</span><span>کارت با نشان دلخواه</span><span>ارسال چندمقصدی</span></div>
          <button type="button" onClick={() => addToCart(demoProducts[demoProducts.length - 1])}>افزودن جعبه نمونه به سبد</button>
        </div>
      </section>

      <section className={styles.storySection} id="story">
        <div className={styles.storyQuote}>
          <span>چرا مزه‌دونه؟</span>
          <blockquote>«یه میان‌وعده‌ی خوش‌طعم می‌تونه حالِ یک روز معمولی رو عوض کنه.»</blockquote>
        </div>
        <div className={styles.storyCopy}>
          <p>مزه‌دونه برای لحظه‌های کوچیک و خوشمزه ساخته شده؛ از مشت آجیل سرِ کار تا کوکی خونگی کنار چای.</p>
          <a href={ADMIN_URL} target="_blank" rel="noreferrer">دیدن پنل مدیریت مزه‌دونه</a>
        </div>
      </section>

      <footer className={styles.footer}>
        <div className={styles.footerBrand}><span className={styles.brandMark}>م</span><div><b>مزه‌دونه</b><small>خوش‌خوراکِ هر روز</small></div></div>
        <div className={styles.footerLinks}><a href="#products">محصولات</a><a href="#quality">خوشمزه‌های کم‌شکر</a><a href="#gift">جعبه‌های هدیه</a></div>
        <div className={styles.footerNote}><b>نسخه دموی تعاملی</b><small>بدون پرداخت، ارسال یا ثبت داده واقعی</small></div>
      </footer>

      {menuOpen && <button type="button" className={styles.mobileMenuBackdrop} aria-label="بستن منو" onClick={() => setMenuOpen(false)} />}

      {cartOpen && (
        <div className={styles.overlay} role="presentation" onMouseDown={(event) => event.target === event.currentTarget && setCartOpen(false)}>
          <aside className={styles.cartDrawer} role="dialog" aria-modal="true" aria-labelledby="cart-title">
            <div className={styles.drawerHeader}>
              <div><small>سبد خرید دمو</small><h2 id="cart-title">انتخاب‌های شما</h2></div>
              <button type="button" onClick={() => setCartOpen(false)} aria-label="بستن سبد">×</button>
            </div>
            <div className={styles.cartLines}>
              {cart.length === 0 ? (
                <div className={styles.emptyCart}>
                  <span>۰</span><b>سبد خرید هنوز خالی است.</b><p>یک بسته را از محصولات منتخب به سبد اضافه کن.</p>
                  <button type="button" onClick={() => setCartOpen(false)}>بازگشت به فروشگاه</button>
                </div>
              ) : cart.map((line) => (
                <article className={styles.cartLine} key={line.id}>
                  <div className={`${styles.cartThumb} ${styles[line.accent]}`}><ProductArtwork product={line} /></div>
                  <div className={styles.cartLineInfo}><b>{line.title}</b><small>{line.packageLabel}</small><span>{toman(line.price * line.quantity)} تومان</span></div>
                  <div className={styles.quantityControl}>
                    <button type="button" onClick={() => changeQuantity(line.id, 1)} aria-label="افزایش تعداد">+</button>
                    <b>{toman(line.quantity)}</b>
                    <button type="button" onClick={() => changeQuantity(line.id, -1)} aria-label="کاهش تعداد">−</button>
                  </div>
                </article>
              ))}
            </div>
            <div className={styles.cartSummary}>
              <div><span>جمع محصولات</span><b>{toman(subtotal)} تومان</b></div>
              <div><span>ارسال</span><b>{shipping === 0 ? "رایگان" : `${toman(shipping)} تومان`}</b></div>
              <small>ارسال برای خرید بالای ۱٬۵۰۰٬۰۰۰ تومان در این دمو رایگان است.</small>
              <div className={styles.payableRow}><span>مبلغ قابل پرداخت</span><b>{toman(payable)} تومان</b></div>
              <button className={styles.checkoutButton} type="button" disabled={cart.length === 0} onClick={() => setCheckoutOpen(true)}>
                ادامه و ثبت سفارش آزمایشی
              </button>
            </div>
          </aside>
        </div>
      )}

      {checkoutOpen && (
        <div className={styles.modalOverlay} role="presentation" onMouseDown={(event) => event.target === event.currentTarget && setCheckoutOpen(false)}>
          <form className={styles.checkoutModal} onSubmit={submitDemoOrder} role="dialog" aria-modal="true" aria-labelledby="checkout-title">
            <div className={styles.drawerHeader}>
              <div><small>مرحله نهایی دمو</small><h2 id="checkout-title">اطلاعات تحویل</h2></div>
              <button type="button" onClick={() => setCheckoutOpen(false)} aria-label="بستن فرم">×</button>
            </div>
            <div className={styles.formGrid}>
              <label><span>نام و نام خانوادگی</span><input name="customer" required placeholder="مثلاً حمیدرضا پاکپور" /></label>
              <label><span>شماره موبایل</span><input name="mobile" required inputMode="tel" pattern="09[0-9]{9}" placeholder="۰۹۱۲۱۲۳۴۵۶۷" /></label>
              <label><span>شهر</span><input name="city" required placeholder="تهران" /></label>
              <label><span>کد پستی</span><input name="postalCode" inputMode="numeric" placeholder="۱۲۳۴۵۶۷۸۹۰" /></label>
              <label className={styles.fullField}><span>نشانی تحویل</span><textarea name="address" required rows={3} placeholder="نشانی کامل برای سناریوی آزمایشی" /></label>
              <label className={styles.fullField}><span>یادداشت سفارش</span><input name="note" placeholder="اختیاری؛ مثلاً کارت تبریک داخل بسته قرار گیرد" /></label>
            </div>
            <div className={styles.demoPaymentNotice}><b>پرداخت شبیه‌سازی می‌شود.</b><span>هیچ اطلاعات بانکی دریافت نخواهد شد.</span></div>
            <div className={styles.checkoutFooter}><div><small>مبلغ دمو</small><b>{toman(payable)} تومان</b></div><button type="submit">ثبت سفارش و شبیه‌سازی پرداخت</button></div>
          </form>
        </div>
      )}

      {order && (
        <div className={styles.modalOverlay} role="presentation">
          <section className={styles.successModal} role="dialog" aria-modal="true" aria-labelledby="success-title">
            <span className={styles.successMark}>✓</span>
            <small>سفارش آزمایشی ثبت شد</small>
            <h2 id="success-title">ممنون {order.customer}</h2>
            <p>این سناریو فقط جریان تجربه مشتری را نمایش می‌دهد و هیچ تراکنش یا ارسال واقعی انجام نشده است.</p>
            <div className={styles.orderReceipt}>
              <div><span>کد سفارش</span><b>{order.code}</b></div>
              <div><span>زمان ثبت</span><b>{order.createdAt}</b></div>
              <div><span>مبلغ</span><b>{toman(order.payable)} تومان</b></div>
            </div>
            <div className={styles.successActions}><button type="button" onClick={() => setOrder(null)}>بازگشت به فروشگاه</button><a href={ADMIN_URL} target="_blank" rel="noreferrer">دیدن سفارش‌ها در پنل دمو</a></div>
          </section>
        </div>
      )}
    </main>
  );
}
