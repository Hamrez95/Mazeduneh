# جدول Traceability پنل مدیریت مزه‌دونه

> این جدول وضعیت را در برابر main فعلی نشان می‌دهد. «ناقص» یعنی بخشی از capability در کد واقعی وجود دارد اما مسیر کامل موردنیاز هنوز آماده نیست. «برنامه‌ریزی‌شده» یعنی owner و Issue دارد اما implementation کامل در main دیده نشده است.

| نیاز کسب‌وکار | ماژول Admin | API فعلی یا قرارداد هدف | جدول/مدل دیتابیس | Issue مالک | وضعیت |
|---|---|---|---|---|---|
| داشبورد فروش، سفارش، سود و هشدار | Dashboard | /api/v1/admin/orders/dashboard، /analytics و aggregateهای جدید | checkout_orders، checkout_order_lines، stock_movements، inventory_batches | #92، #6 | ناقص؛ پایه موجود |
| ثبت/ویرایش/انتشار محصول | Products | /api/v1/products، /admin، /{slug}، /{slug}/publication | products، product_variants، categories | #2 | ناقص؛ پایه موجود |
| Media Library، تصویر اصلی و alt | Products/Media | /api/v1/admin/media، metadata و delete | media reference در product؛ storage object | #2، #70 | ناقص؛ provider موجود |
| Catalog storefront و Product Detail | Storefront | /api/v1/products و published catalog | products، product_variants، categories | #2، #28 | ناقص؛ live مسیر موجود |
| Cart/Checkout و guest purchase | Checkout | /api/v1/checkout/orders | checkout_orders، checkout_order_lines، checkout_idempotency | #3، #29، #75 | ناقص؛ مسیر پایه موجود |
| Payment و reconciliation | Orders/Finance | /api/v1/payments و provider callback/verify هدف | payments، checkout_order_transitions | #3، #8، #100 | ناقص؛ sandbox موجود |
| وضعیت سفارش، timeline، note، cancel/refund | Orders | /api/v1/admin/orders، /orders/{id}/state و قرارداد note/refund | checkout_orders، checkout_order_transitions | #3، #4 | ناقص |
| چاپ invoice و packing slip | Orders/Finance | /checkout/orders/{id}/invoice و نسخهٔ داخلی هدف | checkout_orders، checkout_order_lines | #82، #3 | ناقص؛ invoice پایه موجود |
| موجودی و stock ledger | Inventory | /api/v1/admin/inventory/adjust، /movements | stock_movements | #5 | ناقص؛ ledger موجود |
| batch، expiry و FEFO | Inventory | /api/v1/admin/inventory/batches | inventory_batches، order_batch_allocations هدف | #5، #82 | ناقص؛ batch/FEFO پایه موجود |
| supplier، receiving، waste، return و reorder | Inventory | contract جدید receiving/returns/waste/reorder | suppliers، purchase_receipts، inventory_batches، stock_movements هدف | #5 | برنامه‌ریزی‌شده |
| مالیات، قیمت، بسته‌بندی و سود | Finance/Reports | /api/v1/admin/commerce/settings، report aggregates | commerce_settings، checkout_orders، checkout_order_lines | #82، #6 | ناقص؛ snapshot موجود |
| ارسال، مناطق، tracking و actual cost | Shipping/Orders | /api/v1/commerce/shipping-methods و shipment contract | commerce_settings، order_shipments، delivery_events هدف | #93، #82 | ناقص؛ rule پایه موجود |
| Customer profile و order history | Customers | /api/v1/admin/customers و /{customerId} | customers، customer_addresses، checkout_orders | #75، #94 | ناقص؛ پایه موجود |
| OTP، consent، notes، تماس و segmentation | Customers/CRM | auth/otp، segment و consent contract | customer_notes، contact_history، consent_events، segments هدف | #75، #94 | برنامه‌ریزی‌شده |
| Corporate request و pipeline | Corporate Sales | /api/v1/corporate-requests و /api/v1/admin/corporate-requests | corporate_requests، corporate_request_events، corporate_request_messages | #97 | ناقص؛ core موجود |
| Package، proforma، reminder و conversion report | Corporate Sales | package/proforma/conversion contract | corporate_packages، reminders، order link هدف | #97 | برنامه‌ریزی‌شده |
| Coupon، discount، bundle و campaign | Marketing | promotion/validate/preview/redemption contract | promotions، coupons، promotion_rules، redemptions هدف | #95 | برنامه‌ریزی‌شده |
| Home/Hero/FAQ/About/Footer/SEO/UTM | Content | content draft/preview/publish/rollback contract | content_pages، content_blocks، content_versions هدف | #30، #7 | ناقص/برنامه‌ریزی‌شده |
| Notification Center و delivery history | Notifications | notification event/provider/retry contract | notifications، templates، attempts هدف | #96 | ناقص؛ پایه موجود |
| Role، permission، session و audit | Access/Security | auth/session/permission/audit contract | users، memberships، roles، permissions، audit_log هدف | #91 | ناقص؛ Owner auth پایه موجود |
| Store profile، theme، locale، flags و onboarding | Settings | store settings/version/preview contract | stores، store_settings، theme_tokens، feature_flags هدف | #98 | برنامه‌ریزی‌شده |
| migration، health، backup و release gate | Platform/Settings | /health و migration pipeline | schema_migrations | #76، #100، #8 | ناقص؛ ledger/CI موجود |
| in-panel help، FAQ و next action | Help Center | help content/search/publish contract | help_articles، module_guides، article_versions هدف | #101 | برنامه‌ریزی‌شده |
| multi-store، white-label و clone | Platform | store context در تمام APIها | stores/tenants و store_id روی تمام entityها هدف | #99 | شروع نشده |
| responsive، accessibility و Persian numerals | Shared Admin/Storefront | shared UI/error/formatter contract | ندارد؛ presentation concern | #4، #77، #28، #29 | ناقص؛ پایه موجود |
| CI سبز و controlled launch | CI/Infra | workflow، environment و verification | migration ledger، deployment metadata | #8، #100 | ناقص؛ CI main سبز |

## مالکیت و قاعدهٔ بدون orphan

هیچ ردیف مهمی بدون Issue نیست. اگر implementation جدید به جدولی نیاز دارد که در ستون «هدف» آمده است، ابتدا migration و API contract همان Issue باید ایجاد شود؛ ساخت جدول پراکنده در runtime یا hard-code در UI مجاز نیست.

## ترتیب خواندن برای Agent بعدی

1. Issueهای P0 و docs/ADMIN_PRODUCT_ROADMAP.md
2. docs/ADMIN_USER_GUIDE.md برای مسیر UX
3. API و migration واقعی main
4. تست و CI
5. سپس implementation یک Slice معنی‌دار با یک commit قابل توضیح
