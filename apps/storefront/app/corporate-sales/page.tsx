import type { Metadata } from "next";
import CorporateSalesLanding from "../corporate-sales-page";
import { pageMetadata } from "../seo";

export const metadata: Metadata = pageMetadata("/corporate-sales", "هدیه سازمانی و خرید آجیل سازمانی", "برای هدیه به کارکنان، مشتریان و پذیرایی سازمانی، ترکیب آجیل و مغزیجات متناسب با تعداد و بودجهٔ خود پیشنهاد بگیرید. درخواست بدون ثبت‌نام و پرداخت.");

export default function CorporateSalesPage() {
  return <CorporateSalesLanding />;
}
