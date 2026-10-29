import type { Metadata } from "next";
import "./globals.css";
import "./commerce.css";
import { CartProvider } from "./cart-context";
import { CatalogProvider } from "./catalog-context";
import { readServerCatalog } from "./server-catalog";
import { JsonLd, siteUrl } from "./seo";

export const metadata: Metadata = {
  metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL ?? "https://mazeduneh.ir"),
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

export default async function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  const catalog = await readServerCatalog();
  return (
    <html lang="fa" dir="rtl" suppressHydrationWarning>
      <head><meta name="enamad" content="23492933" /></head>
      <body><JsonLd data={{ "@context": "https://schema.org", "@type": "Organization", "@id": siteUrl("/#organization"), name: "مزه‌دونه", url: siteUrl(), logo: siteUrl("/mazedoone-mark.svg") }} /><CatalogProvider initialState={catalog}><CartProvider>{children}</CartProvider></CatalogProvider></body>
    </html>
  );
}
