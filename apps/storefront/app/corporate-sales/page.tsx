import type { Metadata } from "next";
import CorporateSalesLanding from "../corporate-sales-page";

export const metadata: Metadata = {
  title: "فروش سازمانی و هدایای مناسبتی | مزه‌دونه",
  description: "ساخت پک‌های هدیه سازمانی خوش‌طعم و اختصاصی مزه‌دونه برای تیم‌ها و سازمان‌ها.",
};

export default function CorporateSalesPage() {
  return <CorporateSalesLanding />;
}
