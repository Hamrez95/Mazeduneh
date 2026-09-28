"use client";

import { FormEvent, useState } from "react";
import Link from "next/link";
import { API_BASE } from "./api-catalog";
import styles from "./corporate-sales-page.module.css";

const phone = process.env.NEXT_PUBLIC_CORPORATE_PHONE?.trim() || "021-9100-0000";
const whatsapp = process.env.NEXT_PUBLIC_CORPORATE_WHATSAPP?.trim() || "";
const packages = ["اقتصادی", "استاندارد", "پریمیوم", "سفارش اختصاصی"];
const services = [
  ["01", "پک‌های هدیه سازمانی", "ترکیبی از آجیل، خشکبار و خوراکی‌های دوست‌داشتنی برای هر تیم."],
  ["02", "یلدا و نوروز", "مناسبت‌ها را با یک هدیهٔ به‌یادماندنی و خوش‌سلیقه جشن بگیرید."],
  ["03", "بسته‌بندی اختصاصی", "لوگو، کارت تبریک و رنگ‌بندی برند شما در تجربهٔ هدیه دیده می‌شود."],
  ["04", "سفارش تعداد بالا", "از چند ده تا چند هزار بسته، با برنامه‌ریزی و کنترل کیفیت یکسان."],
];
const steps = ["ثبت درخواست", "تماس و بررسی نیاز", "پیشنهاد ترکیب و قیمت", "تأیید و تولید", "ارسال سفارش"];
const faqs = [
  ["حداقل تعداد سفارش چقدر است؟", "برای هر مناسبت، ترکیب و تعداد را بررسی می‌کنیم؛ حتی سفارش‌های کم‌تعداد هم قابل مذاکره است."],
  ["امکان درج لوگو وجود دارد؟", "بله، لوگو، کارت تبریک و بسته‌بندی اختصاصی در پیشنهاد شما لحاظ می‌شود."],
  ["زمان آماده‌سازی چقدر است؟", "پس از بررسی تعداد و نوع بسته، زمان دقیق آماده‌سازی در پیش‌فاکتور اعلام می‌شود."],
  ["امکان ارسال به چند آدرس هست؟", "بله، برای ارسال چندمقصدی، فهرست آدرس‌ها را از شما دریافت و برنامه‌ریزی می‌کنیم."],
  ["امکان دریافت نمونه یا پیش‌فاکتور هست؟", "بله، پس از ثبت درخواست، کارشناس ترکیب‌های پیشنهادی و پیش‌فاکتور را برایتان ارسال می‌کند."],
];

type FormState = { customerName: string; companyName: string; mobile: string; email: string; city: string; occasion: string; orderQuantity: string; packageType: string; budget: string; deliveryDate: string; customPackaging: string; description: string };
const initialState: FormState = { customerName: "", companyName: "", mobile: "", email: "", city: "", occasion: "", orderQuantity: "", packageType: "استاندارد", budget: "", deliveryDate: "", customPackaging: "بله", description: "" };

export default function CorporateSalesLanding() {
  const [form, setForm] = useState(initialState);
  const [logo, setLogo] = useState<File | null>(null);
  const [status, setStatus] = useState<"idle" | "loading" | "success" | "error">("idle");
  const [message, setMessage] = useState("");
  const [errors, setErrors] = useState<Partial<Record<keyof FormState, string>>>({});

  const update = (key: keyof FormState, value: string) => setForm((current) => ({ ...current, [key]: value }));
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const next: typeof errors = {};
    (['customerName', 'companyName', 'mobile', 'city', 'occasion', 'orderQuantity', 'packageType', 'deliveryDate'] as const).forEach((key) => { if (!form[key].trim()) next[key] = "این فیلد الزامی است."; });
    if (form.email && !/^\S+@\S+\.\S+$/.test(form.email)) next.email = "ایمیل معتبر وارد کنید.";
    setErrors(next);
    if (Object.keys(next).length || !API_BASE) { if (!API_BASE) { setStatus("error"); setMessage("اتصال API فروشگاه برای ثبت درخواست فعال نیست."); } return; }
    setStatus("loading"); setMessage("");
    try {
      let logoKey: string | undefined;
      if (logo) {
        const body = new FormData(); body.append("file", logo);
        const upload = await fetch(`${API_BASE}/api/v1/corporate-requests/upload`, { method: "POST", body });
        if (!upload.ok) throw new Error("آپلود لوگو انجام نشد.");
        logoKey = (await upload.json()).key;
      }
      const response = await fetch(`${API_BASE}/api/v1/corporate-requests`, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ ...form, orderQuantity: Number(form.orderQuantity), budget: form.budget ? Number(form.budget) : null, deliveryDate: form.deliveryDate || null, customPackaging: form.customPackaging === "بله", logoKey }) });
      const data = await response.json().catch(() => ({}));
      if (!response.ok) throw new Error(data.message || "ثبت درخواست انجام نشد.");
      setStatus("success"); setMessage(data.message || "درخواست شما ثبت شد."); setForm(initialState); setLogo(null);
    } catch (error) { setStatus("error"); setMessage(error instanceof Error ? error.message : "خطایی رخ داد. دوباره تلاش کنید."); }
  }

  return <main className={styles.page} dir="rtl">
    <header className={styles.topbar}><Link href="/" className={styles.backLink}>← بازگشت به فروشگاه</Link><span>فروش سازمانی مزه‌دونه</span><a href={`tel:${phone}`} className={styles.phoneLink}>تماس مستقیم</a></header>
    <section className={styles.hero}>
      <div className={styles.heroCopy}><span className={styles.kicker}>یک هدیه، برای ساختن یک حال خوب</span><h1>هدیه‌ای خوش‌طعم<br /><em>برای تیم شما</em></h1><p>از انتخاب ترکیب تا بسته‌بندی اختصاصی و ارسال، یک تجربهٔ سازمانی گرم و حرفه‌ای بسازید.</p><div className={styles.heroActions}><a className={styles.primary} href="#request">درخواست مشاوره سازمانی <b>←</b></a><a className={styles.outline} href={whatsapp ? `https://wa.me/${whatsapp}` : `tel:${phone}`}>تماس یا واتساپ</a></div></div><div className={styles.heroProduct}><span className={styles.heroBlob} /><img src="/organization/mazeduneh-gift-box.webp" alt="جعبه هدیه سازمانی مزه‌دونه" /></div>
    </section>
    <section className={styles.section}><div className={styles.sectionIntro}><span className={styles.kicker}>برای هر مناسبت، یک ترکیب</span><h2>خدماتی که کار را برای شما ساده می‌کند</h2></div><div className={styles.serviceGrid}>{services.map(([number, title, text]) => <article className={styles.service} key={number}><span>{number}</span><h3>{title}</h3><p>{text}</p></article>)}</div></section>
    <section className={styles.process}><div className={styles.sectionIntro}><span className={styles.kicker}>از ایده تا تحویل</span><h2>روند همکاری روشن و قابل پیگیری</h2></div><div className={styles.steps}>{steps.map((step, index) => <div className={styles.step} key={step}><b>{String(index + 1).padStart(2, "0")}</b><span>{step}</span></div>)}</div></section>
    <section className={styles.packages}><div className={styles.sectionIntro}><span className={styles.kicker}>برای بودجه و سلیقهٔ شما</span><h2>سطح هدیه را انتخاب کنید</h2></div><div className={styles.packageGrid}>{packages.map((item, index) => <article className={`${styles.package} ${index === 2 ? styles.packageFeatured : ""}`} key={item}><span>{index === 2 ? "محبوب‌ترین انتخاب" : `پیشنهاد ${String(index + 1).padStart(2, "0")}`}</span><h3>{item}</h3><p>{index === 0 ? "جمع‌وجور و دوست‌داشتنی" : index === 1 ? "متعادل و کامل" : index === 2 ? "ویژهٔ مدیران و مشتریان مهم" : "کاملاً متناسب با برند شما"}</p><a href="#request">دریافت پیشنهاد ←</a></article>)}</div></section>
    <section className={styles.requestSection} id="request"><div className={styles.formIntro}><span className={styles.kicker}>یک قدم تا پیشنهاد شما</span><h2>درخواست فروش سازمانی</h2><p>اطلاعات اولیه را کوتاه و سریع بفرستید؛ برای جزئیات بیشتر با شما تماس می‌گیریم.</p><a href={`tel:${phone}`} className={styles.contactCard}>☎ <span>مشاورهٔ مستقیم<br /><b>{phone}</b></span></a></div><form className={styles.form} onSubmit={submit} noValidate><div className={styles.formGrid}>{([['customerName','نام و نام خانوادگی','text',true],['companyName','نام شرکت یا سازمان','text',true],['mobile','شماره تماس','tel',true],['email','ایمیل (اختیاری)','email',false],['city','شهر','text',true],['occasion','نوع مناسبت','text',true],['orderQuantity','تعداد تقریبی سفارش','number',true],['budget','بودجه تقریبی (اختیاری)','number',false],['deliveryDate','تاریخ موردنیاز تحویل','date',true]] as const).map(([key, label, type, required]) => <label className={styles.field} key={key}>{label}{required && <sup>*</sup>}<input type={type} value={form[key]} required={required} onChange={(event) => update(key, event.target.value)} aria-invalid={Boolean(errors[key])} />{errors[key] && <small>{errors[key]}</small>}</label>)}<label className={styles.field}><span>نوع یا وزن بسته<sup>*</sup></span><select value={form.packageType} onChange={(event) => update("packageType", event.target.value)}>{packages.map((item) => <option key={item}>{item}</option>)}</select></label><label className={styles.field}><span>نیاز به لوگو یا بسته‌بندی اختصاصی؟</span><select value={form.customPackaging} onChange={(event) => update("customPackaging", event.target.value)}><option>بله</option><option>خیر</option></select></label><label className={`${styles.field} ${styles.wide}`}><span>آپلود لوگوی شرکت (اختیاری)</span><input type="file" accept="image/png,image/jpeg,image/webp" onChange={(event) => setLogo(event.target.files?.[0] ?? null)} /><small className={styles.hint}>PNG، JPG یا WEBP تا ۸ مگابایت</small></label><label className={`${styles.field} ${styles.wide}`}><span>توضیحات تکمیلی</span><textarea value={form.description} onChange={(event) => update("description", event.target.value)} rows={4} placeholder="مثلاً رنگ سازمانی، ترکیب مورد علاقه یا نحوهٔ ارسال..." /></label></div>{status !== "idle" && <div className={`${styles.formMessage} ${status === "success" ? styles.success : styles.failure}`} role={status === "error" ? "alert" : "status"}>{message}</div>}<button className={styles.submit} disabled={status === "loading"}>{status === "loading" ? "در حال ارسال..." : "ثبت درخواست مشاوره"}</button></form></section>
    <section className={styles.faq}><div className={styles.sectionIntro}><span className={styles.kicker}>پاسخ چند سؤال رایج</span><h2>قبل از شروع همکاری</h2></div><div className={styles.faqList}>{faqs.map(([question, answer]) => <details key={question}><summary>{question}<span>＋</span></summary><p>{answer}</p></details>)}</div></section>
    <footer className={styles.footer}><strong>مزه‌دونه</strong><span>هدیه‌هایی برای ماندگار کردن لحظه‌های خوب تیم شما.</span><Link href="/">بازگشت به فروشگاه ←</Link></footer>
  </main>;
}
