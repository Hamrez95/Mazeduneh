"use client";

import { useId, useRef, useState } from "react";
import styles from "./social-support.module.css";

const phone = "09339870210";
const displayPhone = "۰۹۳۳۹۸۷۰۲۱۰";
export const telegramSupportUrl = "https://t.me/+9893339870210";

function MessageIcon({ telegram = false }: { telegram?: boolean }) {
  return <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
    {telegram ? <><path d="m3 10 17-6-4 16-5-5-3 3v-6z" /><path d="m8 12 8-5-5 8" /></> : <><path d="M20 11.5a8 8 0 0 1-8 8H5l-3 2 1.7-5A8 8 0 1 1 20 11.5Z" /><path d="m8 11 2.5 2.5L16 8" /></>}
  </svg>;
}

export function SocialSupport() {
  const titleId = useId();
  const dialog = useRef<HTMLDialogElement>(null);
  const [copied, setCopied] = useState(false);
  async function copyPhone() {
    try { await navigator.clipboard.writeText(phone); setCopied(true); }
    catch { setCopied(false); dialog.current?.querySelector("input")?.select(); }
  }
  return <div className={styles.support}>
    <div className={styles.links} aria-label="پیام به مزه‌دونه">
      <a className={styles.link} href={telegramSupportUrl} target="_blank" rel="noopener noreferrer"><MessageIcon telegram />تلگرام</a>
      <button className={styles.link} type="button" onClick={() => { setCopied(false); dialog.current?.showModal(); }}><MessageIcon />بله</button>
    </div>
    <small>فقط پیام در بله و تلگرام: <bdi>{displayPhone}</bdi></small>
    <dialog ref={dialog} className={styles.dialog} onClick={event => { if (event.target === event.currentTarget) dialog.current?.close(); }} aria-labelledby={titleId}>
      <div className={styles.dialogHeading}><h2 id={titleId}>پیام به مزه‌دونه در بله</h2><button type="button" onClick={() => dialog.current?.close()} aria-label="بستن راهنمای بله">×</button></div>
      <p>این شماره را در مخاطب‌های بله جست‌وجو کنید و پیام بدهید.</p>
      <input aria-label="شمارهٔ مزه‌دونه در بله" value={phone} readOnly dir="ltr" onFocus={event => event.target.select()} />
      <div className={styles.links}><button type="button" className={styles.link} onClick={copyPhone}>{copied ? "شماره کپی شد" : "کپی شماره"}</button><a className={styles.link} href="https://bale.ai/" target="_blank" rel="noopener noreferrer">باز کردن بله ↗</a></div>
      <span role="status" className={styles.copyStatus}>{copied ? "شماره آمادهٔ جای‌گذاری در بله است." : "شمارهٔ ارتباطی تلگرام هم همین است."}</span>
    </dialog>
  </div>;
}
