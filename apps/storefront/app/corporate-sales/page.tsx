import type { Metadata } from "next";
import CorporateSalesLanding from "../corporate-sales-page";

export const metadata: Metadata = {
  title: "هدیه سازمانی و خرید آجیل سازمانی | مزه‌دونه",
  description: "برای هدیه به کارکنان، مشتریان و پذیرایی سازمانی، ترکیب آجیل و مغزیجات متناسب با تعداد و بودجهٔ خود پیشنهاد بگیرید. درخواست بدون ثبت‌نام و پرداخت.",
};

export default function CorporateSalesPage() {
  return <CorporateSalesLanding />;
}
