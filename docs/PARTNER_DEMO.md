# دموی حرفه‌ای شریک تجاری مزه‌دونه

این دمو برای نمایش تجربه کامل و قابل ارائه فروشگاه و پنل مدیریت، بدون وابستگی به API عمومی، دیتابیس، درگاه یا داده واقعی ساخته شده است.

## نسخه دوم چه چیزی را اصلاح می‌کند؟

- فروشگاه از حالت صفحه نمایشی و تصویرهای ایموجی خارج شده و زبان بصری اختصاصی، تصویرسازی SVG محصول، جست‌وجو، فیلتر، سبد، تسویه و رسید آزمایشی دارد.
- پنل مدیریت با صفحه ورود قابل استفاده شروع می‌شود و روی موبایل، تبلت و دسکتاپ مسیرهای کامل داشبورد، سفارش، محصول، انبار و گزارش را نمایش می‌دهد.
- تمام عملیات تعاملی‌اند اما فقط در حافظه همان نشست اجرا می‌شوند.
- مرز دمو و Production در تمام صفحات واضح باقی می‌ماند.

## اطلاعات ورود پنل دمو

```text
Email: admin@mazeduneh.ir
Password: Mazeduneh1405
```

این اطلاعات فقط برای Build نمایشی هستند. ورود Production همچنان از `secure_main.dart` و API احراز هویت استفاده می‌کند.

## خروجی‌های دمو

### فروشگاه حرفه‌ای

- هدر و ناوبری Responsive
- جست‌وجوی محصول و فیلتر دسته‌بندی
- تصویرسازی اختصاصی محصول بدون وابستگی به عکس خارجی
- نمایش منشأ، بسته فروش، ویژگی، قیمت و موجودی
- سبد خرید، تغییر تعداد و محاسبه ارسال
- فرم تحویل و شبیه‌سازی ثبت سفارش و پرداخت موفق
- بخش فرایند کیفیت، هدیه سازمانی و داستان برند
- برچسب دائمی دمو و هشدار عدم انجام تراکنش واقعی

Build:

```bash
cd apps/storefront
NEXT_PUBLIC_MAZEDUNEH_DEMO_MODE=true MAZEDUNEH_STATIC_EXPORT=true npm run build
```

خروجی در `apps/storefront/out` ساخته می‌شود.

### پنل مدیریت حرفه‌ای

- ورود مدیر با Validation، نمایش/مخفی‌سازی رمز و پرکردن خودکار اطلاعات دمو
- داشبورد فروش، سود، سفارش فعال و هشدار موجودی
- سفارش‌ها و تغییر مرحله از پرداخت تا تحویل
- محصولات، انتشار/پیش‌نویس، موجودی و افزودن محصول محلی
- بچ‌های انبار، تأمین‌کننده، قیمت خرید، مانده و تاریخ مصرف
- اعلان‌های عملیاتی
- گزارش فروش، بهای تقریبی، سود ناخالص، AOV و نمودار هفتگی
- Sidebar دسکتاپ و Bottom Navigation موبایل

Build:

```bash
cd apps/admin
flutter build web --release --target lib/professional_demo_main.dart
```

خروجی در `apps/admin/build/web` ساخته می‌شود.

## خصوصیات داده دمو

- داده‌ها داخل Build قرار دارند و Secret واقعی ندارند.
- ورود و تغییرات فقط در حافظه همان نشست هستند.
- Refresh صفحه داده‌ها را به Seed اولیه برمی‌گرداند.
- هیچ پرداخت، پیامک، ایمیل یا تغییر دیتابیس واقعی انجام نمی‌شود.

## سوئیچ فروشگاه به Production

در محیط Production این متغیرها تنظیم می‌شوند:

```text
NEXT_PUBLIC_MAZEDUNEH_DEMO_MODE=false
NEXT_PUBLIC_MAZEDUNEH_API_BASE_URL=https://api.example.com
NEXT_PUBLIC_MAZEDUNEH_ADMIN_URL=https://admin.example.com
```

وقتی Demo Mode برابر `false` باشد، صفحه اصلی به `StorefrontApp` متصل به API سوئیچ می‌کند.

## سوئیچ پنل به Production

پنل واقعی از Entry Point زیر ساخته می‌شود:

```bash
flutter build web --release \
  --target lib/secure_main.dart \
  --dart-define=MAZEDUNEH_API_BASE_URL=https://api.example.com
```

نسخه Android نیز از همین Entry Point ساخته می‌شود:

```bash
flutter build apk --release \
  --target lib/secure_main.dart \
  --dart-define=MAZEDUNEH_API_BASE_URL=https://api.example.com
```

ورود مدیر، محصولات، سفارش‌ها و گزارش‌های واقعی در این حالت از API دریافت می‌شوند.

## مرزهای Production

دموی حرفه‌ای جایگزین این موارد نیست:

- PostgreSQL و API عمومی پایدار
- Merchant واقعی و Callback درگاه
- بازپرداخت و تطبیق مالی
- ذخیره‌سازی تصاویر واقعی محصول
- شرکت حمل و کد رهگیری
- Backup، Monitoring و Alerting
- نقش‌ها، MFA و Audit Log کامل
- اطلاعات واقعی محصول، قیمت، موجودی، قوانین و محتوای حقوقی
