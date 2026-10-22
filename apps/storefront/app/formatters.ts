/**
 * Presentation rules for customer-facing Persian copy.
 *
 * The API deliberately keeps numeric values as numbers. Conversion happens only
 * at the UI boundary so that price, stock and quantities remain safe to sort,
 * calculate and manage from the admin panel.
 */
const persianNumber = new Intl.NumberFormat("fa-IR");

export function formatNumber(value: number) {
  return persianNumber.format(Number.isFinite(value) ? value : 0);
}

/** Convert API rial amounts without rounding away a fractional toman. */
export function rialsToTomans(rials: number) {
  return Number.isFinite(rials) ? rials / 10 : 0;
}

// Round only at the presentation boundary; never feed this back into pricing.
const wholeMoney = new Intl.NumberFormat("fa-IR", { maximumFractionDigits: 0 });
export function formatMoney(tomans: number) {
  return wholeMoney.format(Number.isFinite(tomans) ? tomans : 0);
}

export function formatRialsAsTomans(rials: number) {
  return formatMoney(rialsToTomans(rials));
}

export function toPersianDigits(value: string | number) {
  return String(value)
    .replace(/[0-9]/g, (digit) => "۰۱۲۳۴۵۶۷۸۹"[Number(digit)])
    .replace(/[٠-٩]/g, (digit) => "۰۱۲۳۴۵۶۷۸۹"["٠١٢٣٤٥٦٧٨٩".indexOf(digit)]);
}

export function formatInventory(value: number) {
  return `${formatNumber(value)} موجود`;
}
