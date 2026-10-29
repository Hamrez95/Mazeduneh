import { StoreHeader, StoreFooter } from "../store-chrome";
import { breadcrumbs, JsonLd, pageMetadata } from "../seo";
import { giftGuides, corporateRequestHref } from "./guides";
import { GiftFinder } from "./gift-finder";
import styles from "./gifts.module.css";

export const metadata = pageMetadata("/gifts", "راهنمای انتخاب هدیه و پذیرایی", "از هدیهٔ یلدا و قدردانی کارکنان تا آجیل سازمانی و پذیرایی جلسه؛ راهنمای انتخاب بسته با توجه به موقعیت و بودجه.");
export default function GiftsPage() {
  return <><StoreHeader /><main className={styles.page}>
    <JsonLd data={breadcrumbs([{name:"خانه",path:"/"},{name:"هدیه و پذیرایی",path:"/gifts"}])} />
    <nav className={styles.crumbs} aria-label="مسیر صفحه"><a href="/">خانه</a><span aria-hidden="true">/</span><span>هدیه و پذیرایی</span></nav>
    <section className={styles.hero}><div><span className={styles.eyebrow}>یک انتخاب حساب‌شده، یک حال خوب</span><h1>برای چه کسی، چه مناسبتی و چه بودجه‌ای؟</h1><p>از نیازت شروع کن؛ برای خودت یک بسته انتخاب کن یا برای هدیه و پذیرایی سازمان، پیشنهاد متناسب بگیر.</p><div className={styles.actions}><a className={styles.primary} href="#finder">کمکم کن انتخاب کنم</a><a className={styles.secondary} href="/shop">دیدن محصولات</a></div></div><div className={styles.image}><img src="/products/gift-boxes-new.webp" alt="تصویر پیشنهادی بسته‌های هدیهٔ مزه‌دونه" width={560} height={300} /><small className={styles.caption}>تصاویر، ایدهٔ ارائه‌اند؛ مشخصات سفارش پس از هماهنگی نهایی می‌شوند.</small></div></section>
    <section className={styles.section} aria-labelledby="occasions"><span className={styles.eyebrow}>از موقعیت شروع کن</span><h2 id="occasions">هر مناسبت، انتخاب خودش را دارد</h2><p>راهنمای هر موقعیت را بخوان؛ جزئیات مهم را یک‌جا ببین و بعد درخواستت را ثبت کن.</p><div className={styles.grid}>{giftGuides.map(guide=><article className={styles.card} key={guide.slug}><img src={guide.image} alt={guide.alt} width={520} height={200} loading="lazy" /><h3>{guide.title}</h3><p>{guide.intro}</p><a href={`/gifts/${guide.slug}`}>راهنمای انتخاب و سفارش ←</a></article>)}</div></section>
    <GiftFinder />
    <section className={styles.section}><h2>هدیه‌ای که بعد از آخرین دانه هم می‌ماند</h2><p>بازی دوز و اوریگامی گفت‌وگو، دو ایدهٔ ما برای ادامهٔ تجربهٔ هدیه‌اند. برای بررسی امکان تولید، تعداد و زمان موردنظرت را با ما در میان بگذار.</p><a className={styles.secondary} href={corporateRequestHref(giftGuides[2])}>بررسی یک هدیهٔ خلاقانه</a></section>
  </main><StoreFooter /></>;
}
