import type { MetadataRoute } from "next";
import { readServerCatalog, hasServerCatalog } from "./server-catalog";
import { siteUrl } from "./seo";
import { giftGuides } from "./gifts/guides";
export const dynamic = "force-static";
export const revalidate = 300;
export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const catalog = await readServerCatalog();
  const paths = ["/", "/shop", "/gifts", "/corporate-sales", "/about", "/contact", "/shipping", "/returns", "/faq", "/privacy", "/terms", ...giftGuides.map(g => `/gifts/${g.slug}`)];
  // Preview fixtures are intentionally excluded from product discovery.
  if (hasServerCatalog && catalog) paths.push(...catalog.products.map(p => `/product/${encodeURIComponent(p.id)}`));
  return [...new Set(paths)].map(path => ({ url: siteUrl(path) }));
}
