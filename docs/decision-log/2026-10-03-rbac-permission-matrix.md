# تصمیم: ماتریس permission برای نقش‌های پنل

## مسئله

API مدیریتی اولیه همهٔ tokenهای معتبر را عملاً به Owner محدود می‌کرد. این برای شروع امن است، اما با اضافه‌شدن کاربر انبار، فروش، حسابداری و پشتیبانی قابل توسعه نیست.

## تصمیم

`AdminPermissionCatalog` نقش‌ها و permissionهای پایه را در یک محل تعریف می‌کند. نقش پیش‌فرض همچنان `Owner` است تا رفتار فعلی تغییر نکند. برای محیط‌های توسعه یا استقرار موقت، نقش و override permission از تنظیمات runtime خوانده می‌شوند:

- `Admin__Role` اختیاری و پیش‌فرض `Owner`
- `Admin__Permissions` اختیاری و به‌صورت comma-separated؛ اگر خالی باشد permissionهای نقش استفاده می‌شوند

فیلتر موجود `OwnerAuthorizationFilter` بعد از اعتبارسنجی token، permission لازم را از مسیر و روش HTTP تشخیص می‌دهد و برای token معتبر اما فاقد permission پاسخ `403` برمی‌گرداند. token نامعتبر همچنان `401` است. Owner برای حفظ سازگاری به همهٔ permissionها دسترسی دارد.

## نقش‌های seed‌شده

| نقش | حوزهٔ اصلی |
|---|---|
| Owner | همهٔ عملیات |
| StoreManager | عملیات کامل فروشگاه بدون Audit حساس |
| SalesOperator | سفارش، مشتری و فروش سازمانی |
| WarehouseOperator | موجودی، انبار و fulfillment |
| Accountant | گزارش، سفارش و داده‌های قیمت برای محاسبه |
| CustomerSupport | سفارش و مشتری |
| CorporateSales | فروش سازمانی و مشتری |
| ContentManager | محصول، دسته‌بندی و محتوا |
| MarketingManager | محصول، گزارش، قیمت/کمپین و محتوا |
| ReadOnlyAnalyst | مشاهدهٔ داشبورد و گزارش‌های عملیاتی بدون write/export |

## مرز این Slice

این Slice مدل policy و enforcement را آماده می‌کند، اما حساب‌های چندکاربره، جدول membership، مدیریت نقش از UI، MFA و step-up approval در Sliceهای بعدی Issue #91 هستند. هیچ secret یا credential در مستندات ثبت نمی‌شود.
