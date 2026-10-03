# تصمیم معماری: foundation مدیریت کاربران و عضویت فروشگاه

تاریخ: ۳ اکتبر ۲۰۲۶  
Issue: #91

## تصمیم

برای آماده‌سازی RBAC و Multi-store، جدول `admin_users` با کلید `store_id` اضافه شد. این جدول اطلاعات هویتی مدیریتی و عضویت فروشگاه را نگه می‌دارد: ایمیل، نام نمایشی، نقش، وضعیت فعال و زمان غیرفعال‌سازی.

## مرز امنیتی

- endpointهای فهرست، ساخت و فعال/غیرفعال‌سازی فقط با token معتبر و permissionهای Owner قابل استفاده‌اند.
- رمز عبور، access token و secret در جدول یا پاسخ API ذخیره نمی‌شوند.
- seed اولیه فقط membership مربوط به `Admin:Email` فعلی را با نقش Owner ایجاد/همگام می‌کند.
- uniqueness روی `(store_id, email)` از عضویت تکراری در یک فروشگاه جلوگیری می‌کند.
- خروجی نقش، permissionهای محاسبه‌شده را برای طراحی UI آینده ارائه می‌دهد، اما هنوز login را به membership متصل نمی‌کند.

## قرارداد فعلی

- `GET /api/v1/admin/users?storeId=...`
- `POST /api/v1/admin/users`
- `PATCH /api/v1/admin/users/{id}/status`

اعتبارسنجی ایمیل، نام نمایشی و نقش در API انجام می‌شود و conflict ایمیل با HTTP 409 برمی‌گردد.

## گام‌های بعدی

1. ساخت UI مدیریت کاربران و نقش‌ها با مسیر روشن، حالت‌های loading/empty/error/forbidden/success/stale و تست responsive/accessibility با `@frontend-design`.
2. resolve کردن Store Context از hostname/session/token به‌جای اعتماد به query string.
3. اتصال احراز هویت واقعی به membershipها، سپس MFA و step-up approval برای عملیات حساس.
4. افزودن integration test جداسازی دو فروشگاه و audit تغییرات membership.
