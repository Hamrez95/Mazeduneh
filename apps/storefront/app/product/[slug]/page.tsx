import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { demoProducts } from "../../demo/catalog";
import { LiveProductPage } from "../../commerce-pages";

export function generateStaticParams() {
  const apiConfigured = process.env.NEXT_PUBLIC_MAZEDUNEH_DEMO_MODE !== 'true' && Boolean(
    process.env.NEXT_PUBLIC_MAZEDUNEH_API_URL?.trim()
    || process.env.NEXT_PUBLIC_MAZEDUNEH_API_BASE_URL?.trim(),
  );
  return apiConfigured ? [] : demoProducts.map((product) => ({ slug: product.id }));
}
export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }): Promise<Metadata> {
  const { slug } = await params;
  const apiBase = process.env.NEXT_PUBLIC_MAZEDUNEH_DEMO_MODE === 'true' ? '' : (process.env.MAZEDUNEH_API_INTERNAL_URL?.trim() || process.env.NEXT_PUBLIC_MAZEDUNEH_API_URL?.trim() || process.env.NEXT_PUBLIC_MAZEDUNEH_API_BASE_URL?.trim() || "").replace(/\/$/, "");
  const fallback = apiBase ? undefined : demoProducts.find((item) => item.id === slug);
  if (apiBase) {
    try {
      // Metadata can use ISR; live price/stock still come from the uncached client API.
      // A no-store fetch here turns an on-demand SSG route dynamic and causes a production 500.
      const response = await fetch(apiBase + "/api/v1/products/" + encodeURIComponent(slug), { next: { revalidate: 60 }, signal: AbortSignal.timeout(3000) });
      if (response.ok) {
        const product = await response.json() as { title?: string; seoTitle?: string; seoDescription?: string; shortDescription?: string };
        return {
          title: product.seoTitle || product.title || fallback?.title || "محصول",
          description: product.seoDescription || product.shortDescription || fallback?.subtitle || "محصول مزه‌دونه",
        };
      }
    } catch {
      // Keep an unavailable metadata API from delaying the product page indefinitely.
    }
  }
  return { title: fallback?.seoTitle || fallback?.title || (apiBase ? "محصول" : "محصول پیدا نشد"), description: fallback?.seoDescription || fallback?.subtitle || (apiBase ? "اطلاعات محصول مزه‌دونه" : "محصول موردنظر پیدا نشد.") };
}
export default async function ProductRoute({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const product = demoProducts.find((item) => item.id === slug);
  const preview = process.env.NEXT_PUBLIC_MAZEDUNEH_DEMO_MODE === 'true' || (!process.env.MAZEDUNEH_API_INTERNAL_URL && !process.env.NEXT_PUBLIC_MAZEDUNEH_API_URL && !process.env.NEXT_PUBLIC_MAZEDUNEH_API_BASE_URL);
  if (!product && preview) notFound();
  return <LiveProductPage slug={slug} />;
}
