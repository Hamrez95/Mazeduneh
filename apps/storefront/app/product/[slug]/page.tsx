import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { demoProducts } from "../../demo/catalog";
import { ProductPage } from "../../commerce-pages";

export function generateStaticParams() { return demoProducts.map((product) => ({ slug: product.id })); }
export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }): Promise<Metadata> {
  const { slug } = await params;
  const product = demoProducts.find((item) => item.id === slug);
  return { title: product?.title ?? "محصول پیدا نشد", description: product?.subtitle ?? "محصول موردنظر پیدا نشد." };
}
export default async function ProductRoute({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const product = demoProducts.find((item) => item.id === slug);
  if (!product) notFound();
  return <ProductPage product={product} />;
}
