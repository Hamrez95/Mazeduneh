import type { Metadata } from "next";
import { CatalogPage } from "../commerce-pages";
import { pageMetadata } from "../seo";

export const metadata: Metadata = pageMetadata("/shop", "خرید آجیل و میان‌وعده", "محصولات منتشرشدهٔ مزه‌دونه، بسته‌ها و قیمت هر انتخاب را ببین و مقایسه کن.");
export default function ShopRoute() { return <CatalogPage />; }
