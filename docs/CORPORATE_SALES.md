# فروش سازمانی

ماژول فروش سازمانی از سه بخش مستقل تشکیل شده است:

- فروشگاه: بنر homepage و landing page در مسیر `/corporate-sales`.
- API: ثبت عمومی درخواست، مشاهدهٔ عمومی با access token، و عملیات محافظت‌شدهٔ ادمین در `/api/v1/admin/corporate-requests`.
- پنل فعال Flutter: گزینهٔ «فروش سازمانی» در `apps/admin/lib/main.dart`.

## تنظیمات محیطی

برای ثبت واقعی درخواست‌ها، API باید connection string بخش `Catalog` را داشته باشد. ذخیرهٔ لوگو و پیش‌فاکتور از همان `MediaStorage` موجود استفاده می‌کند:

```json
{
  "Media": {
    "Provider": "S3",
    "PublicBaseUrl": "https://api.example.com",
    "S3": {
      "Endpoint": "https://s3.example.com",
      "Bucket": "mazeduneh-media",
      "Region": "us-east-1",
      "AccessKey": "<secret>",
      "SecretKey": "<secret>",
      "ForcePathStyle": true
    }
  }
}
```

`Local` برای توسعه مناسب است و `S3` یا `s3-compatible` برای محیط serverless/production استفاده می‌شود. secretها فقط از environment/config secret store خوانده شوند.

برای تماس در صفحهٔ landing، این متغیرهای عمومی storefront اختیاری هستند:

- `NEXT_PUBLIC_CORPORATE_PHONE`
- `NEXT_PUBLIC_CORPORATE_WHATSAPP` (فقط شمارهٔ بین‌المللی بدون `+` و فاصله)

## وضعیت‌ها

`New`, `Reviewing`, `Contacted`, `NeedsInformation`, `ProformaSent`, `Negotiating`, `Approved`, `Preparing`, `Shipped`, `Finalized`, `Cancelled`

عنوان فارسی هر وضعیت در پنل و پاسخ API قابل ترجمه است و وضعیت خام برای منطق و گزارش‌گیری حفظ می‌شود.

## API اصلی

- `POST /api/v1/corporate-requests` ثبت درخواست عمومی
- `POST /api/v1/corporate-requests/upload` آپلود لوگو
- `GET /api/v1/corporate-requests/{id}?accessToken=...` مشاهدهٔ محدود مشتری
- `GET /api/v1/admin/corporate-requests` فهرست با فیلتر
- `GET /api/v1/admin/corporate-requests/{id}` جزئیات
- `PATCH /api/v1/admin/corporate-requests/{id}/status` تغییر وضعیت و تاریخچه
- `POST /api/v1/admin/corporate-requests/{id}/assign` اختصاص مسئول
- `POST /api/v1/admin/corporate-requests/{id}/follow-up` ثبت یادآور پیگیری
- `POST /api/v1/admin/corporate-requests/{id}/notes` یادداشت داخلی
- `POST /api/v1/admin/corporate-requests/{id}/messages` ثبت پیام مشتری/پاسخ
- `POST /api/v1/admin/corporate-requests/{id}/proforma` آپلود پیش‌فاکتور

Migration `corporate-sales/001-bootstrap` جدول درخواست، تاریخچهٔ تغییر وضعیت و پیام‌ها را ایجاد می‌کند. ارسال پیامک/ایمیل واقعی عمداً به provider اعلان مستقل واگذار شده و فعلاً تاریخچهٔ پیام در دیتابیس ثبت می‌شود.
