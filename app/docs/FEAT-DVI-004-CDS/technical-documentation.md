# FEAT-DVI-004 - CDS

> **Source/legacy reference:** N/A (greenfield).
> **Affected objects:** the CDS table pairs of the standard integration (Customer, Vendor ↔ Account; Contact ↔ Contact; Currency ↔ Transaction Currency; Salesperson/Purchaser ↔ User); eight standard pages extended.
> **Namespaces:** `DataverseIntegration.CDS`; handler values in `DataverseIntegration.Core`; tests `DataverseIntegration.Test`.

## Business Process

The behaviour Microsoft's `CDS Int. Table. Subscriber` adds to these table pairs (and the parts of it that live in
`CRM Int. Table. Subscriber`) moves into one handler per pair, selected on the mapping:

| Handler value | Table pair | Behaviour |
|---|---|---|
| Customer/Vendor - Account (100) | Customer, Vendor ↔ CRM Account | **To Dataverse:** company ID and owner (owning team, or the user coupled to the salesperson) on insert; company ID on modify; after a new customer, the contact mapping's watermark moves back so its contacts follow. **From Dataverse:** customer or vendor number from the matching template's number series; an inactive account blocks its customer; after insert the company ID is written back to the account and the coupled contacts of the account get their company and primary contact; after modify the contact of the customer or vendor is updated. **Uncouple:** the company ID is removed from the account and the couplings of its person contacts are removed. |
| Contact - Contact (110) | Contact ↔ CRM Contact | **Filter:** contacts whose company has no customer or vendor are not sent to Dataverse. **To Dataverse:** parent account from the company's customer or vendor, company ID, owner on insert; parent account and company ID on modify; an unchanged contact without parent account gets one; after insert, the contact becomes the account's primary contact when it has none. **From Dataverse:** the contact's company from the parent account (error when it does not exist); after insert the contact becomes the primary contact of its customer or vendor when that has none, and the company ID is written back. **Uncouple:** the company ID is removed. |
| Currency - Transaction Currency (120) | Currency ↔ CRM Transactioncurrency | **Uncoupled match:** an existing transaction currency with the same ISO code is coupled instead of creating a new one. **To Dataverse:** default precision and symbol on insert; symbol on modify; the current exchange rate (error when it is missing). |
| Salesperson - User (130) | Salesperson/Purchaser ↔ CRM Systemuser | A salesperson created from a Dataverse user gets the next code of the series `SP NO. 00001`. |

Where Microsoft updates related records outside the current pair (primary contacts, contact companies, the account's
company ID), the handler keeps the coupling's synchronization time when the related record had not changed since its
last synchronization, so the fix is not sent back as a change.

When *Use Redesigned Synchronization* switches these mappings, `DVI IHandlerScope.Serves` selects the handler
automatically. The page extensions put the redesigned *Dataverse* group on the cards and lists of these tables (see
FEAT-DVI-002 for the actions and their availability).

## Data Model

No new tables or fields.

## Objects

| Type | ID | Name | Purpose |
|---|---|---|---|
| Enum value | 100 | DVI Sync Handler::DVICDSAccount | Customer/Vendor - Account |
| Enum value | 110 | DVI Sync Handler::DVICDSContact | Contact - Contact |
| Enum value | 120 | DVI Sync Handler::DVICDSCurrency | Currency - Transaction Currency |
| Enum value | 130 | DVI Sync Handler::DVICDSSalesperson | Salesperson - User |
| Codeunit | 80210 | DVI Account Handler | Customer and Vendor ↔ Account |
| Codeunit | 80212 | DVI Contact Handler | Contact ↔ Contact |
| Codeunit | 80213 | DVI Currency Handler | Currency ↔ Transaction Currency |
| Codeunit | 80214 | DVI Salesperson Handler | Salesperson ↔ User |
| Codeunit | 80220 | DVI CDS Company | Company ID and owner |
| Codeunit | 80221 | DVI CDS Relations | Accounts, contacts, primary contacts, blocking, mapping lookup |
| Page extension | 80202–80209 | DVI Vendor Card, DVI Vendor List, DVI Contact Card, DVI Contact List, DVI Currency Card, DVI Currencies, DVI Salesperson Card, DVI Salespersons List | Redesigned *Dataverse* group |

`DVI Config. Template Applier` gains `FindTemplateCode` for the number series of new customers and vendors.

## Files

```
app/src/CDS/codeunits/       AccountHandler, ContactHandler, CurrencyHandler, SalespersonHandler, CDSCompany, CDSRelations
app/src/CDS/pageextensions/  Vendor, Contact, Currency and Salesperson card and list
test/src/Core/codeunits/     CDSHandlerTests
```

## Integration Points

| Point | Procedure | Usage |
|---|---|---|
| CDS Integration Mgt. | `CheckCompanyId`, `SetCompanyId`, `ResetCompanyId`, `HasCompanyIdField`, `SetOwningTeam`, `SetOwningUser`, `GetCDSCompany` | Company and owner |
| CRM Synch. Helper | `GetCoupledCDSUserId`, `SetContactParentCompany`, `FindContactRelatedCustomer`, `FindContactRelatedVendor`, `UpdateContactOnModifyCustomer`, `UpdateContactOnModifyVendor`, `GetCRMLCYToFCYExchangeRate`, `GetCRMCurrencyDefaultPrecision`, `UpdateFieldRefValueIfChanged` | Relations and currency |
| Customer / Vendor Templ. Mgt. | `FillCustomerKeyFromInitSeries`, `FillVendorKeyFromInitSeries` | Number series of new records |
| CRM Integration Management | `RemoveCoupling(TableID, var LocalIdList, Schedule)` | Child contact couplings on uncouple |
| Integration Table Mapping | `IsFieldMappingEnabled` | Primary contact only when its field mapping is enabled |

## Dependencies

| Dependency | App | Usage |
|---|---|---|
| FEAT-DVI-001..003 | this app | Engine, UI framework, converters |

## Known Limitations

- **Users are not added to the default owning team automatically.** Microsoft does this after creating a salesperson
  from a Dataverse user, through procedures that are on-premises only; an extension for the cloud cannot call them.
  Use *Add Users to Team* on *Dataverse Connection Setup*.
- Whether contacts may synchronize without a customer or vendor follows Microsoft's default (they may not); a partner
  changes it by its own handler value for the contact mapping.
- Product → Item (template and number series of new items) comes with the item handler of FEAT-DVI-005a.
- The option-set metadata of sales documents (payment terms, shipment methods, shipping agents) is Dynamics 365 Sales
  behaviour and comes with FEAT-DVI-005a.
- Microsoft's subscriber that deletes a salesperson's coupling when the salesperson is deleted is not an engine event;
  it stays active.
- Verified by compilation and unit tests only.
