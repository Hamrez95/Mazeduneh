import styles from "./social-support.module.css";

export const telegramSupportUrl = "https://t.me/+9893339870210";
const baleSupportUrl = process.env.NEXT_PUBLIC_MAZEDUNEH_BALE_SUPPORT_URL || "https://web.bale.ai/";

function MessageIcon({ telegram = false }: { telegram?: boolean }) {
  return <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
    {telegram ? <><path d="m3 10 17-6-4 16-5-5-3 3v-6z" /><path d="m8 12 8-5-5 8" /></> : <><path d="M20 11.5a8 8 0 0 1-8 8H5l-3 2 1.7-5A8 8 0 1 1 20 11.5Z" /><path d="m8 11 2.5 2.5L16 8" /></>}
  </svg>;
}

export function SocialSupport() {
  return <div className={styles.links} aria-label="پیام به مزه‌دونه">
    <a className={styles.link} href={telegramSupportUrl} target="_blank" rel="noopener noreferrer"><MessageIcon telegram />تلگرام</a>
    <a className={styles.link} href={baleSupportUrl} target="_blank" rel="noopener noreferrer"><MessageIcon />{process.env.NEXT_PUBLIC_MAZEDUNEH_BALE_SUPPORT_URL ? "بله" : "باز کردن بله"}</a>
  </div>;
}
