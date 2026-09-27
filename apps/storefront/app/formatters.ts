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

export function toPersianDigits(value: string | number) {
  return String(value)
    .replace(/[0-9]/g, (digit) => "۰۱۲۳۴۵۶۷۸۹"[Number(digit)])
    .replace(/[٠-٩]/g, (digit) => "۰۱۲۳۴۵۶۷۸۹"["٠١٢٣٤٥٦٧٨٩".indexOf(digit)]);
}

export function formatInventory(value: number) {
  return `${formatNumber(value)} موجود`;
}
