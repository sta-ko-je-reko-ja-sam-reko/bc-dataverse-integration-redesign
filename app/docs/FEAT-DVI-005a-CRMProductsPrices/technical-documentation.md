# FEAT-DVI-005a - CRM Products, Units, Prices and Statistics

> **Source/legacy reference:** N/A (greenfield).
> **Affected objects:** the Dynamics 365 Sales table pairs for products, units, price lists and opportunities; the
> option mappings for payment terms, shipment methods and shipping agents; *Update Account Statistics*; nine standard
> pages extended, two more changed.
> **Namespaces:** `DataverseIntegration.CRM`; handler values and the statistics interface in `DataverseIntegration.Core`;
> tests `DataverseIntegration.Test`.

Sales orders and invoices follow in FEAT-DVI-005b.

## Business Process

The behaviour Microsoft's `CRM Int. Table. Subscriber` (and, for option sets, `CDS Int. Table. Subscriber`) adds to these
pairs moves into one handler per pair, selected on the mapping:

| Handler value | Table pair | Behaviour |
|---|---|---|
| Item/Resource - Product (200) | Item, Resource ↔ CRM Product | **Filter:** the write-in product of *Sales & Receivables Setup* is not sent. **To Dataverse:** decimals supported, default price list and company ID on insert; local currency, unit group or base unit, non-negative price and quantity, price list item(s), vendor name, product type (sales inventory or services), and the state from *Blocked* on a new product; after insert the price list items are written and the product is activated; company ID on modify. **From Dataverse:** a product that is not active blocks its item or resource; a new item takes its number from the matching template's number series; after insert the product's unit group and base unit are coupled to the item's (follow-ups). **Uncouple:** the company ID is removed. |
| Unit Group - Unit Group (210) | Unit Group, Unit of Measure ↔ CRM Uomschedule | **To Dataverse:** a unit of measure names its schedule and renames its single unit; an inactive schedule is an error. **Uncoupled match:** the schedule with the expected name is coupled instead of creating a second one. **Match-based coupling:** matches on the unit group's code. |
| Item/Resource Unit of Measure - Unit (220) | Item Unit of Measure, Resource Unit of Measure ↔ CRM Uom | **To Dataverse:** the unit points at the schedule of its item's or resource's unit group; a unit group that is not synchronized yet is queued as a **prerequisite** and the unit fails with a clear error, so the next run succeeds; after insert the product's price list item follows. **Match-based coupling:** limited to the unit group's schedule. |
| Price Group/Price List - Price List (230) | Customer Price Group, Price List Header ↔ CRM Pricelevel | **To Dataverse:** all prices must share one currency and every product must be coupled (an uncoupled product inside the mapping filter is queued as a prerequisite); currency, description, state (active price lists) and company ID on insert; the currency must not change on modify. After insert, modify and when unchanged, the prices of the group or list are queued as follow-ups. |
| Price/Price List Line - Price List Item (240) | Sales Price, Price List Line ↔ CRM Productpricelevel | **To Dataverse:** unit and schedule from the item's or resource's unit. **Uncoupled match:** an existing price list item for the same price list, product and unit is coupled instead of duplicated. **Uncouple:** the company ID is removed. |
| Opportunity - Opportunity (250) | Opportunity ↔ CRM Opportunity | **Filter:** with team ownership, opportunities whose contact is not a person of a company, or whose company has no customer or vendor, are not sent. **To Dataverse:** company ID and owner on insert; company ID on modify. **Uncouple:** the company ID is removed. |
| Payment Terms/Shipping - Sales Document Options (260) | Payment Terms, Shipment Method, Shipping Agent option mappings | After an option is inserted or modified, and when Dynamics 365 Sales is enabled, its label is written to the matching option set of sales orders, quotes and invoices (freight terms have no invoice field). `SyncDocumentOptionSets` writes all coupled options at once. |

Microsoft re-enters its engine from inside a record (prices after a price list, units after a product). Here those
records are queued on `DVI Sync Context` as **follow-ups** and run after the current record. A **prerequisite** is a
follow-up that survives the failure of the record that queued it: the unit group of a unit, the product of a price.

### Account statistics

`DVI IStatisticsAction` is a new UI interface. Its default (`DVI Standard Record Actions`) offers nothing; the
Customer/Vendor - Account value uses `DVI Account Statistics`, which offers *Update Account Statistics* for a coupled
customer when the mapping sends data to Dataverse and Dynamics 365 Sales is enabled. The action replaces Microsoft's
*Update Account Statistics* on the customer card and list.

When *Use Redesigned Synchronization* switches these mappings, `DVI IHandlerScope.Serves` selects the handler
automatically; the product, unit, price and opportunity handlers belong to the Sales module, the option handler to the
Dataverse module (its mappings are part of the Dataverse setup).

## Data Model

| Table | Field | Change |
|---|---|---|
| DVI Follow-up Buffer (80001, temporary) | 5 Keep On Failure | New. True for a prerequisite; `DropFollowUpsAfterFailure` keeps these rows |

## Objects

| Type | ID | Name | Purpose |
|---|---|---|---|
| Enum value | 200 | DVI Sync Handler::DVICRMProduct | Item/Resource - Product |
| Enum value | 210 | DVI Sync Handler::DVICRMUnitGroup | Unit Group - Unit Group |
| Enum value | 220 | DVI Sync Handler::DVICRMUnit | Item/Resource Unit of Measure - Unit |
| Enum value | 230 | DVI Sync Handler::DVICRMPriceLevel | Price Group/Price List - Price List |
| Enum value | 240 | DVI Sync Handler::DVICRMPriceLine | Price/Price List Line - Price List Item |
| Enum value | 250 | DVI Sync Handler::DVICRMOpportunity | Opportunity - Opportunity |
| Enum value | 260 | DVI Sync Handler::DVICRMSalesOption | Payment Terms/Shipping - Sales Document Options |
| Interface | — | DVI IStatisticsAction | *Update Account Statistics* |
| Codeunit | 80400 | DVI Product Handler | Item, Resource ↔ Product |
| Codeunit | 80401 | DVI Unit Group Handler | Unit Group, Unit of Measure ↔ Unit Group |
| Codeunit | 80402 | DVI Unit Handler | Item/Resource Unit of Measure ↔ Unit |
| Codeunit | 80403 | DVI Price Level Handler | Customer Price Group, Price List Header ↔ Price List |
| Codeunit | 80404 | DVI Price Line Handler | Sales Price, Price List Line ↔ Price List Item |
| Codeunit | 80405 | DVI Opportunity Handler | Opportunity ↔ Opportunity |
| Codeunit | 80406 | DVI Sales Option Handler | Option labels on sales document option sets |
| Codeunit | 80410 | DVI CRM Prices | Price list checks, unit lookup, coupled products, price follow-ups |
| Codeunit | 80411 | DVI CRM Units | Schedules, units, coupling of a new product's units |
| Codeunit | 80412 | DVI Account Statistics | `DVI IStatisticsAction` for customers |
| Page extension | 80400–80408 | DVI Item Card, DVI Item List, DVI Resource Card, DVI Resource List, DVI Customer Price Groups, DVI Sales Price Lists, DVI Sales Price List, DVI Opportunity Card, DVI Opportunity List | Redesigned *Dataverse* group |

`DVI Customer Card` and `DVI Customer List` (FEAT-DVI-002) gain *Update Account Statistics*; `DVI Record Actions`
gains `CanUpdateStatistics` and `UpdateStatistics`; `DVI Sync Context` gains `AddPrerequisite` and
`DropFollowUpsAfterFailure`, which `DVI Record Synch.` calls when a record fails.

## Files

```
app/src/CRM/codeunits/       ProductHandler, UnitGroupHandler, UnitHandler, PriceLevelHandler, PriceLineHandler,
                             OpportunityHandler, SalesOptionHandler, CRMPrices, CRMUnits, AccountStatistics
app/src/CRM/pageextensions/  Item, Resource, Customer Price Groups, Sales Price List(s), Opportunity
app/src/Core/interfaces/     IStatisticsAction
test/src/Core/codeunits/     CRMHandlerTests, SyncContextTests
```

## Integration Points

| Point | Procedure | Usage |
|---|---|---|
| CRM Synch. Helper | `SetCRMDecimalsSupportedValue`, `SetCRMDefaultPriceListOnProduct`, `UpdateCRMCurrencyIdIfChanged`, `UpdateCRMProductUomscheduleId`, `UpdateCRMProductUoMFieldsIfChanged`, `UpdateCRMProductPriceIfNegative`, `UpdateCRMProductQuantityOnHandIfNegative`, `UpdateCRMPriceListItem(s)`, `UpdateCRMProductVendorNameIfChanged`, `UpdateCRMProductTypeCodeIfChanged`, `UpdateCRMProductStateCodeIfChanged`, `SetCRMProductStateToActive`, `UpdateItemBlockedIfChanged`, `UpdateResourceBlockedIfChanged`, `GetUnitOfMeasureName`, `GetUnitGroupName`, `FindNAVLocalCurrencyInCRM` | Products, units, currency |
| CRM Integration Management | `IsUnitGroupMappingEnabled`, `IsCRMIntegrationEnabled`, `IsCDSIntegrationEnabled`, `CreateOrUpdateCRMAccountStatistics` | Mode switches and statistics |
| CDS Integration Mgt. | `GetOptionSetMetadata`, `InsertOptionSetMetadataWithOptionValue`, `UpdateOptionSetMetadata` | Document option sets |
| Item Templ. Mgt. | `FillItemKeyFromInitSeries` | Number series of new items |

## Dependencies

| Dependency | App | Usage |
|---|---|---|
| FEAT-DVI-001..004 | this app | Engine, UI framework, converters, company ID and contact relations |

## Known Limitations

- `GetDocumentMetadataInfo` of `CRM Option Mapping` is internal, so the entity and field names of the sales document
  option sets are fixed in `DVI Sales Option Handler` (`salesorder`, `quote`, `invoice`; `paymenttermscode`,
  `freighttermscode`, `shippingmethodcode`). A partner with other option sets uses its own handler value.
- Microsoft runs `SyncDocumentOptionSets` when the connection is set up; here it is a public procedure of
  `DVI Sales Option Handler` and is not called automatically yet.
- The account statistics FactBox reads Dataverse directly and is unchanged.
- Verified by compilation and unit tests only.
