import type { Metadata } from "next";
import type { ApiProduct } from "./api-catalog";

export function siteUrl(path = "/") {
  const base = new URL(process.env.NEXT_PUBLIC_SITE_URL || "https://mazeduneh.ir");
  return new URL(path, base.origin).toString();
}

export function pageMetadata(path: string, title: string, description: string, index = true): Metadata {
  return { title, description, alternates: { canonical: siteUrl(path) },
    robots: { index, follow: true },
    openGraph: { title, description, url: siteUrl(path), locale: "fa_IR", type: "website", siteName: "مزه‌دونه" },
  };
}

export function JsonLd({ data }: { data: Record<string, unknown> }) {
  const json = JSON.stringify(data).replace(/</g, "\\u003c").replace(/\u2028/g, "\\u2028").replace(/\u2029/g, "\\u2029");
  return <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: json }} />;
}

export function breadcrumbs(items: Array<{ name: string; path: string }>) {
  return { "@context": "https://schema.org", "@type": "BreadcrumbList",
    itemListElement: items.map((item, index) => ({ "@type": "ListItem", position: index + 1, name: item.name, item: siteUrl(item.path) })),
  };
}

export function productStructuredData(product: ApiProduct) {
  // API prices are already IRR. Do not use the UI's toman conversion here.
  if (product.currency !== "IRR" || !product.isPublished) return undefined;
  const variants = (product.variants || []).filter(v => Number.isSafeInteger(v.price) && v.price > 0);
  if (!variants.length) return undefined;
  const url = siteUrl(`/product/${encodeURIComponent(product.slug)}`);
  const mediaBase = (process.env.NEXT_PUBLIC_MAZEDUNEH_API_URL || process.env.NEXT_PUBLIC_MAZEDUNEH_API_BASE_URL || siteUrl()).replace(/\/$/, "") + "/";
  const images = [product.primaryImage, ...(product.galleryImages || [])].flatMap(value => {
    if (!value || /^(?:data|javascript):/i.test(value)) return [];
    try { const image = new URL(value, mediaBase); return /^https?:$/.test(image.protocol) ? [image.toString()] : []; } catch { return []; }
  });
  return { "@context": "https://schema.org", "@type": "Product", "@id": `${url}#product`,
    name: product.title, description: product.description || product.shortDescription,
    url, image: [...new Set(images)], brand: { "@type": "Brand", name: "مزه‌دونه" }, category: product.category,
    offers: { "@type": "AggregateOffer", priceCurrency: "IRR", lowPrice: Math.min(...variants.map(v => v.price)),
      highPrice: Math.max(...variants.map(v => v.price)), offerCount: variants.length,
      offers: variants.map(v => ({ "@type": "Offer", name: v.displayLabel, price: v.price, priceCurrency: "IRR", url,
        availability: `https://schema.org/${v.availablePackages > 0 ? "InStock" : "OutOfStock"}` })),
    },
  };
}
