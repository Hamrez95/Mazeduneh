import { notFound } from "next/navigation";
import { demoProducts } from "../../demo/catalog";
import { LiveProductPage } from "../../commerce-pages";
import { mapApiProduct } from "../../api-catalog";
import { readPublishedProduct, hasServerCatalog } from "../../server-catalog";
import { breadcrumbs, JsonLd, pageMetadata, productStructuredData } from "../../seo";

export function generateStaticParams() {
  return hasServerCatalog ? [] : demoProducts.map(product => ({ slug: product.id }));
}

export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const { product } = await readPublishedProduct(slug);
  const preview = hasServerCatalog ? undefined : demoProducts.find(p => p.id === slug);
  return pageMetadata(`/product/${encodeURIComponent(slug)}`, product?.seoTitle || product?.title || preview?.seoTitle || preview?.title || "محصول",
    product?.seoDescription || product?.shortDescription || preview?.subtitle || "اطلاعات محصول مزه‌دونه", hasServerCatalog && Boolean(product));
}

export default async function ProductRoute({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const { product, missing } = await readPublishedProduct(slug);
  const preview = demoProducts.find(p => p.id === slug);
  if (missing || (!hasServerCatalog && !preview)) notFound();
  const initialProduct = product ? mapApiProduct(product) ?? undefined : undefined;
  const structured = product ? productStructuredData(product) : undefined;
  return <>
    {structured && <JsonLd data={structured} />}
    {product && <JsonLd data={breadcrumbs([{ name: "خانه", path: "/" }, { name: "فروشگاه", path: "/shop" }, { name: product.title, path: `/product/${encodeURIComponent(slug)}` }])} />}
    <LiveProductPage key={slug} slug={slug} initialProduct={initialProduct} />
  </>;
}
