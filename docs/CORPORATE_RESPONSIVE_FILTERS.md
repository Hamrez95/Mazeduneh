# فیلترهای فروش سازمانی در موبایل

Issue #97. مسیر: منوی فروش سازمانی ← جست‌وجو/شهر/وضعیت یا «پیگیری‌های عقب‌افتاده» ← انتخاب درخواست ← مسئول/تاریخ پیگیری و Timeline موجود.

عنوان، شمارنده و کنترل‌های صفحه قبلاً در یک Row ثابت و inputها در Row دیگری قرار داشتند؛ در عرض ۳۶۰px فضای کافی برای شهر و وضعیت باقی نمی‌ماند. چیدمان جدید:

- موبایل: عنوان جدا، actionها با Wrap و سه فیلد زیر هم.
- تبلت/پنل باریک: جست‌وجوی کامل و شهر/وضعیت در ردیف دوم.
- نمایشگر عریض: inputها در یک ردیف با فضای قابل پیش‌بینی.

رنگ‌ها و typography موجود حفظ شده‌اند. فیلدها label قابل‌دیدن دارند؛ refresh tooltip دارد و همهٔ کنترل‌ها از widget استاندارد Flutter برای keyboard/focus استفاده می‌کنند. وضعیت انتخاب‌شده و query API همان قرارداد قبلی است. هیچ فیلتر، status یا دادهٔ جدید در سرور تعریف نشده و هیچ تغییر مالی/انبار/Order در این Slice انجام نمی‌شود.

| بررسی accessibility | اصلاح |
| --- | --- |
| Reflow در ۳۶۰px (WCAG 1.4.10) | ستون‌های موبایل و کنترل‌های قابل Wrap |
| Label فیلدها (3.3.2) | جست‌وجو، شهر و وضعیت درخواست به‌صورت label دائمی |
| Keyboard (2.1.1) | input/dropdown/button استاندارد؛ submit جست‌وجو با keyboard در تست |

بعد از جست‌وجو، API لیست واقعی همان فیلترها را می‌دهد. صف خالی توضیح موجود دربارهٔ نبود درخواست یا نبود پیگیری عقب‌افتاده را نگه می‌دارد. loading، error، forbidden و مسیر جزئیات/ذخیره همان رفتار قبلی هستند؛ هر اصلاح نتیجه از صفحهٔ موجود انجام می‌شود و سپس کاربر به فهرست برمی‌گردد.

Widget test در عرض‌های ۳۶۰/۷۶۸/۱۲۸۰ (۳۶۰ با متن ۲۰۰٪) شمارندهٔ فارسی، نبود overflow، keyboard search، query واقعی overdue و empty-state را بررسی می‌کند. تست‌های قبلی API و تمام CIهای Storefront/API/Admin هم لازم‌اند. بررسی با screen reader واقعی همچنان بخشی از QA دستگاه است و توسط widget test کامل نمی‌شود.

Skills: frontend-design، uiuxdesigner:accessibility-audit، lifecycle-architecture-review. Graphify version/query/update در executor موجود نبود و targeted search جایگزین شد. Flutter محلی موجود نیست؛ CI مرجع runtime است.

باقی‌ماندهٔ #97: package catalog، reminder automation، conversion analytics/order link و صف درخواست‌های فاقد مسئول/تاریخ پیگیری. این Slice اصلاح responsive قابلیت موجود است.
