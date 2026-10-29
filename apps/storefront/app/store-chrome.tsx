"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { toman, type DemoProduct } from "./demo/catalog";
import { ProductArtwork } from "./demo/ProductArtwork";
import { useCart } from "./cart-context";
import styles from "./store-pages.module.css";
import { useCatalog } from "./catalog-context";
import { SocialSupport } from "./social-support";
import { ProductCartControl } from "./product-cart-control";
import { EnamadSeal } from "./enamad-seal";

function CartGlyph() {
  return <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d="M3.5 4.5h2l1.8 10.2h9.8l2-7.2H6.2" /><circle cx="9" cy="19" r="1.35" /><circle cx="17" cy="19" r="1.35" /></svg>;
}

export function BrandLogo({ light = false }: { light?: boolean }) {
  return (
    <a className={`${styles.brand} ${light ? styles.brandLight : ""}`} href="/" aria-label="مزه‌دونه، صفحهٔ اصلی">
      <img src="/mazedoone-mark.svg" alt="" width={46} height={46} />
      <span><strong>مزه‌دونه</strong><small>خوش‌خوراکِ هر روز</small></span>
    </a>
  );
}

export function StoreHeader() {
  const { categories: catalogCategories } = useCatalog();
  const { count, ready, freeShippingLimit, pricingReady } = useCart();
  const [query, setQuery] = useState("");
  const [menuOpen, setMenuOpen] = useState(false);
  const router = useRouter();
  function search(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    router.push(`/shop?q=${encodeURIComponent(query.trim())}`);
  }
  return (
    <>
      <div className={styles.announcement}>{pricingReady && freeShippingLimit ? `ارسال رایگان از ${toman(freeShippingLimit)} تومان با روش ارسال پیش‌فرض` : "خوش‌خوراکِ هر روز"} <span>·</span> آماده‌سازی تازه و روزانه</div>
      <header className={styles.siteHeader}>
        <BrandLogo />
        <button className={styles.menuToggle} type="button" aria-expanded={menuOpen} aria-label={menuOpen ? "بستن فهرست" : "باز کردن فهرست"} onClick={() => setMenuOpen((open) => !open)}>{menuOpen ? "×" : "☰"}</button>
        <nav className={`${styles.nav} ${menuOpen ? styles.navOpen : ""}`} aria-label="ناوبری فروشگاه">
          <form className={styles.mobileMenuSearch} onSubmit={(event) => { search(event); setMenuOpen(false); }} role="search">
            <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="جست‌وجوی محصولات" aria-label="جست‌وجوی محصولات" />
            <button aria-label="جست‌وجو">جست‌وجو</button>
          </form>
          <a href="/shop" onClick={() => setMenuOpen(false)}>همهٔ محصولات</a>
          <a href="/gifts" onClick={() => setMenuOpen(false)}>راهنمای انتخاب هدیه</a>
          {catalogCategories.slice(0, 3).map((name) => <a key={name} href={`/shop?category=${encodeURIComponent(name)}`} onClick={() => setMenuOpen(false)}>{name}</a>)}
          <a href="/about" onClick={() => setMenuOpen(false)}>داستان ما</a>
        </nav>
        <div className={styles.headerActions}>
          <form className={styles.search} onSubmit={search} role="search"><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="دنبال چه مزه‌ای هستی؟" aria-label="جست‌وجوی محصولات" /><button aria-label="جست‌وجو">⌕</button></form>
          <a href="/cart" className={styles.cartLink} aria-label={ready ? `سبد خرید، ${count} کالا` : "در حال بارگذاری سبد خرید"}><span className={styles.cartGlyph}><CartGlyph /></span><em>سبد خرید</em><b>{ready ? toman(count) : "…"}</b></a>
        </div>
      </header>
      {menuOpen && <button className={styles.menuScrim} type="button" aria-label="بستن فهرست" onClick={() => setMenuOpen(false)} />}
    </>
  );
}

export function StoreFooter() {
  const { categories: catalogCategories } = useCatalog();
  return <footer className={styles.footer}>
    <img className={styles.footerArt} src="/products/gift-boxes-new.webp" alt="" aria-hidden="true" loading="lazy" />
    <div className={styles.footerMain}>
      <div><BrandLogo light /><p>یک مشت خوراکی خوش‌طعم برای لحظه‌های کوچک روزمره؛ تازه، ساده و باحوصله آماده‌شده.</p></div>
      <div><strong>خرید</strong><a href="/shop">همهٔ محصولات</a>{catalogCategories.slice(0, 3).map((name) => <a key={name} href={`/shop?category=${encodeURIComponent(name)}`}>{name}</a>)}</div>
        <div><strong>راهنما</strong><a href="/gifts">راهنمای انتخاب هدیه</a><a href="/shipping">روش و زمان ارسال</a><a href="/returns">بازگشت و پیگیری</a><a href="/faq">پرسش‌های پرتکرار</a><a href="/corporate-sales">فروش سازمانی</a><a href="/contact">پیام به مزه‌دونه</a><a href="/privacy">حریم خصوصی</a><a href="/terms">شرایط خرید</a></div>
      <div><strong>مزه‌دونه</strong><a href="/about">دربارهٔ ما</a><SocialSupport />
          <EnamadSeal />
        </div>
    </div>
    <div className={styles.copyright}>© مزه‌دونه · خوش‌خوراکِ هر روز</div>
  </footer>;
}

export function ProductCard({ product }: { product: DemoProduct }) {
  return <article className={styles.productCard}>
    <a className={`${styles.productVisual} ${styles[product.accent]}`} href={`/product/${product.id}`} aria-label={`دیدن جزئیات ${product.title}`}>
      {product.badge && <span className={styles.badge}>{product.badge}</span>}
      <ProductArtwork product={product} />
      <span className={styles.origin}>{product.origin}</span>
    </a>
    <div className={styles.productInfo}>
      <small>{product.category} <span>·</span> {product.packageLabel}</small>
      <a href={`/product/${product.id}`}><h3>{product.title}</h3></a>
      <p>{product.subtitle}</p>
      <div className={styles.productBuy}><strong>{toman(product.price)} <small>تومان</small></strong><ProductCartControl product={product} /></div>
    </div>
  </article>;
}

export function RelatedProducts({ currentId }: { currentId?: string }) {
  const { products } = useCatalog();
  const items = products.filter((item) => item.id !== currentId).slice(0, 4);
  if (!items.length) return null;
  return <section className={styles.related}><div className={styles.sectionTitle}><div><span>برای چشیدن بعدی</span><h2>شاید این‌ها را هم دوست داشته باشی</h2></div><a href="/shop">مشاهدهٔ همه ←</a></div><div className={styles.productGrid}>{items.map((product) => <ProductCard key={product.id} product={product} />)}</div></section>;
}

export function ShopShell({ children, title, kicker, description }: { children: React.ReactNode; title: string; kicker: string; description: string }) {
  return <main className={styles.page}><StoreHeader /><section className={styles.pageHero}>
    <div className={styles.pageHeroCopy}>
      <span>{kicker}</span>
      <h1>{title}</h1>
      <p>{description}</p>
      <div className={styles.pageHeroMeta} aria-hidden="true">
        <span>تازه و روزانه</span>
        <span>بسته‌بندی دوست‌داشتنی</span>
      </div>
    </div>
    <div className={styles.pageHeroArt} aria-hidden="true">
      <div className={styles.pageHeroHalo} />
      <img className={styles.pageHeroImage + " " + styles.pageHeroImageBack} src="/products/dragon-box-new.webp" alt="" />
      <img className={styles.pageHeroImage + " " + styles.pageHeroImageSide} src="/products/almond-pouch-new.webp" alt="" />
      <img className={styles.pageHeroImage + " " + styles.pageHeroImageFront} src="/products/pistachio-pouch-new.webp" alt="" />
      <img className={styles.pageHeroImage + " " + styles.pageHeroImageWalnut} src="/products/walnut-character-new.webp" alt="" />
      <span className={styles.pageHeroSpark + " " + styles.pageHeroSparkOne}>✦</span>
      <span className={styles.pageHeroSpark + " " + styles.pageHeroSparkTwo}>✦</span>
    </div>
  </section>{children}<StoreFooter /></main>;
}
