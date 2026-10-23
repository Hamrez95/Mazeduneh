import type { Metadata } from "next";
import { CheckoutPage } from "../commerce-pages";
export const metadata: Metadata = { robots: { index: false, follow: true }, title: "اطلاعات تحویل و تسویه" };
export default function CheckoutRoute() { return <CheckoutPage />; }
