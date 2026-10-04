# نقشهٔ محصول پنل مدیریت مزه‌دونه

> وضعیت این سند: Audit زندهٔ Repository در ۳۰ سپتامبر ۲۰۲۶  
> منبع حقیقت: کد و migrationهای branch اصلی main، CI و Issue/PRهای واقعی GitHub.  
> این سند برنامه‌ریزی است؛ در این Slice هیچ کد محصولی تغییر داده نشده است.

## ۱. چشم‌انداز

مزه‌دونه باید از یک فروشگاه و پنل اولیه به یک Commerce OS کوچک، قابل اتکا و قابل Clone تبدیل شود. صاحب فروشگاه و کارکنان باید بتوانند محصول، تصویر، قیمت، موجودی، بچ، سفارش، مشتری، فروش سازمانی، محتوا و گزارش سود را بدون ورود به کد مدیریت کنند.

اصل معماری:

- PostgreSQL و API منبع حقیقت پول، موجودی، سفارش، پرداخت و وضعیت هستند.
- Storefront، Admin و API باید قراردادهای روشن و قابل تست داشته باشند.
- هر فروشگاه در آینده برند، دامنه، محصول، قیمت، مالیات، ارسال، کاربر، نقش و feature flag مستقل خواهد داشت.
- هیچ قابلیت Admin نباید فقط با hard-code در یک صفحه قابل کنترل باشد.
- همهٔ UIهای جدید و اصلاحی با @frontend-design طراحی می‌شوند: ساده، متمایز، فارسی/RTL، انگلیسی/LTR، responsive و قابل دسترس.

## ۲. نتیجهٔ Audit زنده

### Repository و شاخه‌ها

| مورد | وضعیت واقعی |
|---|---|
| Repository | Hamrez95/Mazeduneh |
| branch پیش‌فرض GitHub | dev؛ این با سیاست release که main را release-ready می‌داند هم‌راستا نیست |
| main فعلی | bdd386da16afab5c52bed7f7a62b02d809fe2f94 |
| dev فعلی | 96d16a3e5ed86526e7d15b499ec59b7460339be5 |
| main | شامل ۱۹۴ path و مجموعهٔ کامل‌تر Storefront/Admin/API است |
| dev | عقب‌تر و دارای شاخه‌های feature قدیمی؛ مبنای این Roadmap نیست |
| PRهای اخیر | PRهای #80 تا #90 برای migration، مشتری، مالیات، batch/FEFO، corporate و shipping merge شده‌اند |
| CI آخر گزارش‌شده روی main | موفق؛ Storefront، API، Flutter/Admin و artifactهای مرتبط در workflow |
| CI آخر گزارش‌شده روی dev | یک run اخیر failure داشته است؛ نباید معیار release باشد |

### سطوح محصول

- Storefront: Next.js App Router در apps/storefront با مسیرهای home، shop، product، cart، checkout، profile، info و corporate-sales.
- Admin: Flutter web/PWA و Android در apps/admin؛ entrypoint رسمی lib/main.dart است.
- API: ASP.NET Core modular monolith در services/api.
- Data: PostgreSQL/Npgsql با schema_migrations، stock ledger و bootstrapهای ماژولار.
- Media: Local برای توسعه و S3-compatible abstraction برای production.
- Deployment: فایل‌های Docker/Liara در repo وجود دارند. تیم متصل Vercel در Audit هیچ Project فعالی برنگرداند؛ بنابراین URL یا deployment Vercel نباید بدون evidence به‌عنوان production فرض شود.
- Supabase: پروژه‌ای با نام Mazeduneh در اتصال Supabase پیدا نشد؛ API فعلی از Npgsql/PostgreSQL استفاده می‌کند. Supabase در این پروژه منبع حقیقت عملیاتی محسوب نمی‌شود.

### قابلیت‌های موجود

| حوزه | آنچه در main واقعاً وجود دارد | وضعیت |
|---|---|---|
| Catalog | محصول، category، variant وزنی/عددی، SKU، قیمت، cost، publish، SEO و food metadata | پایهٔ عملیاتی؛ ناقص در bulk/media library/relations |
| Media | upload/download/metadata/delete و provider Local/S3 | قرارداد موجود؛ credential/runtime واقعی نیازمند Launch gate |
| Storefront | routeهای چندصفحه‌ای، catalog live، gallery، cart و checkout مهمان | عملیاتی پایه؛ جست‌وجو/فیلتر/اعتماد/SEO پیشرفته ناقص |
| Checkout | reservation، persistence، idempotency، tax/shipping/cost snapshot، receipt token | عملیاتی پایه؛ payment واقعی/reconciliation/refund ناقص |
| Orders | لیست Admin، dashboard، analytics، notification پایه، تغییر state و عملیات گروهی تا ۵۰ سفارش | ناقص در stateهای کامل، timeline، Kanban، print، refund و tracking |
| Inventory | stock_movements، adjustment، batches، expiry و FEFO پایه | ناقص در receiving/supplier/fulfillment/return/waste/reorder |
| Customer | customer پایدار، mobile normalization، address و لیست/پروفایل Admin | ناقص در OTP، consent، segment و privacy workflow |
| Corporate | landing، upload logo، pipeline status، assignment، follow-up، notes، messages و proforma | پایهٔ عملیاتی؛ package/analytics/conversion/reminder تکمیلی لازم |
| Finance | tax، shipping، purchase/packaging/additional cost، invoice و margin پایه | ناقص در accounting رسمی، reconciliation، refund و net profit کامل |
| Admin UX | palette، Vazirmatn، Persian formatter، shared request error states و PWA manifest | نیازمند modular architecture، RBAC و QA کامل |
| Security | bearer امن، rate-limit ورود، logout قابل revoke، Audit Log قابل مشاهده و ماتریس permission برای نقش‌های عملیاتی | ناقص در user management، MFA و step-up approval |
| CI | workflow برای Storefront، API/PostgreSQL، Flutter analyze/test/build و artifact | سبز روی main؛ release/deploy evidence ناقص |

### پیگیری اعلان‌ها — چرخهٔ ۴ اکتبر ۲۰۲۶ (#96)

Component مشترک Dashboard/Notification Center، دکمهٔ مسیر ماژول مجاز، اعداد فارسی و حفظ دادهٔ قبلی در refresh ناموفق اضافه شد. پاسخ ۴۰۱/۴۰۳ دادهٔ قبلی را پنهان می‌کند. قرارداد فعلی اعلان، صف تجمیعی است؛ provider، unread/read، template، role/store filtering سرور و لینک دقیق رکورد همچنان در #96 باز هستند. راهنما: `docs/NOTIFICATION_CENTER.md`.

### Responsive فروش سازمانی — چرخهٔ ۴ اکتبر ۲۰۲۶ (#97)

عنوان و actionها از ردیف ثابت به چیدمان انعطاف‌پذیر تبدیل شدند؛ جست‌وجو/شهر/وضعیت در موبایل زیر هم و در تبلت در دو ردیف قرار می‌گیرند. label و tooltip دائمی اضافه شد. تست ۳۶۰/۷۶۸/۱۲۸۰، متن ۲۰۰٪، keyboard search و overdue query دارد. راهنما: `docs/CORPORATE_RESPONSIVE_FILTERS.md`.

### اصلاح موجودی اولیهٔ صفر — چرخهٔ ۴ اکتبر ۲۰۲۶ (#2)

ساخت محصول یا افزودن Variant با موجودی صفر قبلاً به constraint حرکت انبار برخورد می‌کرد. helper مشترک اکنون برای صفر حرکت جعلی ثبت نمی‌کند و برای مقدار مثبت همان ledger اتمیک را حفظ می‌کند. تست CI شامل ایجاد، افزودن Variant، دریافت بعدی، validation منفی و restart است. راهنما: `docs/ZERO_INITIAL_STOCK.md`.

## ۳. چه چیزهایی دوباره ساخته نمی‌شوند؟

- #61 چرخهٔ category را تکمیل کرده است؛ Issue جدید category ایجاد نمی‌شود.
- #70 قرارداد provider رسانه را تکمیل کرده است؛ کار بعدی credential و runtime verification است.
- #71 فارسی‌سازی اعداد را پایه‌گذاری کرده است؛ ادامه فقط audit و حذف موارد باقی‌مانده است.
- #72 media/catalog را data-driven کرده است؛ کار بعدی حذف fallbackهای ناموجه و تکمیل data contract است.
- #73 stateهای loading/error/forbidden را shared کرده است؛ کار بعدی پوشش همهٔ صفحات و stale/offline است.
- #83 تا #88 بخش‌های food/cost/tax/shipping/invoice/batch/FEFO را merge کرده‌اند؛ #82 تکمیل همین مسیر است، نه قابلیت جدید.
- #89 و #90 core فروش سازمانی را merge کرده‌اند؛ #97 فقط gapهای pipeline، package، reminder و analytics را پوشش می‌دهد.
- #79 و #81 customer operations/address را merge کرده‌اند؛ #75 و #94 هویت پایدار و رشد CRM را جدا می‌کنند.

## ۴. اولویت نهایی

### P0 — برای Launch و جلوگیری از خطای مالی/عملیاتی

#2 Catalog و publish-safe product، #3 Checkout/order/payment lifecycle، #4 Admin operations، #5 inventory/FEFO/fulfillment، #75 customer identity، #76 migrations/environments، #77 Admin architecture، #91 RBAC/audit/session، #92 operations dashboard، #100 release readiness.

### P1 — بهره‌وری و رشد بعد از تثبیت هسته

#6 reports، #7 brand/content، #28 storefront discovery، #30 CMS/settings/reviews، #29 checkout UX، #82 tax/cost/invoice completion، #93 shipping operations، #94 CRM، #95 promotions، #96 notifications/automation، #97 corporate completion، #98 store settings، #101 in-panel help.

### P2 — معماری قابل Clone

#99 multi-store/white-label/isolation.

### P3 — بعد از Launch و پس از تصمیم محصولی

وفاداری و referral، review پیشرفته، abandoned cart با consent، loyalty points، اتصال کامل SMS/Email، چند انبار واقعی و integration با حسابداری بیرونی؛ این موارد در scope رشد هستند و نباید پیش‌نیاز Launch شوند.

## ۵. فازهای اجرا

### M0 — Trust و Release Gate

Issueها: #76، #91، #100، بخش release از #8.

خروجی: migration قابل تکرار، staging جدا، permission/audit، secret hygiene، backup/restore، observability و synthetic order.

### M1 — Sellable Catalog

Issueها: #2، #28.

خروجی: محصول کامل، variant/SKU، تصویر و SEO، preview/publish، storefront published-only، search/filter و trust facts.

### M2 — Order و Customer Core

Issueها: #3، #29، #75.

خروجی: guest checkout بدون از دست دادن customer، totals server-owned، order state، payment sandbox/adapter، reservation و receipt.

### M3 — Admin Operations

Issueها: #4، #5، #77، #92، #101.

خروجی: پنل ماژولار و role-aware، dashboard عملیاتی، سفارش، انبار، batch/FEFO، مسیرهای آموزشی و mobile/PWA قابل استفاده.

### M4 — Commercial Growth

Issueها: #6، #7، #30، #82، #93، #94، #95، #96، #97.

خروجی: گزارش سود، هزینهٔ واقعی ارسال، CMS، کمپین، CRM، اعلان، corporate pipeline و automation پایه.

### M5 — Store Configuration

Issue: #98.

خروجی: profile/brand/theme/locale/tax/shipping/SEO/feature flags/onboarding از پنل و بدون deploy.

### M6 — Cloneable Commerce Core

Issue: #99.

خروجی: Store/Tenant context، isolation، template seed، white-label، domain mapping و clone امن.

## ۶. نقشهٔ وابستگی

~~~mermaid
flowchart TD
  A["M0: Migration + Security + Release"] --> B["M1: Catalog + Publish"]
  B --> C["M2: Checkout + Customer + Orders"]
  C --> D["M3: Admin Operations + Inventory"]
  D --> E["M4: Reports + Growth + Corporate"]
  E --> F["M5: Store Settings + Onboarding"]
  F --> G["M6: Multi-store + White-label"]
~~~

## ۷. اصول تجربهٔ Admin

هر Task مربوط به Admin باید این سؤال‌ها را جواب دهد:

1. کاربر از کدام منو وارد می‌شود؟
2. هدف این صفحه با یک جمله چیست؟
3. چه اطلاعاتی برای تصمیم‌گیری لازم است؟
4. عملیات در چند گام انجام می‌شود؟
5. موفقیت با چه پیام و لینک بعدی نمایش داده می‌شود؟
6. خطا دقیقاً چه چیزی را توضیح می‌دهد و چگونه اصلاح می‌شود؟
7. کاربر بعد از Save یا Cancel کجا برمی‌گردد؟
8. آیا breadcrumb، tooltip یا empty state آموزشی لازم است؟
9. چگونه از محصول به سفارش، از سفارش به مشتری/انبار و از آن‌ها به سود می‌رسیم؟

قانون copy: کاربر «اعلان‌ها» را مدیریت می‌کند، نه «webhook config»؛ دکمهٔ «ذخیره تغییرات» باید واقعاً Save کند؛ status خام API نباید بدون label فارسی به کاربر نمایش داده شود.

## ۸. معماری هدف Multi-store

- Store و User جدا هستند؛ User با membership به Store وصل می‌شود.
- همهٔ داده‌های کسب‌وکار store_id اجباری دارند.
- Store context از hostname/session/token سرور resolve می‌شود و از body قابل جعل نیست.
- catalog، price، tax، shipping، content، media، feature flags و roles store-scoped هستند.
- clone فقط template، theme، settings و دادهٔ seed مجاز را منتقل می‌کند؛ customer، order، payment و secret هرگز clone نمی‌شوند.
- cache key، media key، audit و export هم store-scoped هستند.
- cross-store isolation با integration/security test اجباری است.
- migrationها باید backfill امن و قابل ارتقا داشته باشند.

## وضعیت Slice مدیریت کاربران

Migration افزایشی `admin-users/001-memberships` جدول عضویت‌های store-scoped را می‌سازد، Owner فعلی را بدون ذخیرهٔ رمز یا token seed می‌کند و API فهرست، نقش‌ها، ساخت و فعال/غیرفعال‌سازی کاربر را فراهم می‌کند. UI پنل Owner-only «امنیت ← کاربران» با فرم کوتاه و حالت‌های آموزشی اضافه شده است؛ اتصال واقعی هر membership به احراز هویت، MFA و step-up approval در Sliceهای بعدی انجام می‌شود.

## ۹. جدول Issueها

| Issue | حوزه | Priority | نوع | Effort | وضعیت فعلی |
|---|---|---:|---|---:|---|
| #2 | Catalog/product/media/publish | P0/P1 | Full-stack | L | ناقص، پایه موجود |
| #3 | Checkout/order/payment | P0 | Full-stack | XL | ناقص، پایه موجود |
| #4 | Admin operations/PWA | P0 | Admin | XL | ناقص |
| #5 | Inventory/FEFO/fulfillment | P0/P1 | Full-stack | XL | ناقص، ledger/batch موجود |
| #6 | Reports/analytics | P1 | Analytics | L | revenue/cost/margin پایه، هزینه واقعی ارسال و سود تفکیکی محصول/Variant تکمیل؛ reconciliation/refund/cohort/export پیشرفته باقی |
| #7 | Brand/content foundation | P1 | UX/Storefront | M | ناقص |
| #8 | Production readiness | P0 | Infra/QA | L | باز، CI موجود |
| #28 | Storefront discovery/product UX | P1 | Storefront | L | ناقص |
| #29 | Cart/checkout UX | P0 | Storefront/API | L | ناقص |
| #30 | CMS/reviews/commerce settings | P1 | Full-stack | XL | ناقص |
| #74 | Commerce OS epic | P0→P2 | Product/Architecture | XL | epic باز |
| #75 | Customer identity/guest checkout | P0 | Full-stack | L | پایه موجود |
| #76 | Versioned migrations/environments | P0 | Backend/Infra | L | ناقص |
| #77 | Admin architecture/design system | P0 | Admin/UX | XL | ناقص |
| #82 | Finance/batch/invoice completion | P0/P1 | Full-stack | L | بخش عمده موجود |
| #91 | RBAC/audit/session | P0 | Security | L | ماتریس نقش/permission، Audit UI و UI/API مدیریت عضویت تکمیل؛ اتصال عضویت به ورود، MFA و step-up approval باقی است |
| #92 | Operations dashboard/guided work | P0 | Full-stack/Admin | L | KPI بازه‌ای، سفارش مشکل‌دار، مشتری/درخواست جدید، موجودی کم و نزدیک انقضا با مسیرهای سریع تکمیل؛ سود و drill-downهای پیشرفته باقی است |
| #93 | Shipping/delivery operations | P1 | Full-stack | L | tracking و هزینهٔ واقعی موجود؛ فیلتر سفارش‌های تأخیردار تکمیل؛ مناطق، چندآدرسی و split shipment باقی |
| #94 | CRM/segmentation/attribution | P1 | Full-stack | M | جدید |
| #95 | Promotions/campaign engine | P1 | Full-stack | L | جدید |
| #96 | Notifications/automation | P1 | Full-stack/Infra | L | جدید |
| #97 | Corporate pipeline/packages | P1 | Full-stack | M | pipeline، assignment، follow-up و فیلتر پیگیری عقب‌افتاده تکمیل؛ Package catalog، reminder automation و conversion analytics باقی |
| #98 | Store settings/theme/onboarding | P1 | Full-stack | L | جدید |
| #99 | Multi-store/white-label | P2 | Architecture | XL | جدید |
| #100 | Launch gate/observability | P0 | Infra/QA | L | جدید |
| #101 | In-panel help/next action | P1 | Admin UX | M | جدید |

## ۱۰. Definition of Done مشترک

- User Story، Business Goal و مثال واقعی نوشته شده است.
- مسیر ورود از پنل و next action مشخص است.
- UI با @frontend-design و design system مشترک انجام شده است.
- RTL/LTR، Persian numerals، responsive و accessibility بررسی شده است.
- loading/empty/error/forbidden/success/stale وجود دارد.
- API contract، validation، authorization و error contract مشخص است.
- migration و مدل داده با rollback/recovery plan ثبت شده است.
- backend، frontend، integration و E2E تست شده‌اند.
- audit و observability برای عملیات مهم وجود دارد.
- docs و User Guide به‌روزرسانی شده‌اند.
- CI روی main سبز است و secret در هیچ artifactی وجود ندارد.

## ۱۱. تصمیم‌های باز محصولی

این موارد قبل از اجرای Issue مربوط باید تصمیم‌گیری و در ADR ثبت شوند:

- مقصد canonical deployment: Liara، Vercel یا ترکیب رسمی Storefront/API/Admin.
- provider واقعی payment و قرارداد reconciliation/refund.
- provider واقعی S3-compatible و bucket/domain production.
- واحد نمایش غالب: تومان یا ریال و سیاست تبدیل نمایشی.
- تعریف رسمی سود خالص و هزینه‌هایی که در Launch محاسبه می‌شوند.
- سیاست OTP، consent، retention و anonymization.
- آیا multi-store در همین repository می‌ماند یا به core package جدا منتقل می‌شود.
- نوع خروجی حسابداری: CSV/Excel یا integration با نرم‌افزار مشخص.
- آیا review و SMS/Email قبل از Launch لازم هستند یا بعد از آن.

## ۱۲. وضعیت Milestoneهای GitHub

Issueها با Epic/Milestone پیشنهادی در title/body ثبت شدند. اتصال واقعی به GitHub Milestone object در این اجرای connector در دسترس نبود: ابزار متصل create issue و update issue دارد اما endpoint ساخت Milestone ارائه نمی‌کند. بنابراین تا فعال شدن آن capability، جدول بالا و prefixهای M0 تا M6 منبع ترتیب اجرا هستند و هیچ Issueای به‌دروغ به Milestone غیرموجود نسبت داده نشده است.

## چرخهٔ ۴ اکتبر ۲۰۲۶ — Readiness API (#100)

- تفکیک `/health/live` از `/health/ready`؛ readiness با PostgreSQL یا تنظیمات هویت ناقص، ۵۰۳ می‌دهد.
- diagnostic قدیمی `/health` حفظ شده و قطع دیتابیس دیگر خواندن دوم migration و خطای ۵۰۰ ایجاد نمی‌کند.
- تست CI برای نبود تنظیمات، قطع و بازیابی PostgreSQL بدون restart API اضافه شده است.
- قرارداد و راهنمای عملیات: `docs/API_READINESS.md`.
- #100 تا تأیید staging، storage/payment، backup/restore و launch gate واقعی باز می‌ماند.


## چرخهٔ ۴ اکتبر ۲۰۲۶ — مسیرهای داشبورد متناسب با نقش (#92)

- Quick Actionها بر اساس permissionهای نشست فیلتر می‌شوند؛ برای نقش فقط‌خواندنی، برچسب مشاهده جایگزین پیشنهاد ثبت/اصلاح می‌شود.
- نام شخص hard-code از عنوان داشبورد حذف شد؛ empty state نقش بدون مسیر عملیاتی اضافه شد.
- focus، کنتراست متن کارت‌ها و ارتفاع منعطف KPI برای بزرگ‌نمایی متن بهبود یافت.
- تست نقش محدود، فعال‌سازی با keyboard، عرض‌های ۳۶۰/۷۶۸/۱۲۸۰ و بزرگ‌نمایی متن اضافه شد.
- #92 برای drill-down فیلترشده، سود خالص و پیکربندی داشبورد نقش‌ها همچنان باز است.

## چرخهٔ ۴ اکتبر ۲۰۲۶ — همبستگی درخواست و لاگ (#100)

- شناسهٔ سرور `X-Request-ID` در پاسخ و `requestId` در Problem Details، هماهنگ با Audit موجود.
- لاگ JSON تکمیل درخواست با route template، status و زمان؛ بدون path/query/body/token در event جدید.
- تست CI برای همبستگی Audit، خطای validation، CORS و عدم ثبت دادهٔ حساس درخواست.
- راهنمای عملیات: `docs/API_OBSERVABILITY.md`؛ alert، log sink/retention و تأیید deployment واقعی همچنان باز است.


## چرخهٔ ۴ اکتبر ۲۰۲۶ — فیلتر اعلان‌ها در سرور (#96/#91)

خروجی Notification API بر اساس permissionهای نشست به سفارش و انبار محدود می‌شود؛ title/SKU و count حوزهٔ نامجاز برنمی‌گردد و query آن اجرا نمی‌شود. قرارداد JSON و خروجی Owner حفظ شده است. تست integration با fixture واقعی و processهای دارای permission متفاوت در CI اضافه شد. جزئیات: `docs/NOTIFICATION_PERMISSIONS.md`. Store isolation و membership login همچنان در #91/#99 باز هستند.


## صف نیازمند برنامه‌ریزی فروش سازمانی

در منوی فروش سازمانی، فیلتر «نیازمند برنامه‌ریزی» درخواست‌های فعال بدون مسئول یا موعد پیگیری را نشان می‌دهد. پس از تعیین هر دو در جزئیات، فهرست را تازه کنید. این صف با عقب‌افتاده هم‌زمان فعال نمی‌شود. [قرارداد و مسیر کاربر](CORPORATE_PLANNING_QUEUE.md).
