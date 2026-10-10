import type { Metadata } from "next";
import { CartPage } from "../commerce-pages";
export const metadata: Metadata = { title: "سبد خرید" };
export default function CartRoute() { return <CartPage />; }
