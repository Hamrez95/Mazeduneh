import type { Metadata } from "next";
import { CatalogPage } from "../commerce-pages";

export const metadata: Metadata = { title: "همهٔ محصولات", description: "آجیل، میوه خشک، لواشک و شیرینی‌های مزه‌دونه را ببین و انتخاب کن." };
export default function ShopRoute() { return <CatalogPage />; }
