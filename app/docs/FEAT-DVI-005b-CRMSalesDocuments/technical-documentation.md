# FEAT-DVI-005b - CRM Sales Documents

> **Source/legacy reference:** N/A (greenfield).
> **Affected objects:** the Dynamics 365 Sales table pairs of sales orders and posted sales invoices, with their lines;
> four standard pages extended.
> **Namespaces:** `DataverseIntegration.CRM`; handler and converter values, the completion step in
> `DataverseIntegration.Core`; tests `DataverseIntegration.Test`.

## Business Process

Microsoft synchronizes the lines of an order or invoice by re-entering its engine from inside the header's events,
then sets totals, state and status. Here the header queues its lines as **follow-ups** and a **completion step** for
itself; the completion runs after the lines and the coupling is re-stamped, so its changes are not seen as edits.

| Handler value | Table pair | Behaviour |
|---|---|---|
| Sales Order - Order (270) | Sales Header ↔ CRM Salesorder | **Filter:** archived orders are left alone (bidirectional). **Orders only to Dataverse:** before an update the Dataverse order is set Active, after it Invoiced (fully invoiced) or Submitted. **Bidirectional, to Dataverse:** on insert the price list (by currency, or the order's own with extended pricing), company ID, name, document occurrence and owner; on modify the price list and company ID; after insert, modify or unchanged the lines are queued (Dataverse lines whose sales line was deleted are removed) and the completion sets the line discount total and, after insert or modify, the Submitted state. **Bidirectional, from Dataverse:** the order is reopened before the update; a new order takes its quote number and the quote is archived; the lines are queued (sales lines whose Dataverse line was deleted are removed); the completion applies the order discount, adds the freight line, releases the order (unless prepayment is required), writes the order number back to a new Dataverse order and creates notes from Dataverse annotations. **Uncouple:** the company ID is removed and the couplings of the order's lines are removed. |
| Sales Order Line - Order Product (280) | Sales Line ↔ CRM Salesorderdetail | **To Dataverse:** the line's Dataverse order; the unit (from the unit of measure, or from the item's or resource's unit when unit groups are on); a write-in line on insert; tax on insert and modify. **From Dataverse:** the sales order and line type (item, resource, or the write-in product's type); the unit and the price when unit groups are on; auto-reservation after insert. |
| Posted Sales Invoice - Invoice (290) | Sales Invoice Header → CRM Invoice | **Filter:** an invoice whose Dataverse invoice is no longer active is not updated. **Before insert:** the invoice has lines, its items and resources are not blocked and their products are coupled (an uncoupled product inside its mapping's filter is queued as a **prerequisite**); description from the shipment method; from the Dataverse order it was invoiced from — order, opportunity, price list, name, customer and owner — or else the customer's account (a prerequisite when not coupled) and the price list of its currency; company ID and owning team. **After insert:** the lines are queued; the completion sets totals, discount, payment status and, with prices including VAT, a rounding line. **Uncouple:** the company ID is removed. |
| Posted Sales Invoice Line - Invoice Product (300) | Sales Invoice Line → CRM Invoicedetail | **Filter:** lines of an invoice that is not coupled wait for their invoice (Microsoft raises an error instead). **Before insert:** invoice, currency, exchange rate, ship-to, line number, tax, price without VAT, product and unit, or a write-in product; a missing product price is created. **After insert:** discount, tax, base and extended amount. |

### Write-in product converter

`DVI Write-in Product Converter` (value 55 of `DVI Value Converter`) is the default for the field mapping
Sales Line *No.* ↔ order line *ProductId*: the write-in product of *Sales & Receivables Setup* has no Dataverse product,
and a Dataverse line without product gets the write-in product; other lines use the coupled item or resource. It
replaces the branches of Microsoft's `OnTransferFieldData` for this field.

### Completion step

`DVI Sync Context.AddCompletion(MappingName, LocalSystemId, ToIntegrationTable, SynchAction)` queues it once per
record; `DVI Follow-up Processor` runs the completions after all other follow-ups, each through
`DVI Completion Runner`, which calls `DVI IRecordCompletion.Complete`, logs a failure on the job that queued it, and
re-stamps the coupling. Completions are dropped when their record fails, like other follow-ups.

## Data Model

| Table | Field | Change |
|---|---|---|
| DVI Follow-up Buffer (80001, temporary) | 6 Completion, 7 Synch Action, 8 Job Id | New; key Completion, Entry No. |

## Objects

| Type | ID | Name | Purpose |
|---|---|---|---|
| Interface | — | DVI IRecordCompletion | Completion step of a record |
| Codeunit | 80048 | DVI Completion Runner | Runs a completion, logs failures, re-stamps the coupling |
| Enum value | 270 | DVI Sync Handler::DVICRMSalesOrder | Sales Order - Order |
| Enum value | 280 | DVI Sync Handler::DVICRMSalesOrderLine | Sales Order Line - Order Product |
| Enum value | 290 | DVI Sync Handler::DVICRMInvoice | Posted Sales Invoice - Invoice |
| Enum value | 300 | DVI Sync Handler::DVICRMInvoiceLine | Posted Sales Invoice Line - Invoice Product |
| Enum value | 55 | DVI Value Converter::DVIWriteInProduct | Write-in product |
| Codeunit | 80407 | DVI Sales Order Handler | Sales Header ↔ Order |
| Codeunit | 80408 | DVI Sales Order Line Handler | Sales Line ↔ Order Product |
| Codeunit | 80409 | DVI Invoice Handler | Posted Sales Invoice → Invoice |
| Codeunit | 80413 | DVI Invoice Line Handler | Posted Sales Invoice Line → Invoice Product |
| Codeunit | 80414 | DVI CRM Sales Orders | Order price list, lines, state, release, discount, freight, notes |
| Codeunit | 80415 | DVI CRM Invoices | Invoice checks, customer and order, lines, totals, rounding |
| Codeunit | 80416 | DVI Write-in Product Converter | Sales line number ↔ product |
| Page extension | 80409–80412 | DVI Sales Order, DVI Sales Order List, DVI Posted Sales Invoice, DVI Posted Sales Invoices | Redesigned *Dataverse* group |

`DVI Generic Handler` implements `DVI IRecordCompletion` as the default (nothing to do). `DVI CRM Prices.RequireCoupledRecord`
is now internal and shared, so customers are queued as prerequisites the same way as products.

## Files

```
app/src/Core/interfaces/      IRecordCompletion
app/src/Core/codeunits/       CompletionRunner (+ SyncContext, FollowUpProcessor, GenericHandler)
app/src/CRM/codeunits/        SalesOrderHandler, SalesOrderLineHandler, InvoiceHandler, InvoiceLineHandler,
                              CRMSalesOrders, CRMInvoices, WriteInProductConverter
app/src/CRM/pageextensions/   SalesOrder, SalesOrderList, PostedSalesInvoice, PostedSalesInvoices
test/src/Core/codeunits/      SalesDocumentTests
```

## Integration Points

| Point | Procedure | Usage |
|---|---|---|
| CRM Synch. Helper | `UpdateCRMPriceList`, `CreateCRMPriceList`, `FindCRMPriceListByCurrencyCode`, `CreateCRMPricelevelInCurrency`, `UpdateCRMInvoiceStatus`, `CreateCRMProductpriceIfAbsent`, `GetCRMTransactioncurrency` | Price lists, invoice status, product prices |
| CRM Sales Order to Sales Order | `GetCRMSalesOrder`, `GetCoupledCustomer`, `GetCRMAccountOfCRMSalesOrder` | Invoice of a Dataverse order |
| CRM Connection Setup | `IsBidirectionalSalesOrderIntEnabled` | Mode |
| CDS Integration Mgt. | `SetOwningUser`, `SetOwningTeam` | Owner of the invoice |
| Document Totals | `CalculatePostedSalesInvoiceTotals` | Invoice totals |
| Release Sales Document, Prepayment Mgt., Sales - Calc Discount By Type, ArchiveManagement | release/reopen, prepayment test, invoice discount, quote archive | Orders from Dataverse |
| CRM Annotation Coupling | `ExtractNoteText` | Notes |

## Dependencies

| Dependency | App | Usage |
|---|---|---|
| FEAT-DVI-001..005a | this app | Engine, UI framework, converters, company and owner, products and prices |

## Known Limitations

- **A completely shipped order is not fulfilled in Dataverse.** Microsoft fulfils it through a .NET helper that is
  internal and on-premises only; the order keeps its state. A partner adds this with its own handler value.
- `CRM Sales Document Posting Mgt.IsSalesOrderFullyInvoiced` is internal; `DVI CRM Sales Orders.IsFullyInvoiced` is
  the same check.
- Creating sales orders from Dataverse orders when sales orders go only to Dataverse (*Create in Business Central* on
  the Dataverse order list, `CRM Sales Order to Sales Order`) is not engine code and is unchanged.
- Microsoft's subscribers that delete or archive a sales order's coupling when the order is posted or deleted are not
  engine events; they stay active.
- Verified by compilation and unit tests only.
