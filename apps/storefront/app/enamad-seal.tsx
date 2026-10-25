"use client";

import { useEffect, useRef, useState } from "react";
import styles from "./enamad-seal.module.css";

const code = "xq46ZqyHRQtv0ZGlrkmnEj6fFhmX7Zxc";
const profileUrl = `https://trustseal.enamad.ir/?id=8329471&Code=${code}`;
const imageUrl = `https://trustseal.enamad.ir/logo.aspx?id=8329471&Code=${code}`;

export function EnamadSeal() {
  const [state, setState] = useState<"loading" | "ready" | "unavailable">("loading");
  const [attempt, setAttempt] = useState(0);
  const [nearFooter, setNearFooter] = useState(false);
  const cardRef = useRef<HTMLElement>(null);
  const imageRef = useRef<HTMLImageElement>(null);

  function checkImage(image: HTMLImageElement) {
    // A tiny tracking/error response is not a visible trust seal.
    setState(image.naturalWidth >= 32 && image.naturalHeight >= 32 ? "ready" : "unavailable");
  }

  useEffect(() => {
    const observer = new IntersectionObserver(([entry]) => {
      if (entry.isIntersecting) { setNearFooter(true); observer.disconnect(); }
    }, { rootMargin: "300px" });
    if (cardRef.current) observer.observe(cardRef.current);
    return () => observer.disconnect();
  }, []);

  useEffect(() => {
    if (imageRef.current?.complete) checkImage(imageRef.current);
  }, [attempt]);

  useEffect(() => {
    if (!nearFooter) return;
    const timeout = window.setTimeout(() => setState(current => current === "ready" ? current : "unavailable"), 15000);
    return () => window.clearTimeout(timeout);
  }, [nearFooter, attempt]);

  return <section ref={cardRef} className={styles.card} aria-label="نماد اعتماد الکترونیکی" data-state={state}>
    <span className={styles.label}>اینماد مزه‌دونه</span>
    <a className={styles.link} href={profileUrl} target="_blank" rel="noopener" referrerPolicy="origin" aria-label="مشاهدهٔ شناسنامهٔ مزه‌دونه در سایت رسمی اینماد (پنجرهٔ جدید)">
      <span className={styles.imageStage}>
        <img key={attempt} ref={imageRef} className={`${styles.image} ${state === "ready" ? styles.ready : ""}`}
          src={attempt ? `${imageUrl}&_retry=${attempt}` : imageUrl} alt="نماد اعتماد الکترونیکی مزه‌دونه" aria-hidden={state !== "ready"} width={125} height={136}
          referrerPolicy="origin" loading="lazy" decoding="async" fetchPriority="low" {...{ code }}
          onLoad={event => checkImage(event.currentTarget)} onError={() => setState("unavailable")} />
        {state !== "ready" && <span className={styles.placeholder}>
          <svg viewBox="0 0 32 32" fill="none" stroke="currentColor" strokeWidth="1.5" aria-hidden="true"><path d="m16 3 10 4v8c0 6-4 10-10 14C10 25 6 21 6 15V7l10-4Z" /><path d="M12 12h8M12 16h8M12 20h5" /></svg>
          <span className={styles.message} role="status">{state === "loading" ? "در حال دریافت تصویر نماد…" : "تصویر نماد فعلاً در دسترس نیست"}</span>
        </span>}
      </span>
      <span className={styles.verify}>مشاهدهٔ شناسنامهٔ رسمی <span aria-hidden="true">↗</span></span>
    </a>
    {state === "unavailable" && <button className={styles.retry} type="button" onClick={() => { setState("loading"); setAttempt(Date.now()); }}>تلاش دوباره برای تصویر</button>}
  </section>;
}
