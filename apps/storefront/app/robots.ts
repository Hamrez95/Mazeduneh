import type { MetadataRoute } from "next";
import { siteUrl } from "./seo";
export const dynamic = "force-static";
export default function robots(): MetadataRoute.Robots {
  // Cart, checkout and profile declare noindex in their metadata. Keep them
  // crawlable so search engines can actually read that instruction.
  return { rules: [{ userAgent: "*", allow: "/", disallow: ["/api/", "/admin/"] }], sitemap: siteUrl("/sitemap.xml") };
}
