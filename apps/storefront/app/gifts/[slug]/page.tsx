import { notFound } from "next/navigation";
import { StoreHeader, StoreFooter } from "../../store-chrome";
import { breadcrumbs, JsonLd, pageMetadata } from "../../seo";
import { corporateRequestHref, giftGuides } from "../guides";
import styles from "../gifts.module.css";

export function generateStaticParams(){return giftGuides.map(g=>({slug:g.slug}));}
export async function generateMetadata({params}:{params:Promise<{slug:string}>}){
  const {slug}=await params;const guide=giftGuides.find(g=>g.slug===slug);
  return guide ? pageMetadata(`/gifts/${slug}`,guide.title,guide.intro) : { title:"راهنما پیدا نشد",robots:{index:false} };
}
export default async function GiftGuidePage({params}:{params:Promise<{slug:string}>}){
  const {slug}=await params;const guide=giftGuides.find(g=>g.slug===slug);if(!guide)notFound();
  return <><StoreHeader /><main className={styles.page}>
    <JsonLd data={breadcrumbs([{name:"خانه",path:"/"},{name:"هدیه و پذیرایی",path:"/gifts"},{name:guide.title,path:`/gifts/${slug}`}])} />
    <nav className={styles.crumbs} aria-label="مسیر صفحه"><a href="/">خانه</a><span aria-hidden="true">/</span><a href="/gifts">هدیه و پذیرایی</a><span aria-hidden="true">/</span><span>{guide.title}</span></nav>
    <section className={styles.hero}><div><span className={styles.eyebrow}>{guide.eyebrow}</span><h1>{guide.title}</h1><p>{guide.intro}</p><div className={styles.actions}><a className={styles.primary} href={corporateRequestHref(guide)}>برای این مناسبت پیشنهاد می‌خواهم</a><a className={styles.secondary} href="/gifts">بازگشت به راهنماها</a></div></div><div className={styles.image}><img src={guide.image} alt={guide.alt} width={560} height={300} /><small className={styles.caption}>تصویر پیشنهادی؛ محتویات و بسته‌بندی در پیشنهاد نهایی مشخص می‌شوند.</small></div></section>
    <div className={`${styles.section} ${styles.article}`}><article className={styles.prose}>{guide.sections.map(section=><section key={section.title}><h2>{section.title}</h2><p>{section.text}</p></section>)}</article><aside className={styles.checklist}><h2>برای شروع چه چیزهایی لازم است؟</h2><ul>{guide.checklist.map(item=><li key={item}>{item}</li>)}</ul><a className={styles.primary} href={corporateRequestHref(guide)}>ثبت درخواست پیشنهاد</a><p className={styles.hint}>بدون ثبت‌نام و پرداخت؛ ثبت درخواست به معنی رزرو کالا نیست.</p></aside></div>
    <section className={`${styles.section} ${styles.faq}`}><h2>پیش از انتخاب</h2>{guide.questions.map(item=><details key={item.question}><summary>{item.question}</summary><p>{item.answer}</p></details>)}</section>
    <section className={styles.section}><h2>برای موقعیت‌های دیگر</h2><div className={styles.grid}>{giftGuides.filter(g=>g.slug!==slug).map(g=><article className={styles.card} key={g.slug}><h3>{g.title}</h3><p>{g.intro}</p><a href={`/gifts/${g.slug}`}>خواندن راهنما ←</a></article>)}</div></section>
  </main><StoreFooter /></>;
}
