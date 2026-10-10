# اتصال زیبال

پرداخت واقعی فقط وقتی فعال می‌شود که هر سه تنظیم زیر در secret manager محیط API قرار گرفته باشند:

```text
Payments__Zibal__Merchant=<merchant-code>
Payments__Zibal__CallbackUrl=https://api.<domain>/api/v1/payments/zibal/callback
Payments__Zibal__ReturnUrl=https://<storefront-domain>/checkout
```

Merchant Code هرگز نباید در Storefront، پنل Admin، فایل `.env` نسخه‌شده یا log قرار گیرد. برای Staging می‌توان از Merchant آزمایشی `zibal` استفاده کرد. URLهای Callback و Return باید HTTPS عمومی باشند. دامنهٔ فروشگاه، Referer و IP سرور API را در پنل زیبال مطابق تنظیمات درگاه ثبت کنید.

## مسیر پرداخت

1. Storefront سفارش را ایجاد می‌کند و `receiptToken` فقط در Session Storage همان مرورگر نگه داشته می‌شود.
2. API مبلغ snapshot سفارش را به ریال به `/v1/request` زیبال می‌فرستد و مشتری را به صفحهٔ پرداخت منتقل می‌کند.
3. زیبال مشتری را به Callback API بازمی‌گرداند. API مقدار `trackId` را از دیتابیس پیدا می‌کند و خودش `/v1/verify` را فراخوانی می‌کند.
4. API پاسخ verify را بررسی می‌کند و در صورت نیاز از inquiry برای تشخیص وضعیت قطعی استفاده می‌کند؛ فقط نتیجهٔ `status=1` همراه با مبلغ و `orderId` برابر، payment و order را به `Succeeded` و `Paid` تغییر می‌دهد.
5. API مشتری را به Checkout فروشگاه برمی‌گرداند؛ Storefront با `receiptToken` ذخیره‌شده، وضعیت نهایی سفارش را نمایش می‌دهد.

Callback تکراری بدون ایجاد transition دوم همان نتیجه را برمی‌گرداند. پاسخ قطعی زیبال مبنی‌بر پرداخت‌نشدن، تلاش پرداخت را ناموفق ثبت می‌کند؛ سفارش در `AwaitingPayment` می‌ماند و دکمهٔ تلاش دوباره یک `trackId` جدید می‌گیرد. خطای شبکه یا پاسخ نامشخص به‌عنوان شکست قطعی ثبت نمی‌شود تا پرداختی که وضعیتش روشن نیست گم نشود.

## پیش از Production

- دامنهٔ نهایی و Callback را در پنل زیبال ثبت کنید.
- IP عمومی سرور API را در allow-list زیبال ثبت کنید.
- کد رهگیری مالیاتی، ای‌نماد، مجوز و شبا را طبق فرایند زیبال تکمیل کنید.
- یک پرداخت موفق، لغو پرداخت، callback تکراری و قطع ارتباط callback را در Staging آزمایش کنید.

منابع: [راهنمای فعال‌سازی زیبال](https://help.zibal.ir/article/how-get-and-set-up-online-payment-gateway/) و [مستندات IPG](https://help.zibal.ir/ipg/).
