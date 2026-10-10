import Link from "next/link";
import styles from "./corporate-sales.module.css";

export function CorporateSalesBanner() {
  return (
    <section className={styles.banner} aria-labelledby="corporate-banner-title">
      <span className={`${styles.leaf} ${styles.leafOne}`} aria-hidden="true" />
      <span className={`${styles.leaf} ${styles.leafTwo}`} aria-hidden="true" />
      <div className={styles.bannerProduct}>
        <div className={styles.productGlow} aria-hidden="true" />
        <img
          src="/organization/mazeduneh-gift-box.webp"
          alt="جعبه هدیه آجیل و خشکبار مزه‌دونه"
          loading="lazy"
          decoding="async"
        />
      </div>
      <div className={styles.bannerCopy}>
        <span className={styles.eyebrow}>فروش سازمانی و هدایای مناسبتی مزه‌دونه</span>
        <h2 id="corporate-banner-title"><span>هدیه‌ای خوش‌طعم</span><em>برای تیم شما</em></h2>
        <p>برای قدردانی از تیم‌تان، یک انتخاب خوش‌سلیقه و ماندگار بسازید.</p>
        <Link className={styles.bannerCta} href="/corporate-sales">
          مشاهده خدمات سازمانی <span aria-hidden="true">←</span>
        </Link>
      </div>
    </section>
  );
}
