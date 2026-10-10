# نمونهٔ انتشار روی لیارا

لیارا فقط یکی از مقصدهای ممکن است و خرید آن پیش‌نیاز توسعه نیست. قرارداد اصلی اتصال مستقل از میزبان در [HOST_CONFIGURATION.md](HOST_CONFIGURATION.md) است. ساخت سرویس‌های پولی و تنظیم DNS/انتشار واقعی هنوز انجام نشده‌اند.

## اجزای آماده‌شده

هر بخش یک Docker app مستقل دارد تا بتوان نسخه و متغیرهای محیطی‌اش را جداگانه مدیریت کرد:

- فروشگاه Next.js: `apps/storefront/Dockerfile`
- API دات‌نت: `services/api/Dockerfile`
- پنل Flutter Web: `apps/admin/Dockerfile`
- هر app فایل `liara.json` خودش را دارد و روی پورت `8080` گوش می‌دهد.

برای Next.js، خروجی standalone فقط هنگام ساخت Docker فعال می‌شود؛ توسعهٔ محلی و خروجی static فعلی رفتار جداگانه‌شان را حفظ می‌کنند. آدرس API برای فروشگاه و پنل هنگام build تنظیم می‌شود، چون داخل کد سمت مرورگر قرار می‌گیرد.

## سرویس‌های موردنیاز در زمان انتشار

1. سه Docker app برای فروشگاه، API و پنل.
2. یک PostgreSQL مدیریت‌شدهٔ لیارا برای داده‌های پایدار.
3. یک باکت Object Storage سازگار با S3 برای تصاویر و فایل‌ها.
4. دامنه‌های HTTPS برای فروشگاه، API و پنل؛ نام نهایی هرکدام هنگام خرید و تنظیم دامنه انتخاب می‌شود.

## متغیرهای حساس API

این مقادیر را فقط در Environment Variables پنل لیارا قرار می‌دهیم، نه در Git یا `liara.json`:

```text
ConnectionStrings__Catalog=<connection string دیتابیس لیارا>
Admin__Email=<ایمیل مدیر>
Admin__PasswordHash=<هش SHA-256 رمز مدیر به‌صورت hex>
Admin__TokenSigningKey=<کلید تصادفی حداقل ۳۲ بایتی>
Cors__AllowedOrigins__0=https://<دامنه فروشگاه>
Cors__AllowedOrigins__1=https://<دامنه پنل>
Media__Provider=S3
Media__S3__Endpoint=<endpoint باکت>
Media__S3__Bucket=<نام باکت>
Media__S3__Region=<region باکت>
Media__S3__AccessKey=<access key>
Media__S3__SecretKey=<secret key>
Media__S3__ForcePathStyle=true
Payments__SandboxEnabled=false
Payments__Zibal__Merchant=<merchant-code>
Payments__Zibal__CallbackUrl=https://<دامنه-api>/api/v1/payments/zibal/callback
Payments__Zibal__ReturnUrl=https://<دامنه-فروشگاه>/checkout
```

اطلاعات دقیق اتصال دیتابیس و Object Storage را از خود پنل لیارا می‌گیریم. ذخیره‌سازی `Local` برای فایل‌های آپلودی production مناسب نیست، چون دیسک کانتینر محل نگهداری پایدار فایل نیست.

## اتصال آدرس‌ها

- `NEXT_PUBLIC_MAZEDUNEH_API_URL`: آدرس HTTPS عمومی API.
- `NEXT_PUBLIC_MAZEDUNEH_DEMO_MODE=false`: فعال‌کردن فروشگاه متصل به API.
- `NEXT_PUBLIC_MAZEDUNEH_ADMIN_URL`: آدرس پنل.
- `NEXT_PUBLIC_SITE_URL`: آدرس canonical فروشگاه.
- `MAZEDUNEH_API_BASE_URL`: آدرس API که هنگام build پنل Flutter به آن داده می‌شود.

مقادیر `NEXT_PUBLIC_*` و `MAZEDUNEH_API_BASE_URL` secret نیستند، ولی باید قبل از build نهایی باشند تا کلاینت مرورگر نشانی درست را دریافت کند.

## فرمان‌های انتشار

بعد از ساخت appها در لیارا، ورود CLI و ثبت environmentها، از ریشهٔ مخزن هر app را جداگانه منتشر می‌کنیم. نام‌های داخل `<...>` را با نام واقعی appها و دامنه‌ها جایگزین می‌کنیم:

```powershell
$apiApp = 'نام-app-api'
$storefrontApp = 'نام-app-فروشگاه'
$adminApp = 'نام-app-پنل'
$apiUrl = 'https://api.example.ir'
$storefrontUrl = 'https://mazeduneh.ir'
$adminUrl = 'https://admin.mazeduneh.ir'

liara deploy --path services/api --app $apiApp --platform docker --port 8080
liara deploy --path apps/storefront --app $storefrontApp --platform docker --port 8080 --build-arg "NEXT_PUBLIC_MAZEDUNEH_API_URL=$apiUrl" --build-arg "NEXT_PUBLIC_MAZEDUNEH_DEMO_MODE=false" --build-arg "NEXT_PUBLIC_MAZEDUNEH_ADMIN_URL=$adminUrl" --build-arg "NEXT_PUBLIC_SITE_URL=$storefrontUrl"
liara deploy --path apps/admin --app $adminApp --platform docker --port 8080 --build-arg "MAZEDUNEH_API_BASE_URL=$apiUrl"
```

مستندات رسمی [Liara CLI](https://github.com/liara-cloud/cli) فرمان‌های `--path`، `--platform`، `--port` و `--build-arg` را پشتیبانی می‌کند. `platform: docker` در فایل‌های تنظیمات صریح است، چون هر app هم Dockerfile دارد و هم فایل‌هایی مثل `package.json` یا `.csproj` که تشخیص خودکار را مبهم می‌کنند.

## بررسی‌های لازم پیش از انتشار واقعی

- API هنگام شروع، migrationهای PostgreSQL را اجرا می‌کند؛ اجرای اول روی دیتابیس خالی چند محصول نمونه هم درج می‌کند. پیش از اتصال دیتابیس production، seed و migrationها باید بازبینی شوند.
- نام دامنه‌های نهایی را به CORS API اضافه می‌کنیم.
- رمز مدیر و `Admin__TokenSigningKey` مستقل و تصادفی تولید می‌شوند.
- اتصال API به دیتابیس و آپلود/دریافت فایل در Object Storage را روی محیط staging بررسی می‌کنیم.
- Merchant Code زیبال، Callback و Return URL را فقط در Environment API قرار می‌دهیم؛ Callback باید HTTPS عمومی باشد و دامنه و IP API در پنل زیبال ثبت شوند. راهنمای کامل در [ZIBAL_PAYMENT.md](ZIBAL_PAYMENT.md) است.
- Docker روی محیط توسعهٔ فعلی نصب نیست؛ بنابراین Dockerfileها در این سیستم image-build نشده‌اند. ساخت image و تطبیق نهایی CLI هنگام آماده‌شدن حساب لیارا انجام می‌شود.
