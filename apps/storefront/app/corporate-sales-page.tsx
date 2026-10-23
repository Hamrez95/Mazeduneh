"use client";

import { FormEvent, useEffect, useRef, useState } from "react";
import Link from "next/link";
import { API_BASE } from "./api-catalog";
import { formatMoney, formatRialsAsTomans, toPersianDigits } from "./formatters";
import styles from "./corporate-sales-page.module.css";

const phone = process.env.NEXT_PUBLIC_CORPORATE_PHONE?.trim() || "";
const whatsapp = (process.env.NEXT_PUBLIC_CORPORATE_WHATSAPP || "").replace(/\D/g, "");
const occasions = ["قدردانی از همکاران", "یلدا", "نوروز", "هدیه به مشتریان", "رویداد و همایش", "پذیرایی و مصرف روزانه", "سایر"];
const ideas = [
  { title: "برای همکارهای دوست‌داشتنی", label: "قدردانی از همکاران", image: "/products/gift-box.webp", text: "یک ترکیب خوش‌طعم برای قدردانی از آدم‌هایی که هر روز کنار شما هستند." },
  { title: "برای یک مناسبت به‌یادماندنی", label: "یلدا", image: "/products/gift-boxes-new.webp", text: "آجیل و خوراکی‌های مناسب هدیه؛ ترکیب و بسته‌بندی را با هم هماهنگ می‌کنیم." },
  { title: "برای روزهای کاری خوشمزه‌تر", label: "پذیرایی و مصرف روزانه", image: "/products/one-kilo-box-packaging.webp", text: "مغزیجات و میان‌وعده برای جلسات، پذیرایی یا مصرف تیم شما." },
];
const faqs = [
  ["هنوز نمی‌دانیم چه بسته‌ای انتخاب کنیم؛ چه کار کنیم؟", "تعداد تقریبی و بودجهٔ دلخواه را بفرستید و گزینهٔ «برای انتخاب راهنمایی می‌خواهم» را نگه دارید. برای پیشنهاد ترکیب مناسب با شما هماهنگ می‌کنیم."],
  ["قیمت نهایی چطور مشخص می‌شود؟", "محتویات، وزن، تعداد، بسته‌بندی و نحوهٔ ارسال در قیمت اثر دارند. قیمت بسته‌های موجود، قیمت پایه است؛ مبلغ و شرایط نهایی در پیشنهاد فروش مشخص می‌شود."],
  ["حداقل تعداد سفارش و زمان تحویل چقدر است؟", "به ترکیب و بسته‌بندی انتخابی بستگی دارد. تعداد و زمان مدنظر را در درخواست بنویسید تا امکان تأمین و زمان تحویل پیش از نهایی شدن سفارش بررسی شود."],
  ["لوگو، کارت تبریک یا ارسال به چند مقصد می‌خواهیم.", "در بخش جزئیات اختیاری درخواست مشخص کنید. امکان اجرا، هزینه و زمان این موارد پیش از تأیید سفارش با شما هماهنگ می‌شود."],
  ["آیا با ثبت درخواست باید پرداخت کنیم؟", "خیر. این فرم برای شروع گفت‌وگو و دریافت پیشنهاد است. ثبت درخواست به معنی خرید، پرداخت یا رزرو موجودی نیست."],
];
type PackageChoice = { code: string; name: string; description?: string | null; unitPrice: number; isActive: boolean; items?: { name: string; quantity: number; unit: string }[] };
type FormState = { customerName: string; companyName: string; mobile: string; city: string; occasion: string; orderQuantity: string; budget: string; packageCode: string; email: string; timing: string; customPackaging: boolean; description: string };
const initialState: FormState = { customerName: "", companyName: "", mobile: "", city: "", occasion: "قدردانی از همکاران", orderQuantity: "", budget: "", packageCode: "", email: "", timing: "", customPackaging: false, description: "" };
const latin = (value: string) => value.replace(/[۰-۹٠-٩]/g, d => String("۰۱۲۳۴۵۶۷۸۹".includes(d) ? "۰۱۲۳۴۵۶۷۸۹".indexOf(d) : "٠١٢٣٤٥٦٧٨٩".indexOf(d))).replace(/[٬,\s]/g, "");
const numericInput = (value: string) => toPersianDigits(latin(value));

export default function CorporateSalesLanding() {
  const [form, setForm] = useState(initialState);
  const [catalog, setCatalog] = useState<PackageChoice[]>([]);
  const [catalogState, setCatalogState] = useState<"loading" | "ready" | "error">("loading");
  const [logo, setLogo] = useState<File | null>(null);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  const [errors, setErrors] = useState<Partial<Record<keyof FormState, string>>>({});
  const [receipt, setReceipt] = useState<{ id: string; company: string; quantity: string } | null>(null);
  const sending = useRef(false);
  const formRef = useRef<HTMLFormElement>(null);
  const successRef = useRef<HTMLDivElement>(null);
  const fileRef = useRef<HTMLInputElement>(null);
  useEffect(() => {
    const controller = new AbortController();
    if (!API_BASE) { setCatalogState("error"); return; }
    fetch(`${API_BASE}/api/v1/corporate-packages`, { cache: "no-store", signal: controller.signal })
      .then(async response => { if (!response.ok) throw new Error(); return response.json() as Promise<PackageChoice[]>; })
      .then(items => { if (!Array.isArray(items)) throw new Error(); setCatalog(items.filter(p => p.isActive)); setCatalogState("ready"); })
      .catch(() => { if (!controller.signal.aborted) setCatalogState("error"); });
    return () => controller.abort();
  }, []);
  useEffect(() => { if (receipt) successRef.current?.focus(); }, [receipt]);
  const update = (key: keyof FormState, value: string | boolean) => { setForm(current => ({ ...current, [key]: value })); setErrors(current => ({ ...current, [key]: undefined })); };
  const quantity = Number(latin(form.orderQuantity));
  const budget = Number(latin(form.budget));
  const selected = catalog.find(p => p.code === form.packageCode);
  const choose = (occasion?: string, code?: string) => {
    setForm(current => ({ ...current, ...(occasion ? { occasion } : {}), packageCode: code ?? current.packageCode }));
    document.getElementById("request")?.scrollIntoView({ behavior: "auto", block: "start" });
    formRef.current?.querySelector<HTMLInputElement>('input[name="customerName"]')?.focus({ preventScroll: true });
  };
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (sending.current) return;
    const next: typeof errors = {};
    for (const key of ["customerName", "companyName", "city"] as const) if (!form[key].trim()) next[key] = "لطفاً این مورد را بنویسید.";
    const mobile = latin(form.mobile).replace(/[-()]/g, "");
    if (!/^(?:0|\+98|0098)9\d{9}$/.test(mobile)) next.mobile = "شمارهٔ همراه معتبر بنویسید؛ مثلاً ۰۹۱۲۳۴۵۶۷۸۹.";
    if (!/^\d+$/.test(latin(form.orderQuantity)) || !Number.isSafeInteger(quantity) || quantity < 1 || quantity > 1000000) next.orderQuantity = "تعداد را بین ۱ تا ۱٬۰۰۰٬۰۰۰ بسته بنویسید.";
    if (form.budget && (!/^\d+$/.test(latin(form.budget)) || !Number.isSafeInteger(budget) || budget < 1 || !Number.isSafeInteger(budget * quantity * 10))) next.budget = "بودجهٔ هر بسته را به تومان کامل و در محدودهٔ معتبر بنویسید.";
    if (form.email && !/^\S+@\S+\.\S+$/.test(form.email)) next.email = "نشانی ایمیل را بررسی کنید.";
    setErrors(next); setMessage("");
    if (Object.keys(next).length) { if (next.email) { const details = formRef.current?.querySelector("details"); if (details) details.open = true; }
      formRef.current?.querySelector<HTMLElement>(`[name="${Object.keys(next)[0]}"]`)?.focus(); return; }
    if (!API_BASE) { setMessage("ثبت آنلاین درخواست فعلاً در دسترس نیست. کمی بعد دوباره تلاش کنید."); return; }
    if (logo && (logo.size > 8 * 1024 * 1024 || !["image/png", "image/jpeg", "image/webp"].includes(logo.type))) { setMessage("لوگو باید PNG، JPG یا WEBP و حداکثر ۸ مگابایت باشد."); return; }
    sending.current = true; setBusy(true);
    try {
      let logoKey: string | undefined;
      if (logo) {
        const body = new FormData(); body.append("file", logo);
        const upload = await fetch(`${API_BASE}/api/v1/corporate-requests/upload`, { method: "POST", body });
        if (!upload.ok) throw new Error("بارگذاری لوگو انجام نشد؛ دوباره تلاش کنید یا فعلاً بدون لوگو بفرستید.");
        logoKey = (await upload.json()).key;
      }
      const description = [form.timing.trim() && `زمان موردنظر تحویل: ${form.timing.trim()}`, form.description.trim()].filter(Boolean).join("\n");
      const response = await fetch(`${API_BASE}/api/v1/corporate-requests`, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ customerName: form.customerName.trim(), companyName: form.companyName.trim(), mobile, city: form.city.trim(), occasion: form.occasion, orderQuantity: quantity, packageCode: selected?.code ?? null, packageType: selected?.name ?? "برای انتخاب راهنمایی می‌خواهم", budget: form.budget ? budget * quantity * 10 : null, deliveryDate: null, customPackaging: form.customPackaging, email: form.email.trim() || null, description, logoKey }) });
      const data = await response.json().catch(() => ({}));
      if (!response.ok) throw new Error(data.message || Object.values(data.errors ?? {}).flat().join(" ") || "ثبت درخواست تأیید نشد؛ لطفاً دوباره تلاش کنید.");
      if (!data.id) throw new Error("تأیید ثبت درخواست دریافت نشد. لطفاً با فروش هماهنگ کنید.");
      setReceipt({ id: data.id, company: form.companyName, quantity: form.orderQuantity });
    } catch (error) { setMessage(error instanceof Error ? error.message : "ارتباط برقرار نشد؛ اطلاعات فرم حفظ شده است. دوباره تلاش کنید."); }
    finally { sending.current = false; setBusy(false); }
  }
  return <main className={styles.page} dir="rtl">
    <header className={styles.topbar}><Link href="/" className={styles.brand}><img src="/mazedoone-mark.svg" alt="" width="38" height="38" />مزه‌دونه <span>همراه خوش‌طعم سازمان شما</span></Link><nav aria-label="راهنمای فروش سازمانی"><a href="#packages">بسته‌ها و ایده‌ها</a><a href="#process">مراحل سفارش</a><a href="#request" className={styles.navCta}>دریافت پیشنهاد</a></nav></header>
    <section className={styles.hero}><div className={styles.heroCopy}><span className={styles.kicker}>هدایای سازمانی · آجیل و مغزیجات · میان‌وعده</span><h1>قدردانی شما،<br /><em>با طعمِ یک حال خوب.</em></h1><p>برای همکارها، مشتری‌ها و مهمان‌های شما؛ هدیه‌ای خوش‌طعم با ترکیب و بسته‌بندی متناسب با بودجهٔ سازمانتان انتخاب کنیم.</p><div className={styles.heroActions}><a href="#request" className={styles.primary}>برای سازمانم پیشنهاد می‌خواهم <span aria-hidden="true">←</span></a><a href="#packages" className={styles.secondary}>اول گزینه‌ها را ببینم ↓</a></div><p className={styles.reassurance}>بدون نیاز به ثبت‌نام یا پرداخت · جزئیات را با هم هماهنگ می‌کنیم</p></div><div className={styles.heroProduct}><span className={styles.heroBlob} /><img src="/organization/mazeduneh-gift-box.webp" alt="نمونهٔ چیدمان جعبه هدیه مزه‌دونه" fetchPriority="high" /><span className={styles.imageLabel}>ایدهٔ چیدمان؛ ترکیب نهایی با انتخاب شما</span></div></section>
    <div className={styles.benefits}><div><b>متناسب با بودجه</b><span>تعداد و بودجهٔ هر بسته، نقطهٔ شروع ماست.</span></div><div><b>با هویت سازمان شما</b><span>امکان بررسی لوگو، کارت و بسته‌بندی اختصاصی.</span></div><div><b>شفاف، قبل از تأیید</b><span>ترکیب، مبلغ و زمان تحویل را هماهنگ می‌کنیم.</span></div></div>
    <section className={styles.section} id="packages"><div className={styles.sectionIntro}><div><span className={styles.kicker}>از اینجا انتخاب را شروع کنید</span><h2>برای چه کسی خوشمزگی می‌فرستید؟</h2></div><p>این‌ها ایده‌اند؛ لازم نیست همین حالا محتویات نهایی را انتخاب کنید.</p></div><div className={styles.ideaGrid}>{ideas.map(item => <article className={styles.idea} key={item.label}><div className={styles.ideaImage}><img src={item.image} alt={`ایدهٔ بسته‌بندی ${item.title}`} loading="lazy" /><span>ایدهٔ هدیه</span></div><div className={styles.ideaCopy}><h3>{item.title}</h3><p>{item.text}</p><button type="button" onClick={() => choose(item.label)}>برای این مناسبت پیشنهاد می‌خواهم ←</button></div></article>)}</div>
    {catalog.length > 0 && <div className={styles.livePackages}><h3>بسته‌های قابل درخواست</h3><p>قیمت پایهٔ هر بسته؛ هزینه و شرایط نهایی پس از بررسی درخواست مشخص می‌شود.</p><div className={styles.catalogGrid}>{catalog.map(item => <article key={item.code}><h4>{item.name}</h4>{item.description && <p>{item.description}</p>}{!!item.items?.length && <ul>{item.items.map((entry, index) => <li key={index}>{entry.name} · {toPersianDigits(entry.quantity)} {entry.unit}</li>)}</ul>}<strong>{formatRialsAsTomans(item.unitPrice)} <small>تومان / هر بسته</small></strong><button type="button" onClick={() => choose(undefined, item.code)}>انتخاب {item.name} ←</button></article>)}</div></div>}
    {catalogState === "loading" && <p role="status">در حال دریافت بسته‌های فروشگاه…</p>}{catalogState === "error" && <p className={styles.catalogNote}>فهرست بسته‌ها فعلاً در دسترس نیست؛ همچنان می‌توانید درخواست پیشنهاد اختصاصی بفرستید.</p>}</section>
    <section className={styles.process} id="process"><div><span className={styles.kicker}>یک مسیر روشن تا تحویل</span><h2>شما نیازتان را بگویید؛<br />ترکیب مناسب را با هم پیدا می‌کنیم.</h2><a href="#request" className={styles.processLink}>شروع درخواست ←</a></div><ol>{[["نیاز شما", "تعداد، مناسبت و بودجهٔ تقریبی را مشخص می‌کنید."],["پیشنهاد ما", "برای ترکیب، بسته‌بندی، قیمت و زمان تحویل هماهنگ می‌کنیم."],["تأیید و آماده‌سازی", "پس از توافق، سفارش نهایی و ارسال برنامه‌ریزی می‌شود."]].map(([title, copy], i) => <li key={title}><span>{toPersianDigits(i + 1)}</span><div><h3>{title}</h3><p>{copy}</p></div></li>)}</ol></section>
    <section className={styles.requestSection} id="request"><div className={styles.formIntro}><span className={styles.kicker}>شروع یک همکاری خوش‌طعم</span><h2>پیشنهاد مخصوص<br />سازمان شما</h2><p>فقط اطلاعات اولیه را بنویسید. انتخاب ترکیب و جزئیات بسته‌بندی می‌تواند در گفت‌وگو مشخص شود.</p><ul><li>بودجه هنوز قطعی نیست؟ خالی بگذارید.</li><li>هنوز بسته‌ای انتخاب نکرده‌اید؟ راهنمایی می‌کنیم.</li><li>درخواست شما تعهد خرید ایجاد نمی‌کند.</li></ul>{phone && <a className={styles.contactCard} href={`tel:${phone.replace(/[^+0-9]/g, "")}`}>ترجیح می‌دهید صحبت کنیم؟ <b dir="ltr">{toPersianDigits(phone)}</b></a>}{whatsapp && <a className={styles.contactCard} href={`https://wa.me/${whatsapp}`}>گفت‌وگو در واتساپ ←</a>}</div>
    {receipt ? <div className={styles.success} ref={successRef} tabIndex={-1} role="status"><span className={styles.successIcon} aria-hidden="true">✓</span><h3>قدم اول را با هم برداشتیم!</h3><p>درخواست {receipt.company} برای {toPersianDigits(receipt.quantity)} بسته ثبت شد. برای بررسی جزئیات با شماره‌ای که وارد کردید تماس می‌گیریم.</p><p>شناسهٔ درخواست را برای پیگیری نگه دارید:</p><bdi className={styles.reference} dir="ltr">{receipt.id}</bdi><p>هنوز پرداخت یا رزرو موجودی انجام نشده است.</p><button className={styles.primary} type="button" onClick={() => { setForm(initialState); setLogo(null); setReceipt(null); setMessage(""); }}>ثبت یک درخواست دیگر</button></div> : <form className={styles.form} ref={formRef} onSubmit={submit} noValidate aria-busy={busy}><fieldset disabled={busy}><legend>اطلاعات اولیهٔ درخواست</legend><div className={styles.formGrid}>{([["customerName","نام و نام خانوادگی","name"],["companyName","نام شرکت یا سازمان","organization"],["mobile","شمارهٔ همراه برای هماهنگی","tel"],["city","شهر تحویل","address-level2"]] as const).map(([key,label,autoComplete]) => <label className={styles.field} key={key}>{label}<input name={key} autoComplete={autoComplete} type={key === "mobile" ? "tel" : "text"} value={form[key]} required maxLength={key === "mobile" ? 20 : 120} inputMode={key === "mobile" ? "tel" : "text"} onChange={e => update(key, key === "mobile" ? toPersianDigits(e.target.value) : e.target.value)} aria-invalid={!!errors[key]} aria-describedby={errors[key] ? `error-${key}` : undefined} />{errors[key] && <small id={`error-${key}`}>{errors[key]}</small>}</label>)}
      <label className={styles.field}>تعداد تقریبی بسته‌ها<input name="orderQuantity" inputMode="numeric" value={form.orderQuantity} placeholder="مثلاً ۱۰۰" required onChange={e => update("orderQuantity", numericInput(e.target.value))} aria-invalid={!!errors.orderQuantity} aria-describedby={errors.orderQuantity ? "error-quantity" : undefined} />{errors.orderQuantity && <small id="error-quantity">{errors.orderQuantity}</small>}</label>
      <label className={styles.field}>مناسبت یا کاربرد<select name="occasion" value={form.occasion} onChange={e => update("occasion", e.target.value)}>{occasions.map(item => <option key={item}>{item}</option>)}</select></label>
      <label className={styles.field}>بودجهٔ هر بسته (تومان، اختیاری)<input name="budget" inputMode="numeric" value={form.budget && /^\d+$/.test(latin(form.budget)) ? formatMoney(budget) : form.budget} placeholder="هنوز مشخص نیست" onChange={e => update("budget", numericInput(e.target.value))} aria-invalid={!!errors.budget} aria-describedby="budget-help" /><small id="budget-help">{errors.budget || (budget > 0 && quantity > 0 && Number.isSafeInteger(budget * quantity) ? `بودجهٔ تقریبی کل: ${formatMoney(budget * quantity)} تومان` : "عدد را به تومان کامل بنویسید؛ هزینهٔ نهایی پس از هماهنگی مشخص می‌شود.")}</small></label>
      <label className={styles.field}>بستهٔ موردنظر<select value={form.packageCode} onChange={e => update("packageCode", e.target.value)}><option value="">برای انتخاب راهنمایی می‌خواهم</option>{catalog.map(item => <option key={item.code} value={item.code}>{item.name}</option>)}</select></label>
      </div><details className={styles.optional}><summary>جزئیات بیشتر دارید؟ (اختیاری)</summary><div className={styles.formGrid}><label className={styles.field}>چه زمانی نیاز دارید؟<input value={form.timing} maxLength={120} onChange={e => update("timing", toPersianDigits(e.target.value))} placeholder="مثلاً هفتهٔ آخر آذر؛ هنوز قطعی نیست" /></label><label className={styles.field}>ایمیل برای هماهنگی<input name="email" type="email" autoComplete="email" dir="ltr" value={form.email} onChange={e => update("email", e.target.value)} aria-invalid={!!errors.email} />{errors.email && <small>{errors.email}</small>}</label><label className={`${styles.check} ${styles.wide}`}><input type="checkbox" checked={form.customPackaging} onChange={e => update("customPackaging", e.target.checked)} />لوگو، کارت تبریک یا بسته‌بندی اختصاصی می‌خواهم</label><label className={`${styles.field} ${styles.wide}`}>فایل لوگو (اختیاری)<input ref={fileRef} type="file" accept="image/png,image/jpeg,image/webp" onChange={e => setLogo(e.target.files?.[0] ?? null)} /><small>PNG، JPG یا WEBP، حداکثر ۸ مگابایت؛ می‌توانید بعداً بفرستید.</small></label>{logo && <button type="button" className={styles.removeFile} onClick={() => { setLogo(null); if (fileRef.current) fileRef.current.value = ""; }}>حذف فایل انتخاب‌شده</button>}<label className={`${styles.field} ${styles.wide}`}>نکته‌ای که باید بدانیم<textarea maxLength={3000} rows={3} value={form.description} onChange={e => update("description", e.target.value)} placeholder="مثلاً ترکیب دلخواه، حساسیت غذایی یا ارسال به چند مقصد…" /></label></div></details>
      {message && <p className={styles.error} role="alert">{message}</p>}<button className={styles.submit} type="submit" disabled={busy}>{busy ? "در حال ثبت درخواست…" : "درخواست پیشنهاد و هماهنگی"}<span aria-hidden="true">←</span></button><p className={styles.privacy}>از اطلاعات تماس برای پیگیری همین درخواست استفاده می‌کنیم. ارسال فرم به معنی سفارش قطعی نیست.</p></fieldset></form>}</section>
    <section className={styles.faq}><div className={styles.sectionIntro}><div><span className={styles.kicker}>با خیال روشن تصمیم بگیرید</span><h2>سؤال‌های قبل از سفارش</h2></div></div><div className={styles.faqList}>{faqs.map(([q,a]) => <details key={q}><summary>{q}<span aria-hidden="true">＋</span></summary><p>{a}</p></details>)}</div></section>
    <footer className={styles.footer}><strong>مزه‌دونه</strong><span>برای آدم‌های مهم سازمان شما، یک انتخاب خوش‌طعم.</span><Link href="/">بازگشت به فروشگاه ←</Link></footer>
    <div className={styles.mobileCta}><span>یک هدیهٔ خوش‌طعم، با بودجهٔ شما</span><a href="#request">دریافت پیشنهاد ←</a></div>
  </main>;
}
