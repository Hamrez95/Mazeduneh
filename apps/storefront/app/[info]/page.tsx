import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { InfoPage } from "../commerce-pages";

const infoPages = ["shipping", "returns", "faq", "contact"] as const;
type InfoPageKey = (typeof infoPages)[number];
const titles: Record<InfoPageKey, string> = { shipping: "روش و زمان ارسال", returns: "پیگیری و بازگشت سفارش", faq: "پرسش‌های پرتکرار", contact: "تماس با مزه‌دونه" };
export function generateStaticParams() { return infoPages.map((info) => ({ info })); }
export async function generateMetadata({ params }: { params: Promise<{ info: string }> }): Promise<Metadata> {
  const { info } = await params;
  return { title: infoPages.includes(info as InfoPageKey) ? titles[info as InfoPageKey] : "صفحه پیدا نشد" };
}
export default async function InfoRoute({ params }: { params: Promise<{ info: string }> }) {
  const { info } = await params;
  if (!infoPages.includes(info as InfoPageKey)) notFound();
  return <InfoPage page={info as InfoPageKey} />;
}
