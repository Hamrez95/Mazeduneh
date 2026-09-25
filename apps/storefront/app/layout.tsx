import type { Metadata } from "next";
import "./globals.css";
import "./commerce.css";

export const metadata: Metadata = {
  metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL ?? "https://mazeduneh-storefront.vercel.app"),
  title: {
    default: "مزه‌دونه | خوش‌خوراکِ هر روز",
    template: "%s | مزه‌دونه",
  },
  description:
    "فروشگاه آنلاین آجیل، خشکبار، میوه خشک و هدیه‌های خوش‌طعم با انتخاب شفاف و ارسال مطمئن.",
  openGraph: {
    type: "website",
    locale: "fa_IR",
    siteName: "مزه‌دونه",
    title: "مزه‌دونه | خوش‌خوراکِ هر روز",
    description: "آجیل تازه، میوه خشک و شیرینی‌های خانگی کم‌شکر.",
  },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="fa" dir="rtl">
      <body>{children}</body>
    </html>
  );
}
