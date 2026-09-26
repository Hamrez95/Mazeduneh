"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { categories, demoProducts, toman, type DemoProduct } from "./demo/catalog";
import { ProductArtwork } from "./demo/ProductArtwork";
import { useCart } from "./cart-context";
import styles from "./store-pages.module.css";

export function BrandLogo({ light = false }: { light?: boolean }) {
  return (
    <a className={`${styles.brand} ${light ? styles.brandLight : ""}`} href="/" aria-label="مزه‌دونه، صفحهٔ اصلی">
      <img src="/mazedoone-mark.svg" alt="" width={46} height={46} />
      <span><strong>مزه‌دونه</strong><small>خوش‌خوراکِ هر روز</small></span>
    </a>
  );
}

export function StoreHeader() {
  const { count } = useCart();
  const [query, setQuery] = useState("");
  const [menuOpen, setMenuOpen] = useState(false);
  const router = useRouter();
  function search(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    router.push(`/shop?q=${encodeURIComponent(query.trim())}`);
  }
  return (
    <>
      <div className={styles.announcement}>ارسال رایگان برای سفارش‌های بالای ۱٬۵۰۰٬۰۰۰ تومان <span>·</span> آماده‌سازی تازه و روزانه</div>
      <header className={styles.siteHeader}>
        <BrandLogo />
        <button className={styles.menuToggle} type="button" aria-expanded={menuOpen} aria-label={menuOpen ? "بستن فهرست" : "باز کردن فهرست"} onClick={() => setMenuOpen((open) => !open)}>{menuOpen ? "×" : "☰"}</button>
        <nav className={`${styles.nav} ${menuOpen ? styles.navOpen : ""}`} aria-label="ناوبری فروشگاه">
          <a href="/shop" onClick={() => setMenuOpen(false)}>همهٔ محصولات</a>
          <a href="/shop?category=آجیل و مغزها" onClick={() => setMenuOpen(false)}>آجیل و مغزها</a>
          <a href="/shop?category=میوه خشک" onClick={() => setMenuOpen(false)}>میوه خشک</a>
          <a href="/shop?category=کوکی و شیرینی" onClick={() => setMenuOpen(false)}>کوکی و شیرینی</a>
          <a href="/about" onClick={() => setMenuOpen(false)}>داستان ما</a>
        </nav>
        <div className={styles.headerActions}>
          <form className={styles.search} onSubmit={search} role="search"><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="دنبال چه مزه‌ای هستی؟" aria-label="جست‌وجوی محصولات" /><button aria-label="جست‌وجو">⌕</button></form>
          <a href="/cart" className={styles.cartLink} aria-label={`سبد خرید، ${count} کالا`}>سبد خرید <b>{toman(count)}</b></a>
        </div>
      </header>
      {menuOpen && <button className={styles.menuScrim} type="button" aria-label="بستن فهرست" onClick={() => setMenuOpen(false)} />}
    </>
  );
}

export function StoreFooter() {
  return <footer className={styles.footer}>
    <div className={styles.footerMain}>
      <div><BrandLogo light /><p>یک مشت خوراکی خوش‌طعم برای لحظه‌های کوچک روزمره؛ تازه، ساده و باحوصله آماده‌شده.</p></div>
      <div><strong>خرید</strong><a href="/shop">همهٔ محصولات</a><a href="/shop?category=آجیل و مغزها">آجیل و مغزها</a><a href="/shop?category=میوه خشک">میوه خشک</a><a href="/shop?category=کوکی و شیرینی">کوکی و شیرینی</a></div>
      <div><strong>راهنما</strong><a href="/shipping">روش و زمان ارسال</a><a href="/returns">بازگشت و پیگیری</a><a href="/faq">پرسش‌های پرتکرار</a><a href="/contact">تماس با ما</a></div>
      <div><strong>مزه‌دونه</strong><a href="/about">دربارهٔ ما</a><span>پشتیبانی: هر روز، ۹ تا ۱۸</span><span>نسخهٔ نمایشی؛ سفارش و پرداخت واقعی فعال نیست.</span></div>
    </div>
    <div className={styles.copyright}>© مزه‌دونه · خوش‌خوراکِ هر روز</div>
  </footer>;
}

export function ProductCard({ product }: { product: DemoProduct }) {
  const { add } = useCart();
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
      <div className={styles.productBuy}><strong>{toman(product.price)} <small>تومان</small></strong><button type="button" onClick={() => add(product)} aria-label={`افزودن ${product.title} به سبد`}>افزودن <b>+</b></button></div>
    </div>
  </article>;
}

export function RelatedProducts({ currentId }: { currentId?: string }) {
  const items = demoProducts.filter((item) => item.id !== currentId).slice(0, 4);
  return <section className={styles.related}><div className={styles.sectionTitle}><div><span>برای چشیدن بعدی</span><h2>شاید این‌ها را هم دوست داشته باشی</h2></div><a href="/shop">مشاهدهٔ همه ←</a></div><div className={styles.productGrid}>{items.map((product) => <ProductCard key={product.id} product={product} />)}</div></section>;
}

export function ShopShell({ children, title, kicker, description }: { children: React.ReactNode; title: string; kicker: string; description: string }) {
  return <main className={styles.page}><StoreHeader /><section className={styles.pageHero}><span>{kicker}</span><h1>{title}</h1><p>{description}</p></section>{children}<StoreFooter /></main>;
}

export function categoriesForUi() { return categories; }
