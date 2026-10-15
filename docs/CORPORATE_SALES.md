# فروش سازمانی

ماژول فروش سازمانی از سه بخش مستقل تشکیل شده است:

- فروشگاه: بنر homepage و landing page در مسیر `/corporate-sales`.
- API: ثبت عمومی درخواست، مشاهدهٔ محدود با توکن در header، و عملیات محافظت‌شدهٔ ادمین در `/api/v1/admin/corporate-requests`.
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

## کاتالوگ بسته‌ها

- `GET /api/v1/corporate-packages` فهرست عمومی بسته‌های فعال، اقلام و قیمت هر بسته به ریال را برمی‌گرداند.
- `GET /api/v1/admin/corporate-requests/packages` فهرست همهٔ بسته‌ها برای کاربران مجاز فروش سازمانی.
- `PUT /api/v1/admin/corporate-requests/packages/{code}` ایجاد یا ویرایش بسته؛ actor و before/after در Audit ثبت می‌شود.
- بدنهٔ `PUT` شامل `name`, `description`, `isActive` و `items` است؛ هر قلم `name`, `quantity`, `unit`, `unitPrice` دارد. قیمت قلم به ریال است و قیمت هر بسته از مجموع `quantity × unitPrice` محاسبه می‌شود.
- Storefront برای انتخاب کاتالوگ `packageCode` می‌فرستد. نام، اقلام، قیمت هر بسته، تعداد و جمع تخمینی در snapshot مستقل درخواست ذخیره می‌شوند؛ ویرایش بعدی، درخواست‌های قبلی را تغییر نمی‌دهد. بستهٔ اختصاصی و درخواست‌های قدیمی می‌توانند بدون کد بمانند.

## API اصلی

- `POST /api/v1/corporate-requests` ثبت درخواست عمومی
- `POST /api/v1/corporate-requests/upload` آپلود لوگو
- `GET /api/v1/corporate-requests/{id}` مشاهدهٔ محدود مشتری با header `X-Corporate-Request-Token`؛ توکن در query string یا `Location` قرار نمی‌گیرد.
- `GET /api/v1/admin/corporate-requests` فهرست با فیلتر
- `GET /api/v1/admin/corporate-requests/{id}` جزئیات
- `PATCH /api/v1/admin/corporate-requests/{id}/status` تغییر وضعیت و تاریخچه
- `POST /api/v1/admin/corporate-requests/{id}/assign` اختصاص مسئول
- `POST /api/v1/admin/corporate-requests/{id}/follow-up` ثبت یادآور پیگیری
- `POST /api/v1/admin/corporate-requests/{id}/notes` یادداشت داخلی
- `POST /api/v1/admin/corporate-requests/{id}/messages` ثبت پیام مشتری/پاسخ
- `POST /api/v1/admin/corporate-requests/{id}/proforma` آپلود پیش‌فاکتور

Migration `corporate-sales/001-bootstrap` جدول درخواست، تاریخچهٔ تغییر وضعیت و پیام‌ها را ایجاد می‌کند. Migration `002-package-catalog-snapshots` کاتالوگ بسته، اقلام و snapshot را اضافه می‌کند. کاتالوگ در شروع خالی است تا هیچ قیمت یا ترکیب تجاری بدون تأیید مدیر ساخته نشود؛ بسته‌ها را از API محافظت‌شدهٔ بالا تعریف کنید. ارسال پیامک/ایمیل واقعی عمداً به provider اعلان مستقل واگذار شده و فعلاً تاریخچهٔ پیام در دیتابیس ثبت می‌شود.
