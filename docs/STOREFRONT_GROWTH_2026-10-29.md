# Storefront growth — development cycle, 29 October 2026

## Branch and release boundary

Development takes place on `dev`, starting from main `1f335fd291629ac128447975839c02aa5f75b787`. This work does not authorize a production deployment or a merge into main. The current Cloudflare preview and production configuration remain unchanged.

## Backlog reconciliation

At the owner's request, 26 historical issues were closed as superseded (`not_planned`), with links to their successor issues. Closure does **not** mean their unfinished acceptance criteria passed. Their original descriptions are preserved in [the backlog snapshot](LEGACY_BACKLOG_2026-10-29.json).

| Issue | Scope | Delivery status |
| --- | --- | --- |
| #345 | Server-rendered catalog and technical SEO | Initial implementation on dev; CI and connected-server acceptance pending |
| #346 | Useful pages for distinct gifting search intents | Four guides and a guide hub implemented on dev; editorial acceptance pending |
| #347 | Guided gift discovery | Occasion/budget helper and corporate-form handoff implemented on dev; acceptance pending |
| #348 | Product clarity and mobile purchasing | Initial clarity and keyboard/mobile improvements on dev; interaction acceptance pending |
| #349 | Search visibility and conversion measurement | Requires owner-controlled search accounts and a deployed connected server |
| #350 | Original photography and packaging prototypes | Requires real product information, photographs and production confirmation |
| #351 | Server, payment and controlled launch acceptance | Preserves incomplete server/payment/restore/pilot gates from #244, #100 and #8 |
| #352 | Legacy scope and advanced admin backlog | Preserves the remaining historical work; no false completion claim |
| #353 | Production performance and accessibility | Deployed measurements and complete interaction acceptance remain pending |

## Implemented first slice

- `/gifts` helps visitors choose by occasion and optional budget. Personal recommendations use available catalog packages; they do not modify the cart. Preview products are explicitly identified as examples.
- `/gifts/corporate-nut-gifts`, `/gifts/yalda-corporate-gifts`, `/gifts/employee-appreciation-gifts` and `/gifts/meeting-snack-boxes` have distinct, useful content, preparation checklists and visible questions and answers.
- Guide links preselect only recognized occasions in the existing corporate request form. Budget is passed as whole tomans per package; the existing submission calculation and server validation remain authoritative.
- Shared header, footer, typography and restrained green/cream styling remain consistent. Existing artwork is reused and identified as illustrative, without claiming stock or manufactured packaging.
- The selected package's price is explained beside shipping/return links. Multi-package products no longer show a potentially misleading product-level weight. Package selection supports arrow/Home/End keys; mobile purchase controls have a contained sticky surface and larger touch targets.
- The server seeds the public catalog and product page from the published API using a bounded timeout and 60-second revalidation. API failure does not substitute demonstration products in a live store. Browser refresh preserves the previous live catalog on connection failure.
- Product structured data uses published API prices in **IRR**, without converting them to UI tomans. No fabricated reviews, ratings, GTINs, health claims or delivery promises are added.
- Canonical URLs, organization and breadcrumb data, `robots.txt` and a sitemap are included. Preview product fixtures are omitted from the sitemap and marked noindex. Cart, checkout and profile retain noindex metadata; crawling them remains allowed so that instruction can be read.
- Search-specific AI markup is not required. General crawler access is retained; no Cloudflare security policy or training-crawler preference is changed.

## Review and acceptance

TypeScript checking and production/static builds are build checks, not a claim that every flow has been tested. The existing production-route CI fixture was updated to return a complete public product response because the page now renders real product data on the server; no new test suite was added.

Before merging: review the latest dev-head CI, check the new routes on desktop/mobile with a connected API, verify genuine product markup in Google's tools, and confirm corporate inquiry handoff. External search indexing, AI citations, ranking and conversion gains cannot be guaranteed.

## Design and search references

- [Nuts.com corporate gifts](https://nuts.com/pages/corporate-gifts): occasion-led discovery, clear customization inquiry and useful questions.
- [Nuts.com custom gifts](https://nuts.com/custom-gifts): a small set of starting choices rather than an overwhelming configurator.
- [Fortnum & Mason corporate hampers](https://www.fortnumandmason.com/hampers/all-hampers/corporate-hampers): clear gift contents and comparisons.
- [Google AI features guidance](https://developers.google.com/search/docs/appearance/ai-features): ordinary search eligibility remains the foundation.
- [Google product structured data](https://developers.google.com/search/docs/appearance/structured-data/product).
- [Google JavaScript SEO basics](https://developers.google.com/search/docs/crawling-indexing/javascript/javascript-seo-basics).
- [OpenAI crawler documentation](https://developers.openai.com/api/docs/bots): search crawler access is independent from training preferences.

These are interaction references, not evidence of specific conversion gains. No competitor code, photographs or branding were copied.
