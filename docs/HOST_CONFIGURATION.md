# اتصال مستقل از میزبان

خرید لیارا پیش‌نیاز اجرای پروژه نیست. هر میزبان دارای Docker برای API دات‌نت، خروجی Next.js و خروجی Flutter Web، همراه با PostgreSQL و Storage سازگار با S3 قابل استفاده است. دامنه‌ها، host و کلیدهای سرویس در تنظیمات محیط وارد می‌شوند؛ منطق فروشگاه به نام سرویس‌دهنده وابسته نیست. فایل‌های liara.json صرفاً نمونهٔ پیکربندی آن سرویس‌اند.

## قرارداد اتصال واقعی

| بخش | تنظیمات موجود پروژه | زمان تنظیم |
|---|---|---|
| API → PostgreSQL | ConnectionStrings__Catalog شامل Host/Port/Database/Username/Password و SSL Mode | زمان اجرای API؛ فقط سرور |
| API → S3 | Media__Provider=S3 و Media__S3__Endpoint/Bucket/Region/AccessKey/SecretKey/ForcePathStyle | زمان اجرای API؛ فقط سرور |
| آدرس عمومی تصاویر API | Media__PublicBaseUrl | زمان اجرای API |
| ورود مدیر | Admin__Email/PasswordHash/TokenSigningKey | زمان اجرای API؛ secret manager |
| MFA مدیر اصلی (اختیاری) | Admin__Mfa__Required و Admin__Mfa__TotpSecret | secret manager؛ TOTP شش‌رقمی |
| مبداهای مجاز مرورگر | Cors__AllowedOrigins__0 و __1 | آدرس دقیق HTTPS فروشگاه و پنل |
| فروشگاه → API | NEXT_PUBLIC_MAZEDUNEH_API_URL | هنگام build فروشگاه؛ عمومی |
| پنل → API | MAZEDUNEH_API_BASE_URL | هنگام build پنل با dart-define؛ عمومی |
| پنل → زمینهٔ فروشگاه | MAZEDUNEH_ADMIN_STORE_ID | هنگام build پنل؛ عمومی و با مقدار پیش‌فرض `default` |
| آدرس‌های برند/پنل | NEXT_PUBLIC_SITE_URL و NEXT_PUBLIC_MAZEDUNEH_ADMIN_URL | هنگام build فروشگاه؛ عمومی |

نمونهٔ بدون اطلاعات واقعی در services/api/.env.example و apps/storefront/.env.example است. API دات‌نت فایل .env را خودکار نمی‌خواند؛ مقادیر باید در Environment یا secret manager میزبان تنظیم شوند. Dockerfile هر سرویس از پوشهٔ خود ساخته می‌شود. پنل اکنون lib/secure_main.dart را می‌سازد؛ همان entry point امن فعال و تست‌شده در CI.

`MAZEDUNEH_ADMIN_STORE_ID` فقط مشخص می‌کند پنل هنگام ورود کدام عضویت فروشگاه را درخواست کند؛ مجوز دسترسی محسوب نمی‌شود. API عضویت فعالِ همان ایمیل/رمز را در همان فروشگاه بررسی می‌کند و شناسهٔ فروشگاه نشست را از توکن امضاشده می‌خواند. کلاینت پس از ورود نمی‌تواند زمینهٔ نشست را با query string عوض کند.

برای فعال‌کردن MFA مدیر اصلی، یک seed تصادفی Base32 با دست‌کم ۱۶ بایت دادهٔ رمزگشایی‌شده در `Admin__Mfa__TotpSecret` نگه دارید و `Admin__Mfa__Required=true` را تنظیم کنید. برنامهٔ احراز هویت باید TOTP با SHA-1، کد ۶ رقمی و بازهٔ ۳۰ ثانیه‌ای داشته باشد. seed را در Git یا متغیر عمومی پنل قرار ندهید. ورود و تأیید عملیات حساس فقط پس از درخواست سرور کد را نمایش می‌دهند؛ seed و اتصال برنامهٔ احراز هویت باید پیش از فعال‌سازی امن به مدیر تحویل شوند. برای جلوگیری از پذیرش دوبارهٔ یک کد، اتصال دیتابیس مدیران لازم است و هر کد فقط یک بار در تمام نمونه‌های API پذیرفته می‌شود. تغییر Required/seed نشست‌های قبلی را تا زمان انقضا معتبر نگه می‌دارد؛ ورود تازه با MFA اجباری است.

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

آزمون واقعی migration و backup/restore روی سرویس staging، DNS و پرداخت واقعی باید پیش از لانچ انجام شوند (#76/#100). migration دیگر در startup عادی API اجرا نمی‌شود؛ آن را با job کنترل‌شدهٔ `--migrate` پیش از ارتقا اجرا کنید. `--seed-demo` فقط برای local/demo است و CI جلوی اجرای ضمنی آن را می‌گیرد. Sandbox پرداخت برای production فعال نشود.

Skills: deployments-cicd، lifecycle-architecture-review، Supabase guidance. Graphify version/query/update در executor موجود نیست و fallback ثبت شد. هیچ حساب، سرویس پولی، DNS یا secret تغییر نکرد.
