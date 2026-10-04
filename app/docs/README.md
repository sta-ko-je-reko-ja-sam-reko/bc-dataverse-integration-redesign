# Documentation

| Folder / file | Content |
|---|---|
| `architecture.md` | The redesign: takeover per mapping, pipeline and UI interfaces, value converters, delivery plan |
| `analysis/subscribers-*.md` | Inventory of Microsoft's CDS, CRM and Field Service subscribers, with file:line citations |
| `analysis/ui-and-entry-points.md` | Inventory of the pages, actions and other entry points (redirect, coupling dialog, create flows, setup actions) |
| `getting-started-english.md` | How to install and switch on the app |
| `privacy.md` | What the app stores and sends |
| `FEAT-DVI-001-CorePipeline/` | The takeover, the engine, option and coupling jobs, the mapping switch |
| `FEAT-DVI-002-UIFramework/` | Action interfaces, record actions facade, CRM Redirect takeover, Customer pilot pages |
| `FEAT-DVI-003-ValueConverters/` | One converter per field mapping instead of `OnTransferFieldData` |
| `FEAT-DVI-004-CDS/` | Handlers and pages for customers, vendors, contacts, currencies and salespeople |
| `FEAT-DVI-005a-CRMProductsPrices/` | Handlers and pages for products, units, price lists, opportunities, document option sets; account statistics |
| `FEAT-DVI-005b-CRMSalesDocuments/` | Handlers and pages for sales orders and posted invoices with their lines; completion step; write-in products |
| `FEAT-DVI-<n>-<Title>/` | One folder per feature: technical documentation, test plans, getting started |

The app supports English only (`supportedLocales` en-US), so each feature has an English getting-started guide and no
locale copy.
