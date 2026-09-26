# لاگ تصمیم — Adapter پرداخت Sandbox

## مسئله

چرخه سفارش تا حالت `AwaitingPayment` کامل بود، اما بدون درگاه نمی‌شد تطبیق مبلغ، Callback تکراری، ثبت مرجع پرداخت و ماندگاری وضعیت `Paid` را آزمایش کرد. قراردادن کلید یا شبیه‌سازی غیرشفاف داخل Client نیز ناامن و گمراه‌کننده بود.

## گزینه‌ها

1. صبر تا دریافت درگاه واقعی — رد شد؛ بخش بزرگی از ریسک فنی بدون دلیل عقب می‌افتاد.
2. تغییر دستی وضعیت سفارش توسط مدیر — رد شد؛ رفتار واقعی Provider و Callback را آزمایش نمی‌کرد.
3. Adapter پرداخت Sandbox با همان مرزهای Initiate/Verify — انتخاب شد.

## نظر میزگرد

- **Backend/Technical:** Payment باید رکورد مستقل، Authority یکتا، مبلغ Snapshot و Callback idempotent داشته باشد.
- **Security:** Sandbox پیش‌فرض خاموش است و فقط با Environment فعال می‌شود؛ Receipt Token برای Initiate و Complete لازم است.
- **Accounting:** مبلغ و Currency پرداخت باید دقیقاً با سفارش تطبیق داده شود.
- **Sales/Product:** سفارش پرداخت‌شده باید بعد از Restart همچنان Paid باشد و مرجع پرداخت داشته باشد.
- **QA:** Complete تکراری نباید Transition یا پرداخت دوم بسازد.
- **Operations:** درگاه واقعی بعداً با حفظ Interface و قرارداد جایگزین Sandbox می‌شود.

## تصمیم و پیاده‌سازی

- جدول `payments` با Order یکتا، Authority یکتا، مبلغ، وضعیت و مرجع ایجاد شد.
- Intent فقط برای سفارش AwaitingPayment و رزرو منقضی‌نشده ساخته می‌شود.
- Intent تکراری همان Payment را برمی‌گرداند.
- Complete در یک تراکنش، Payment را Succeeded، سفارش را Paid و Transition را ثبت می‌کند.
- Callback تکراری همان نتیجه را برمی‌گرداند و اثر جانبی جدید ندارد.
- اختلاف مبلغ یا Currency باعث توقف تراکنش و ثبت خطای فنی می‌شود.
- JSON Enumها در کل API به نام پایدار تبدیل شدند تا Client به عدد داخلی وابسته نباشد.

## گیت تست

CI باید با PostgreSQL واقعی:

1. سفارش بسازد و پس از Restart بازیابی کند.
2. Payment Intent بسازد.
3. Complete را دو بار ارسال و یکسان‌بودن Payment را اثبات کند.
4. API را Restart و Paid بودن سفارش و تاریخچه را بررسی کند.
5. سایت و Flutter را بدون Regression بسازد.

## مرز صادقانه

Sandbox هیچ تراکنش مالی انجام نمی‌دهد و در Production پیش‌فرض خاموش است. برای Go-Live باید Provider واقعی، Merchant ID، Callback عمومی، Verification رسمی و Reconciliation اضافه شوند.
