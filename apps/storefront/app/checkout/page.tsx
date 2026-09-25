import type { Metadata } from "next";
import { CheckoutPage } from "../commerce-pages";
export const metadata: Metadata = { title: "اطلاعات تحویل و تسویه" };
export default function CheckoutRoute() { return <CheckoutPage />; }
