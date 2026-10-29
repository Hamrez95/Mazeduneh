import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { InfoPage } from "../commerce-pages";
import { pageMetadata } from "../seo";

const infoPages = ["shipping", "returns", "faq", "contact"] as const;
type InfoPageKey = (typeof infoPages)[number];
const titles: Record<InfoPageKey, string> = { shipping: "روش و زمان ارسال", returns: "پیگیری و بازگشت سفارش", faq: "پرسش‌های پرتکرار", contact: "تماس با مزه‌دونه" };
const descriptions: Record<InfoPageKey, string> = {
  shipping: "روش‌های ارسال و نکات تحویل سفارش در مزه‌دونه را بخوانید.",
  returns: "شرایط اعلام مغایرت، آسیب یا مشکل کیفیت و راه پیگیری سفارش مزه‌دونه.",
  faq: "پاسخ پرسش‌های رایج دربارهٔ انتخاب محصول، سفارش و خرید از مزه‌دونه.",
  contact: "راه‌های ارتباط با مزه‌دونه برای پرسش و پیگیری سفارش.",
};
export function generateStaticParams() { return infoPages.map((info) => ({ info })); }
export async function generateMetadata({ params }: { params: Promise<{ info: string }> }): Promise<Metadata> {
  const { info } = await params;
  return infoPages.includes(info as InfoPageKey)
    ? pageMetadata(`/${info}`, titles[info as InfoPageKey], descriptions[info as InfoPageKey])
    : { title: "صفحه پیدا نشد", robots: { index: false } };
}
export default async function InfoRoute({ params }: { params: Promise<{ info: string }> }) {
  const { info } = await params;
  if (!infoPages.includes(info as InfoPageKey)) notFound();
  return <InfoPage page={info as InfoPageKey} />;
}
