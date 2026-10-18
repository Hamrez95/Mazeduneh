# Browser admin design and feature map

The admin uses an independently implemented Flutter design based on the supplied Vuexy dark demo and the 2026-10-18 reference recording. It does not bundle the vendor template source or assets. Default locale remains Persian, RTL, Vazirmatn, with the existing Jalali date controls.

## Shared design

- Dark canvas `#25293C`, surfaces `#2F3349`, primary `#7367F0`, compact outlined inputs and 6px cards/buttons.
- Continuous 260px right sidebar, collapsible to icons, floating top navigation, account security/logout menu, authorized shortcuts and section search (Ctrl+K).
- Permission-based navigation grouped into dashboard; store; operations/reports; management/security.
- Desktop record tables: loaded-record search, sorting where meaningful, page sizes and pagination, semantic badges, existing edit/detail actions. Server filters/exports keep their existing scope; table search/pagination only affect the loaded records and never claim a full-database count.
- Product, order, customer, promotion, user and audit screens use these tables. Narrow layouts and enlarged text keep the existing card presentations.
- Shared dark tokens also cover inventory, corporate requests, settings, authentication, dialogs, empty/error states and calendars. A light palette/switch remains future work; no inactive switch is presented.

## Store-specific analytics

The existing `reports.read` analytics endpoint now adds `dailySales` and `orderStates`, without changing existing totals or permissions. All queries in one analytics response share a repeatable-read PostgreSQL snapshot.

- Daily trend switches between customer payments and net profit; supports negative profit, pointer selection and keyboard-accessible day selection. UTC day buckets are explicitly labelled and formatted with the current locale/calendar. Unsold days between the first and last paid order appear as zero; empty data is labelled.
- Order state ring counts all orders created within the selected period, including unpaid/cancelled/expired orders. Financial values count only Paid/Preparing/Shipped/Delivered orders, as before.
- Best-selling products in Reports rank the loaded product/variant profitability results by units sold (the existing API returns up to 200 profitability rows). This is not claimed to be a global ranking beyond that limit.
- Existing revenue, discount, batch cost snapshots, packaging, incidental costs, shipping revenue/expense, tax and net-profit breakdowns remain available.
- No invented growth percentages, visitors, conversions, targets or demonstration chart series are shown.

## Reference mapping

| Reference area | Mazeduneh implementation |
| --- | --- |
| Analytics/eCommerce dashboard | Real sales/profit trend, order state ring, KPIs, operational alerts, low stock/expiry, configurable dashboard sections |
| Products/add product/categories | Product table, create/edit product and package prices, uploads/gallery, draft/publication, existing category manager |
| Orders/detail/invoice | Order table/filter/export, payment/status details, transition actions, bulk operations and permitted documents |
| Customers/profile | Customer table, profile/address/consent details, permitted CSV export |
| Discounts | Coupon/campaign table, percentage/fixed/shipping/bundle/BuyGet rules, existing preview and owner approval |
| Store settings | Existing tax and shipping method/customer charge/internal cost settings |
| Users/roles/permissions | User table, invitations, roles and granular permissions, activity toggle, sessions and personal MFA |
| Audit | Searchable activity table with before/after detail dialog |
| Inventory/operations | Existing batches, expiry/FEFO, receipts, movements, adjustments and pricing forms with the shared theme |

## Remaining functional gaps compared with the general-purpose demo

The demo includes products outside a food store's current scope (academy, vehicles/logistics tracking, chat/email client, projects and job kanban). They are not represented as working store modules.

Potential store extensions not delivered by this visual migration: product review moderation, returns/refunds workflow, referral/loyalty program, website visitor/conversion tracking, editable store branding/payment-provider configuration and shipping carrier tracking integration. Their absence must not be confused with a hidden working backend. Existing payment-provider configuration remains deployment configuration, not a new public settings form.

There is no complete English translation or language switch yet; existing English calendar/date localization remains supported. The current release is Persian first. A separate acceptance pass should cover any future full English interface and light palette.

## Local use

Use the normal root PowerShell launcher (`scripts/local.ps1`, or the existing setup shortcut). It builds the secured admin target and runs the browser apps with portable PostgreSQL. Browser URL/port selection remains automatic; no server deployment is part of this change. Local data and credentials remain outside Git.
