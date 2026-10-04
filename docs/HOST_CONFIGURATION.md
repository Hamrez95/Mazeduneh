# اتصال مستقل از میزبان

خرید لیارا پیش‌نیاز اجرای پروژه نیست. هر میزبان دارای Docker برای API دات‌نت، خروجی Next.js و خروجی Flutter Web، همراه با PostgreSQL و Storage سازگار با S3 قابل استفاده است. دامنه‌ها، host و کلیدهای سرویس در تنظیمات محیط وارد می‌شوند؛ منطق فروشگاه به نام سرویس‌دهنده وابسته نیست. فایل‌های liara.json صرفاً نمونهٔ پیکربندی آن سرویس‌اند.

## قرارداد اتصال واقعی

| بخش | تنظیمات موجود پروژه | زمان تنظیم |
|---|---|---|
| API → PostgreSQL | ConnectionStrings__Catalog شامل Host/Port/Database/Username/Password و SSL Mode | زمان اجرای API؛ فقط سرور |
| API → S3 | Media__Provider=S3 و Media__S3__Endpoint/Bucket/Region/AccessKey/SecretKey/ForcePathStyle | زمان اجرای API؛ فقط سرور |
| آدرس عمومی تصاویر API | Media__PublicBaseUrl | زمان اجرای API |
| ورود مدیر | Admin__Email/PasswordHash/TokenSigningKey | زمان اجرای API؛ secret manager |
| مبداهای مجاز مرورگر | Cors__AllowedOrigins__0 و __1 | آدرس دقیق HTTPS فروشگاه و پنل |
| فروشگاه → API | NEXT_PUBLIC_MAZEDUNEH_API_URL | هنگام build فروشگاه؛ عمومی |
| پنل → API | MAZEDUNEH_API_BASE_URL | هنگام build پنل با dart-define؛ عمومی |
| آدرس‌های برند/پنل | NEXT_PUBLIC_SITE_URL و NEXT_PUBLIC_MAZEDUNEH_ADMIN_URL | هنگام build فروشگاه؛ عمومی |

نمونهٔ بدون اطلاعات واقعی در services/api/.env.example و apps/storefront/.env.example است. API دات‌نت فایل .env را خودکار نمی‌خواند؛ مقادیر باید در Environment یا secret manager میزبان تنظیم شوند. Dockerfile هر سرویس از پوشهٔ خود ساخته می‌شود. پنل اکنون lib/main.dart را می‌سازد؛ همان entry point فعال و تست‌شده در CI. lib/secure_main.dart یک پنل قدیمی‌تر است و مسیر انتشار فعلی نیست.

## اطلاعاتی که پس از خرید سرویس وارد می‌شوند

برای دیتابیس: host، port، نام دیتابیس، username/password و گواهی/شرایط TLS سرویس. فرمت مورد استفاده Npgsql است: `Host=...;Port=...;Database=...;Username=...;Password=...;SSL Mode=VerifyFull`. URI ارائه‌شده توسط سرویس را به این پارامترها تبدیل کنید؛ آن را بدون بررسی فرمت به Npgsql ندهید. CA موردنیاز میزبان را نصب یا با تنظیم Root Certificate معرفی کنید؛ بررسی گواهی غیرفعال نشود.

برای Storage: endpoint، bucket، region و کلید با دسترسی محدود همان باکت. برنامه همین حالا AWSSDK.S3 و provider مستقل دارد؛ برای میزبان جدید فقط تنظیمات عوض می‌شود. نمونهٔ endpoint عمومی در مستندات سرویس به معنی endpoint یا credential حساب شما نیست. کلیدهای نمونهٔ سایت‌ها را به پروژه منتقل نکنید.

اطلاعات عمومی از مستندات رسمی بررسی شده است:

- [لینک اتصال عمومی/خصوصی دیتابیس لیارا](https://docs.liara.ir/dbaas/details/connection-links/): اطلاعات حساب در صفحهٔ اتصال دیتابیس ایجادشده قرار دارد.
- [اتصال .NET به S3 لیارا](https://docs.liara.ir/object-storage/how-tos/connect-via-platform/dotnet/): endpoint/bucket از پنل و کلید از ساخت کلید محدود گرفته می‌شود.
- [اتصال PostgreSQL در Supabase](https://supabase.com/docs/guides/database/connecting-to-postgres): connection مستقیم یا session pooler با توجه به شبکهٔ میزبان. در حالت API-managed، جدول‌های تجاری نباید در Data API عمومی قابل دسترسی باشند.
- [TLS در Npgsql](https://www.npgsql.org/doc/security.html): انتخاب VerifyFull و زنجیرهٔ اعتماد گواهی.

## جابه‌جایی میزبان

۱. از PostgreSQL و Storage فعلی پشتیبان بگیرید؛ مقصد را بدون حذف مبدا ایجاد کنید.
۲. دیتابیس/فایل‌ها را به مقصد منتقل و schema_migrations را حفظ کنید؛ دستور reset یا seed دستی روی دادهٔ واقعی اجرا نشود.
۳. API را با connection/storage جدید و originهای staging اجرا کنید؛ /health/live و /health/ready و آپلود/دانلود واقعی را بررسی کنید.
۴. فروشگاه و پنل را با آدرس API مقصد دوباره build کنید؛ آدرس API در مرورگر داخل artifact است و فقط تغییر env زمان اجرا کافی نیست.
۵. بعد از آزمون سفارش/انبار/قیمت/دسترسی، DNS را تغییر دهید و نسخهٔ قبلی را برای rollback حفظ کنید.

آزمون عملی مهاجرت، backup/restore، DNS و پرداخت واقعی هنوز انجام نشده و #100/#76 باز می‌مانند. اولین شروع روی دیتابیس خالی در کد فعلی seed دمو دارد؛ جداسازی seed از production همچنان #76 است. Sandbox پرداخت برای production فعال نشود. Docker محلی موجود نیست؛ CI entry point وب را build می‌کند، اما ادعای build یا انتشار Docker image واقعی نداریم.

Skills: deployments-cicd، lifecycle-architecture-review، Supabase guidance. Graphify version/query/update در executor موجود نیست و fallback ثبت شد. هیچ حساب، سرویس پولی، DNS یا secret تغییر نکرد.
