export type ShippingMethodOption = { code: string; title: string; price: number; freeAbove: number; isActive: boolean };
export type PublicCommerceSettings = { taxRatePercent: number; shippingMethods: ShippingMethodOption[] };

// These values are only for the explicitly disconnected design preview.
export const previewCommerceSettings: PublicCommerceSettings = {
  taxRatePercent: 0,
  shippingMethods: [{ code: "post", title: "پست", price: 750000, freeAbove: 15000000, isActive: true }],
};

export function parseCommerceSettings(value: unknown): PublicCommerceSettings | null {
  if (!value || typeof value !== "object") return null;
  const settings = value as PublicCommerceSettings;
  if (!Number.isFinite(settings.taxRatePercent) || settings.taxRatePercent < 0 || settings.taxRatePercent > 100 || !Array.isArray(settings.shippingMethods)) return null;
  const codes = new Set<string>();
  for (const method of settings.shippingMethods) {
    if (!method || typeof method.code !== "string" || !method.code.trim() || typeof method.title !== "string" ||
        !Number.isFinite(method.price) || method.price < 0 || !Number.isFinite(method.freeAbove) || method.freeAbove < 0 ||
        typeof method.isActive !== "boolean" || codes.has(method.code.toLowerCase())) return null;
    codes.add(method.code.toLowerCase());
  }
  return settings;
}

export function defaultShippingMethod(settings: PublicCommerceSettings | null) {
  const active = settings?.shippingMethods.filter(method => method.isActive) ?? [];
  return active.find(method => method.code === "post") ?? active[0];
}

/** Settings and arithmetic use rials; display/cart prices use tomans. */
export function estimateCommerce(subtotalTomans: number, settings: PublicCommerceSettings | null, code?: string) {
  const method = code ? settings?.shippingMethods.find(item => item.code === code && item.isActive) : defaultShippingMethod(settings);
  if (!settings || !method || !Number.isFinite(subtotalTomans) || subtotalTomans < 0) return null;
  const subtotalRials = subtotalTomans * 10;
  const shipping = subtotalRials === 0 || (method.freeAbove > 0 && subtotalRials >= method.freeAbove) ? 0 : method.price / 10;
  const tax = Math.round((subtotalRials * settings.taxRatePercent / 100 + Number.EPSILON) * 100) / 1000;
  return { shipping, tax, total: subtotalTomans + shipping + tax, method };
}
