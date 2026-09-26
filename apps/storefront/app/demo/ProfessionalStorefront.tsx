"use client";

import { useMemo, useState } from "react";
import { categories, demoProducts, toman, type DemoProduct } from "./catalog";
import { ProductArtwork } from "./ProductArtwork";
import styles from "./professional-storefront.module.css";
import { useCart } from "../cart-context";

export default function ProfessionalStorefront() {
  const [category, setCategory] = useState("همه");
  const [query, setQuery] = useState("");
  const { cart, subtotal, shipping, total: payable, add, change } = useCart();
  const [cartOpen, setCartOpen] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);

  const products = useMemo(() => {
    const normalized = query.trim();
    return demoProducts.filter((product) => {
      const matchesCategory = category === "همه" || product.category === category;
      const matchesQuery = !normalized || `${product.title} ${product.subtitle} ${product.origin}`.includes(normalized);
      return matchesCategory && matchesQuery;
    });
  }, [category, query]);

  const cartCount = cart.reduce((sum, line) => sum + line.quantity, 0);

  return (
    <main className={styles.page}>
      <div className={styles.demoBar}>
        <span className={styles.demoDot} />
        <strong>پیش‌نمایش تعاملی مزه‌دونه</strong>
        <span>سبد و سفارش نمایشی‌اند؛ پرداخت واقعی انجام نمی‌شود.</span>
      </div>

      <header className={styles.header}>
        <a href="#top" className={styles.brand} aria-label="مزه‌دونه؛ صفحه نخست">
          <span className={styles.brandMark}><img src="/mazedoone-mark.svg" alt="" width="48" height="48" /></span>
          <span className={styles.brandType}>
            <b>مزه‌دونه</b>
            <small>خوش‌خوراکِ هر روز</small>
          </span>
        </a>

        <nav className={`${styles.nav} ${menuOpen ? styles.navOpen : ""}`} aria-label="ناوبری اصلی">
          <a href="/shop" onClick={() => setMenuOpen(false)}>همهٔ محصولات</a>
          <a href="/shop?category=آجیل و مغزها" onClick={() => setMenuOpen(false)}>آجیل و مغزها</a>
          <a href="/shop?category=میوه خشک" onClick={() => setMenuOpen(false)}>میوه خشک</a>
          <a href="#quality" onClick={() => setMenuOpen(false)}>چرا مزه‌دونه</a>
          <a href="#gift" onClick={() => setMenuOpen(false)}>جعبه‌های هدیه</a>
          <a href="/about" onClick={() => setMenuOpen(false)}>داستان برند</a>
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
            <a href="/shop" className={styles.primaryButton}>خوشمزه‌هامون رو ببین <span>←</span></a>
            <a href="/about" className={styles.secondaryButton}>قصه‌ی خوشمزگی</a>
          </div>
          <div className={styles.heroProof}>
            <div><b>تازه</b><span>آماده‌سازی روزانه</span></div>
            <div><b>کم‌شکر</b><span>انتخاب‌های شیرین‌تر</span></div>
            <div><b>با عشق</b><span>بسته‌بندی مزه‌دونه</span></div>
          </div>
        </div>

        <div className={styles.heroVisual}>
          <span className={styles.heroCaption}>پرفروشِ این هفته</span>
          <div className={styles.heroPackagingHalo} aria-hidden="true" />
          <figure className={`${styles.heroPackaging} ${styles.heroPackagingBack}`} aria-hidden="true"><img src="/products/dragon-box-new.webp" alt="" /></figure>
          <figure className={`${styles.heroPackaging} ${styles.heroPackagingSide}`} aria-hidden="true"><img src="/products/almond-pouch-new.webp" alt="" /></figure>
          <figure className={`${styles.heroPackaging} ${styles.heroPackagingWalnut}`} aria-hidden="true"><img src="/products/walnut-character-new.webp" alt="" /></figure>
          <figure className={`${styles.heroPackaging} ${styles.heroPackagingFront}`} aria-hidden="true"><img src="/products/pistachio-pouch-new.webp" alt="" /></figure>
          <figure className={`${styles.heroPackaging} ${styles.heroPackagingGift}`} aria-hidden="true"><img src="/products/gift-boxes-new.webp" alt="" /></figure>
          <span className={`${styles.heroSpark} ${styles.heroSparkOne}`} aria-hidden="true">✦</span>
          <span className={`${styles.heroSpark} ${styles.heroSparkTwo}`} aria-hidden="true">✦</span>
          <div className={styles.heroPriceCard}>
            <small>پسته اکبری ممتاز</small>
            <b>{toman(demoProducts[0].price)} <span>تومان</span></b>
            <button type="button" onClick={() => { add(demoProducts[0]); setCartOpen(true); }}>افزودن به سبد</button>
          </div>
          <div className={styles.heroOriginCard}>
            <span>مبدأ</span><b>رفسنجان</b><small>سری نمایشی NS-26</small>
          </div>
        </div>
      </section>

      <section className={styles.packagingShowcase} aria-labelledby="packaging-title">
        <div className={styles.packagingShowcaseCopy}>
          <span className={styles.eyebrow}>هویت تازهٔ مزه‌دونه</span>
          <h2 id="packaging-title">هر محصول، یک شخصیت و یک بسته‌بندی</h2>
          <p>رنگ و کاراکتر هر محصول متفاوت است؛ پنجرهٔ شفاف، لوگوتایپ و زبان سبز صدری همه‌چیز را یکپارچه نگه می‌دارند.</p>
          <a className={styles.secondaryButton} href="#products">دیدن محصولات</a>
        </div>
        <div className={styles.packagingRail} aria-label="نمونه بسته‌بندی‌های مزه‌دونه">
          {[
            ["/products/pistachio-pouch-new.webp", "پسته"],
            ["/products/almond-pouch-new.webp", "بادام"],
            ["/products/walnut-character-new.webp", "گردو"],
            ["/products/dragon-box-new.webp", "کوکی کاکائویی"],
            ["/products/gift-boxes-new.webp", "پک یک‌کیلویی"],
            ["/products/cookie-boxes-new.webp", "پک کوکی"],
          ].map(([src, label]) => (
            <figure className={styles.packagingTile} key={src}>
              <img src={src} alt={`بسته‌بندی ${label}`} loading="lazy" />
              <figcaption>{label}</figcaption>
            </figure>
          ))}
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
          <a href="/shop">دیدن همهٔ محصولات ←</a>
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
                  <h3><a href={`/product/${product.id}`}>{product.title}</a></h3>
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
                    <button type="button" onClick={() => { add(product); setCartOpen(true); }} aria-label={`افزودن ${product.title} به سبد`}>
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
          <a href="/shipping">روش و زمان ارسال <span>←</span></a>
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
          <button type="button" onClick={() => { add(demoProducts[demoProducts.length - 1]); setCartOpen(true); }}>افزودن جعبه نمونه به سبد</button>
        </div>
      </section>

      <section className={styles.storySection} id="story">
        <div className={styles.storyQuote}>
          <span>چرا مزه‌دونه؟</span>
          <blockquote>«یه میان‌وعده‌ی خوش‌طعم می‌تونه حالِ یک روز معمولی رو عوض کنه.»</blockquote>
        </div>
        <div className={styles.storyCopy}>
          <p>مزه‌دونه برای لحظه‌های کوچیک و خوشمزه ساخته شده؛ از مشت آجیل سرِ کار تا کوکی خونگی کنار چای.</p>
          <a href="/about">بیشتر دربارهٔ مزه‌دونه بخوان</a>
        </div>
      </section>

      <footer className={styles.footer}>
        <div className={styles.footerBrand}><span className={styles.brandMark}><img src="/mazedoone-mark.svg" alt="" width="48" height="48" /></span><div><b>مزه‌دونه</b><small>خوش‌خوراکِ هر روز</small></div></div>
        <div className={styles.footerLinks}><a href="/shop">همهٔ محصولات</a><a href="/faq">پرسش‌های پرتکرار</a><a href="/shipping">روش ارسال</a><a href="/about">دربارهٔ ما</a></div>
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
                    <button type="button" onClick={() => change(line.id, 1)} aria-label="افزایش تعداد">+</button>
                    <b>{toman(line.quantity)}</b>
                    <button type="button" onClick={() => change(line.id, -1)} aria-label="کاهش تعداد">−</button>
                  </div>
                </article>
              ))}
            </div>
            <div className={styles.cartSummary}>
              <div><span>جمع محصولات</span><b>{toman(subtotal)} تومان</b></div>
              <div><span>ارسال</span><b>{shipping === 0 ? "رایگان" : `${toman(shipping)} تومان`}</b></div>
              <small>ارسال برای خرید بالای ۱٬۵۰۰٬۰۰۰ تومان در این دمو رایگان است.</small>
              <div className={styles.payableRow}><span>مبلغ قابل پرداخت</span><b>{toman(payable)} تومان</b></div>
              <a className={styles.checkoutButton} aria-disabled={cart.length === 0} href={cart.length ? "/checkout" : "/shop"}>
                ادامه به صفحهٔ اطلاعات و ارسال
              </a>
              <a className={styles.fullCartLink} href="/cart">مشاهدهٔ سبد خرید کامل</a>
            </div>
          </aside>
        </div>
      )}
    </main>
  );
}
