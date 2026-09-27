"use client";

import { useEffect, useMemo, useState } from "react";
import { categories, demoProducts, toman, type DemoProduct } from "./catalog";
import { ProductArtwork } from "./ProductArtwork";
import styles from "./professional-storefront.module.css";
import { useCart } from "../cart-context";

const categoryMeta: Record<string, { icon: string; hint: string }> = {
  "آجیل و مغزها": { icon: "🥜", hint: "تازه و دست‌چین" },
  "میوه خشک": { icon: "🍊", hint: "آفتاب‌خورده" },
  "لواشک و ترش‌مزه": { icon: "🍓", hint: "ترش و ملس" },
  "کوکی و شیرینی": { icon: "🍪", hint: "پخت روز" },
  "کم‌شکر و پروتئینی": { icon: "🍫", hint: "خوش‌طعم و سبک" },
  "هدیه": { icon: "🎁", hint: "برای خوشحال‌کردن" },
};

const categoryAliases: Record<string, string> = {
  "پسته": "آجیل و مغزها",
  "گردو": "آجیل و مغزها",
  "شکلات": "کم‌شکر و پروتئینی",
  "کوکی‌ها": "کوکی و شیرینی",
};

function cartKey(product: DemoProduct) {
  return product.sku ?? product.id;
}

export default function ProfessionalStorefront() {
  const [category, setCategory] = useState("همه");
  const [query, setQuery] = useState("");
  const [favorites, setFavorites] = useState<string[]>([]);
  const [favoritesOnly, setFavoritesOnly] = useState(false);
  const [cartOpen, setCartOpen] = useState(false);
  const [toast, setToast] = useState<string | null>(null);
  const { cart, count: cartCount, subtotal, shipping, total: payable, add, change } = useCart();

  useEffect(() => {
    try {
      const stored = JSON.parse(localStorage.getItem("mazedooneh-favorites-v1") ?? "[]");
      if (Array.isArray(stored)) setFavorites(stored.filter((item): item is string => typeof item === "string"));
    } catch {
      localStorage.removeItem("mazedooneh-favorites-v1");
    }
  }, []);

  useEffect(() => {
    localStorage.setItem("mazedooneh-favorites-v1", JSON.stringify(favorites));
  }, [favorites]);

  useEffect(() => {
    if (!toast) return;
    const timer = window.setTimeout(() => setToast(null), 2600);
    return () => window.clearTimeout(timer);
  }, [toast]);

  const products = useMemo(() => {
    const normalized = query.trim().toLocaleLowerCase("fa");
    return demoProducts.filter((product) => {
      const matchesCategory = category === "همه" || product.category === category;
      const searchable = `${product.title} ${product.subtitle} ${product.origin} ${product.category}`.toLocaleLowerCase("fa");
      return matchesCategory && (!favoritesOnly || favorites.includes(product.id)) && (!normalized || searchable.includes(normalized));
    });
  }, [category, favorites, favoritesOnly, query]);

  function announceAdd(product: DemoProduct) {
    add(product);
    setToast(`«${product.title}» به سبد اضافه شد.`);
  }

  function toggleFavorite(product: DemoProduct) {
    setFavorites((current) => current.includes(product.id)
      ? current.filter((id) => id !== product.id)
      : [...current, product.id]);
  }

  function selectCategory(value: string) {
    setCategory(value);
    setFavoritesOnly(false);
    document.getElementById("products")?.scrollIntoView({ behavior: "smooth", block: "start" });
  }

  return (
    <main className={styles.page} id="top">
      <div className={styles.announcement}>ارسال رایگان برای خریدهای بالای ۱٬۵۰۰٬۰۰۰ تومان <span>•</span> تازه‌چین، خوش‌طعم، آمادهٔ رسیدن</div>

      <header className={styles.siteHeader}>
        <a href="#top" className={styles.brand} aria-label="مزه‌دونه؛ صفحهٔ اصلی">
          <span className={styles.brandMark}><img src="/mazedoone-mark.svg" alt="" width="52" height="52" /></span>
          <span><strong>مزه‌دونه</strong><small>خوش‌خوراکِ هر روز</small></span>
        </a>
        <nav className={styles.desktopNav} aria-label="ناوبری اصلی"><a href="#products">محصولات</a><a href="#categories">دسته‌بندی‌ها</a><a href="#story">داستان ما</a></nav>
        <div className={styles.headerActions}>
          <label className={styles.searchBox}><span aria-hidden="true">⌕</span><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="جست‌وجوی محصولات..." aria-label="جست‌وجوی محصولات" /></label>
          <button className={styles.accountButton} type="button" onClick={() => setToast("ورود به حساب کاربری به‌زودی فعال می‌شود.")} aria-label="حساب کاربری">♙</button>
          <button className={styles.cartButton} type="button" onClick={() => setCartOpen(true)} aria-label={`سبد خرید، ${cartCount} کالا`}><span aria-hidden="true">🛒</span><b>{toman(cartCount)}</b></button>
        </div>
      </header>

      <section className={styles.hero} aria-labelledby="hero-title">
        <div className={styles.heroCopy}><span className={styles.eyebrow}>یک مشت حال خوب، آمادهٔ خوردن</span><h1 id="hero-title">خوشمزه‌ها<br /><em>اینجان</em></h1><p>از پسته و مغزهای تازه تا کوکی‌های شکلاتی؛ انتخاب‌هایی که قرار است حال یک روز معمولی را بهتر کنند.</p><div className={styles.heroActions}><button type="button" className={styles.primaryButton} onClick={() => selectCategory("همه")}>شروع مزه‌گردی <span>←</span></button><a className={styles.secondaryButton} href="#story">قصهٔ مزه‌دونه</a></div><div className={styles.heroProof}><span><b>تازه</b><small>آماده‌سازی روزانه</small></span><span><b>خوش‌ساخت</b><small>بسته‌بندی باحال</small></span><span><b>مطمئن</b><small>ارسال سراسری</small></span></div></div>
        <div className={styles.heroVisual} aria-label="بسته‌بندی‌های مزه‌دونه"><div className={styles.heroGlow} aria-hidden="true" /><figure className={`${styles.heroPack} ${styles.heroPackBack}`}><img src="/products/dragon-box-new.webp" alt="بستهٔ کوکی شکلاتی مزه‌دونه" /></figure><figure className={`${styles.heroPack} ${styles.heroPackSide}`}><img src="/products/almond-pouch-new.webp" alt="بستهٔ بادام مزه‌دونه" /></figure><figure className={`${styles.heroPack} ${styles.heroPackFront}`}><img src="/products/pistachio-pouch-new.webp" alt="بستهٔ پستهٔ مزه‌دونه" /></figure><span className={`${styles.heroLeaf} ${styles.heroLeafOne}`} aria-hidden="true">✦</span><span className={`${styles.heroLeaf} ${styles.heroLeafTwo}`} aria-hidden="true">✦</span></div>
      </section>

      <section className={styles.categorySection} id="categories" aria-labelledby="category-title"><div className={styles.sectionHeading}><div><span>برای هر هوس، یک انتخاب</span><h2 id="category-title">مزه‌گردی را از کجا شروع کنیم؟</h2></div><a href="#products">همهٔ محصولات ←</a></div><div className={styles.categoryRail}>{["کوکی‌ها", "آجیل و مغزها", "پسته", "گردو", "شکلات"].map((item) => { const meta = categoryMeta[categoryAliases[item]] ?? { icon: "🥜", hint: "خوشمزه و تازه" }; const value = categoryAliases[item] ?? item; return <button className={`${styles.categoryCard} ${category === value ? styles.categoryCardActive : ""}`} type="button" key={item} onClick={() => selectCategory(value)}><span className={styles.categoryIcon}>{meta.icon}</span><strong>{item}</strong><small>{meta.hint}</small><span className={styles.categoryArrow}>←</span></button>; })}</div></section>

      <section className={styles.trustStrip} aria-label="مزیت‌های خرید از مزه‌دونه"><div><span>🚚</span><strong>ارسال سریع<small>به سراسر ایران</small></strong></div><div><span>🌿</span><strong>تازه و باکیفیت<small>مستقیم از بهترین‌ها</small></strong></div><div><span>🛡️</span><strong>پرداخت امن<small>با خیال راحت خرید کن</small></strong></div></section>

      <section className={styles.productSection} id="products" aria-labelledby="products-title"><div className={styles.sectionHeading}><div><span>انتخاب‌های محبوب</span><h2 id="products-title">پرفروش‌ترین‌ها</h2></div><a href="/shop">مشاهدهٔ همه ←</a></div><div className={styles.productToolbar}><div className={styles.chips}>{categories.slice(0, 5).map((item) => <button type="button" className={category === item ? styles.chipActive : ""} key={item} onClick={() => setCategory(item)}>{item}</button>)}</div><span>{toman(products.length)} محصول</span></div>{products.length === 0 ? <div className={styles.emptyState}><span>🔎</span><strong>چیزی با این جست‌وجو پیدا نشد.</strong><p>اسم محصول یا دستهٔ دیگری را امتحان کن.</p><button type="button" onClick={() => { setQuery(""); setCategory("همه"); }}>نمایش همهٔ محصولات</button></div> : <div className={styles.productGrid}>{products.map((product) => { const key = cartKey(product); const quantity = cart.find((line) => (line.sku ?? line.id) === key)?.quantity ?? 0; const favorite = favorites.includes(product.id); return <article className={styles.productCard} key={product.id}><div className={`${styles.productVisual} ${styles[product.accent]}`}><button type="button" className={`${styles.favoriteButton} ${favorite ? styles.favoriteActive : ""}`} onClick={() => toggleFavorite(product)} aria-label={favorite ? `حذف ${product.title} از علاقه‌مندی‌ها` : `افزودن ${product.title} به علاقه‌مندی‌ها`}>{favorite ? "♥" : "♡"}</button>{product.badge && <span className={styles.productBadge}>{product.badge}</span>}<a href={`/product/${product.id}`} className={styles.productImageLink}><ProductArtwork product={product} /></a></div><div className={styles.productBody}><div className={styles.productMeta}><span>{product.category}</span><small>★ ۴٫۸</small></div><h3><a href={`/product/${product.id}`}>{product.title}</a></h3><p>{product.packageLabel}</p><div className={styles.priceLine}><strong>{toman(product.price)} <small>تومان</small></strong><span className={product.stock < 8 ? styles.lowStock : ""}>{product.stock > 0 ? "موجود" : "ناموجود"}</span></div>{quantity > 0 ? <div className={styles.quantityBar}><button type="button" onClick={() => change(key, 1)} disabled={quantity >= product.stock}>+</button><b>{toman(quantity)}</b><button type="button" onClick={() => change(key, -1)}>−</button><span>در سبد شما</span></div> : <button type="button" className={styles.addToCart} onClick={() => announceAdd(product)} disabled={product.stock === 0}>افزودن به سبد <span>🛒</span></button>}</div></article>; })}</div>}</section>

      <section className={styles.specialOffer} id="offer"><div className={styles.offerArtwork}><img src="/products/dragon-box-new.webp" alt="جعبهٔ کوکی شکلاتی مزه‌دونه" /></div><div><span>پیشنهاد امروز</span><h2>یک استراحت شکلاتی<br />برای وسط روز</h2><p>کوکی‌های شکلاتی مزه‌دونه با مواد اولیهٔ طبیعی و تکه‌های شکلات واقعی.</p><button type="button" onClick={() => announceAdd(demoProducts.find((product) => product.id === "protein-cookie") ?? demoProducts[0])}>همین حالا سفارش بده <b>←</b></button></div></section>
      <section className={styles.storySection} id="story"><div><span>داستان مزه‌دونه</span><h2>ما باور داریم<br />مزه باید حال آدم را خوب کند.</h2></div><p>از انتخاب دانه‌های خوب تا لحظه‌ای که بسته را باز می‌کنی، مزه‌دونه برای همان لبخند کوچک ساخته شده؛ ساده، خوش‌طعم و صمیمی.</p></section>
      <footer className={styles.footer}><div className={styles.footerBrand}><span className={styles.brandMark}><img src="/mazedoone-mark.svg" alt="" width="48" height="48" /></span><div><strong>مزه‌دونه</strong><small>خوش‌خوراکِ هر روز</small></div></div><div className={styles.footerLinks}><a href="/shop">محصولات</a><a href="/about">دربارهٔ ما</a><a href="/shipping">روش ارسال</a><a href="/faq">پرسش‌های پرتکرار</a></div><p>هر روز، یک مشت حال خوب.</p></footer>
      <nav className={styles.mobileNav} aria-label="ناوبری موبایل"><a className={styles.mobileNavActive} href="#top"><span>⌂</span>خانه</a><a href="#categories"><span>▦</span>دسته‌بندی‌ها</a><button type="button" onClick={() => { setFavoritesOnly(true); document.getElementById("products")?.scrollIntoView({ behavior: "smooth" }); }}><span>♡</span>علاقه‌مندی‌ها</button><button type="button" onClick={() => setCartOpen(true)}><span>🛒<i>{toman(cartCount)}</i></span>سبد خرید</button><button type="button" onClick={() => setToast("ورود به حساب کاربری به‌زودی فعال می‌شود.")}><span>♙</span>پروفایل</button></nav>
      {toast && <div className={styles.toast} role="status"><span>✓</span>{toast}<button type="button" onClick={() => setCartOpen(true)}>مشاهدهٔ سبد</button></div>}
      {cartOpen && <div className={styles.overlay} role="presentation" onMouseDown={(event) => event.target === event.currentTarget && setCartOpen(false)}><aside className={styles.cartDrawer} role="dialog" aria-modal="true" aria-labelledby="cart-title"><div className={styles.drawerHeader}><div><small>سبد خرید شما</small><h2 id="cart-title">انتخاب‌های خوشمزه</h2></div><button type="button" onClick={() => setCartOpen(false)} aria-label="بستن سبد">×</button></div><div className={styles.cartLines}>{cart.length === 0 ? <div className={styles.emptyCart}><span>🛒</span><b>سبد خرید هنوز خالی است.</b><p>یک بستهٔ خوشمزه برای شروع انتخاب کن.</p><button type="button" onClick={() => setCartOpen(false)}>بازگشت به فروشگاه</button></div> : cart.map((line) => <article className={styles.cartLine} key={line.sku ?? line.id}><div className={`${styles.cartThumb} ${styles[line.accent]}`}><ProductArtwork product={line} /></div><div className={styles.cartLineInfo}><b>{line.title}</b><small>{line.packageLabel}</small><span>{toman(line.price * line.quantity)} تومان</span></div><div className={styles.quantityControl}><button type="button" onClick={() => change(line.sku ?? line.id, 1)} aria-label="افزایش تعداد">+</button><b>{toman(line.quantity)}</b><button type="button" onClick={() => change(line.sku ?? line.id, -1)} aria-label="کاهش تعداد">−</button></div></article>)}</div><div className={styles.cartSummary}><div><span>جمع محصولات</span><b>{toman(subtotal)} تومان</b></div><div><span>ارسال</span><b>{shipping === 0 ? "رایگان" : `${toman(shipping)} تومان`}</b></div><div className={styles.payableRow}><span>مبلغ قابل پرداخت</span><b>{toman(payable)} تومان</b></div><a className={styles.checkoutButton} aria-disabled={cart.length === 0} href={cart.length ? "/checkout" : "#top"}>ادامه به اطلاعات ارسال</a><a className={styles.fullCartLink} href="/cart">مشاهدهٔ سبد کامل</a></div></aside></div>}
    </main>
  );
}
