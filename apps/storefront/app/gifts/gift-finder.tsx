"use client";

import { useMemo, useState } from "react";
import { CatalogFeedback, useCatalog } from "../catalog-context";
import { toman } from "../demo/catalog";
import { formatMoney, toPersianDigits } from "../formatters";
import { corporateRequestHref, giftGuides } from "./guides";
import styles from "./gifts.module.css";

export function GiftFinder(){
  const {products,status}=useCatalog();
  const [purpose,setPurpose]=useState("personal");const [budget,setBudget]=useState("");
  const amount=Number(budget.replace(/[۰-۹٠-٩]/g,d=>String("۰۱۲۳۴۵۶۷۸۹".includes(d)?"۰۱۲۳۴۵۶۷۸۹".indexOf(d):"٠١٢٣٤٥٦٧٨٩".indexOf(d))).replace(/[٬,\s]/g,""));
  const invalid=budget.trim()!==""&&(!Number.isSafeInteger(amount * 10)||amount<=0);
  const picks=useMemo(()=>products.filter(p=>p.stock>0&&(!amount||p.price<=amount)).sort((a,b)=>b.price-a.price).slice(0,3),[products,amount]);
  const guide=giftGuides.find(g=>g.slug===purpose);
  return <section className={styles.section} id="finder" aria-labelledby="finder-title"><h2 id="finder-title">چند قدم تا یک انتخاب خوش‌طعم</h2><p>مناسبت و بودجه‌ات را مشخص کن؛ بعد بسته‌های پیشنهادی را ببین یا برای سازمانت پیشنهاد بگیر.</p><div className={styles.finder}><div className={styles.fields}><label>برای چه موقعیتی می‌خواهی؟<select value={purpose} onChange={e=>setPurpose(e.target.value)}><option value="personal">برای خودم یا یک هدیهٔ شخصی</option>{giftGuides.map(g=><option key={g.slug} value={g.slug}>{g.occasion}</option>)}</select></label><label>حداکثر بودجهٔ هر بسته (تومان)<input inputMode="numeric" value={budget ? (invalid ? toPersianDigits(budget) : formatMoney(amount)) : ""} placeholder="اختیاری" aria-invalid={invalid} aria-describedby="gift-budget-help" onChange={e=>setBudget(e.target.value.replace(/[^0-9۰-۹٠-٩٬,\s]/g,"").slice(0,16))} /></label></div><p className={styles.hint} id="gift-budget-help">{invalid?"بودجه را به تومان و به صورت یک عدد مثبت بنویس.":"بودجه برای خود محصول است؛ ارسال و گزینه‌های اختصاصی جداگانه بررسی می‌شوند."}</p>
    {guide?<div><h3>{guide.title}</h3><p>{guide.intro}</p><div className={styles.actions}><a className={styles.secondary} href={`/gifts/${guide.slug}`}>اول راهنمای انتخاب را بخوانم</a><a className={styles.primary} aria-disabled={invalid} onClick={event=>{if(invalid)event.preventDefault();}} href={invalid?"#gift-budget-help":corporateRequestHref(guide).replace("#request",`${amount>0?`&budget=${amount}`:""}#request`)}>درخواست پیشنهاد متناسب</a></div></div>:<div aria-live="polite"><CatalogFeedback />{invalid?<p>بودجه را اصلاح کن تا انتخاب‌ها نمایش داده شوند.</p>:status==="loading"||status==="error"?null:picks.length?<><p>{status==="preview"?"انتخاب‌های زیر نمونهٔ پیش‌نمایش هستند؛ موجودی و قیمت فروش واقعی نیستند.":"چند انتخاب موجود در محدودهٔ بودجهٔ تو؛ برای دیدن همهٔ بسته‌ها، جزئیات محصول را باز کن."}</p><div className={styles.results}>{picks.map(p=><article className={styles.result} key={p.id}><strong>{p.title}</strong><span>{p.packageLabel}</span><span>{toman(p.price)} تومان</span><a href={`/product/${p.id}`}>دیدن بسته‌ها و جزئیات ←</a></article>)}</div></>:<p>در حال حاضر انتخابی با این شرایط نداریم. <a href="/shop">همهٔ محصولات را ببین</a> یا بودجه را تغییر بده.</p>}</div>}
  </div></section>;
}
