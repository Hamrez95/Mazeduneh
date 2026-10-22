export type ReceiptLine = { productTitle: string; variantLabel: string; quantity: number; lineTotal: number; sku: string };

export type CheckoutReceipt = {
  name: string; orderId: string; receiptToken: string; payable: number; tax: number; shipping: number;
  expiresAt: string; state: string; paymentOutcome?: "failed" | "review" | "success"; sandboxAuthority?: string;
  subtotal?: number; discount?: number; shippingMethod?: string; lines?: ReceiptLine[];
};

const closingLines = [
  "امیدواریم اولین لقمه، لبخند روی لبت بیاورد. نوش جان!",
  "این بسته بهانه‌ای است برای یک حال خوب؛ سهم خوشمزگی امروزت، نوش جان!",
  "برای وقت‌های چای، گپ و استراحتت، یک همراه خوشمزه انتخاب کردی. نوش جان!",
  "خوشحالیم مزه‌دونه مهمان لحظه‌های توست. به خوشی بخوری و لبخند بزنی!",
];

export function paymentIsConfirmed(state: string) {
  return ["Paid", "Preparing", "Shipped", "Delivered"].includes(state);
}

export function receiptClosingLine(orderId: string) {
  const seed = Number.parseInt(orderId.replaceAll("-", "").slice(0, 2), 16);
  return closingLines[(Number.isFinite(seed) ? seed : 0) % closingLines.length];
}
