import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { demoProducts } from "../../demo/catalog";
import { LiveProductPage } from "../../commerce-pages";

export function generateStaticParams() { return demoProducts.map((product) => ({ slug: product.id })); }
export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }): Promise<Metadata> {
  const { slug } = await params;
  const fallback = demoProducts.find((item) => item.id === slug);
  const apiBase = (process.env.NEXT_PUBLIC_MAZEDUNEH_API_URL?.trim() || process.env.NEXT_PUBLIC_MAZEDUNEH_API_BASE_URL?.trim() || "").replace(/\/$/, "");
  if (apiBase) {
    try {
      const response = await fetch(apiBase + "/api/v1/products/" + encodeURIComponent(slug), { cache: "no-store" });
      if (response.ok) {
        const product = await response.json() as { title?: string; seoTitle?: string; seoDescription?: string; shortDescription?: string };
        return {
          title: product.seoTitle || product.title || fallback?.title || "محصول",
          description: product.seoDescription || product.shortDescription || fallback?.subtitle || "محصول مزه‌دونه",
        };
      }
    } catch {
      // Fall back to the local preview metadata when the API is unavailable during build.
    }
  }
  return { title: fallback?.seoTitle || fallback?.title || "محصول پیدا نشد", description: fallback?.seoDescription || fallback?.subtitle || "محصول موردنظر پیدا نشد." };
}
export default async function ProductRoute({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const product = demoProducts.find((item) => item.id === slug);
  if (!product && !process.env.NEXT_PUBLIC_MAZEDUNEH_API_URL && !process.env.NEXT_PUBLIC_MAZEDUNEH_API_BASE_URL) notFound();
  return <LiveProductPage slug={slug} />;
}
