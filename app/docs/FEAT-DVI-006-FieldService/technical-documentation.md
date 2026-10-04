# FEAT-DVI-006 - Field Service

> **Source/legacy reference:** N/A (greenfield).
> **Affected objects:** all table pairs of Microsoft's *Field Service Integration* app: master data, project journal
> lines, service orders; the Field Service mapping reset; eleven standard pages extended, *FS Connection Setup* changed.
> **Namespaces:** `DataverseIntegration.FieldService`; handler and converter values, two new interfaces and the
> change-detection step in `DataverseIntegration.Core`; tests `DataverseIntegration.Test`.

## Business Process

The behaviour of `FS Int. Table Subscriber` moves into one handler per table pair, selected on the mapping. Field
transforms of its `OnTransferFieldData` and `OnFindNewValueForCoupledRecordPK` move into `DVI FS Value Converter`.
Microsoft re-enters its engine for a work order's incidents and lines and posts project journal lines from engine
events; here those are follow-ups and completion steps.

### Master data

| Handler value | Table pair | Behaviour |
|---|---|---|
| Resource - Bookable Resource (400) | Resource ↔ FS Bookable Resource | **Filter:** contacts, crews, facilities and pools are not synchronized (Microsoft's check only runs when Field Service is *disabled*). **To Field Service:** company ID, time zone, resource type (equipment, account, user, generic), user from the time sheet owner's e-mail. **From Field Service:** resource type, hour unit of measure, time sheet owner from the user's e-mail; after insert the company ID is written to the Field Service record (Microsoft writes it before the insert, also when the insert fails). |
| Service Item - Customer Asset (410) | Service Item ↔ FS Customer Asset | **Filter:** an uncoupled service item whose item's product has *Convert to Customer Asset* off. Company ID as above. |
| Location - Warehouse (420) | Location → FS Warehouse | Company ID. |
| Service Order Type - Work Order Type (430) | Service Order Type ↔ FS Work Order Type | Company ID. |
| Project Task - Project Task (440) | Job Task → FS Project Task | **Filter:** the project exists, is not blocked, is open and applies usage links (again only checked by Microsoft when Field Service is disabled). **Insert:** project description, billing and service account from the bill-to and sell-to customers; a customer that is not coupled is queued as a **prerequisite** (Microsoft's error names the bill-to customer for the sell-to case). |

### Projects

| Handler value | Table pair | Behaviour |
|---|---|---|
| Project Journal Line - Work Order Product/Service (450) | Job Journal Line ← FS Work Order Product, FS Work Order Service | **Filter:** work orders that go to service orders, and (when only used lines synchronize) lines whose quantities are fully consumed and invoiced — decided for the project mapping only (Microsoft cannot tell the project and the service mapping apart). **Before transfer:** project and task from the coupled project task. **Insert:** journal template and batch from the Field Service setup, document number and posting date by the posting rule, source and reason code, price and cost calculation, item, quantities net of what the project planning lines already consumed and invoiced; services check the item (not inventory, not blocked, hour unit). **After insert:** for a service item with a coupled booked resource a budget line for the resource is inserted and coupled. **Modify / unchanged:** the correlated budget or billable line follows. **Posting:** when the line is used or the work order completed (by the posting rule) a **completion step** posts the line and its correlated line through *Job Jnl.-Post Batch*, so Microsoft's write-back of consumed quantities runs (posting with *Job Jnl.-Post Line*, as Microsoft does, leaves them buffered until a later batch posting). **Deletion:** a posted, deleted line is skipped when everything is consumed and invoiced, else a new line is created for the rest. |

The invoiced quantities of project lines are written back to the work order products and services when their posted
sales invoice is sent to Dataverse (`DVI Invoice Handler`, FEAT-DVI-005b).

### Service orders

| Handler value | Table pair | Behaviour |
|---|---|---|
| Service Order - Work Order (460) | Service Header ↔ FS Work Order | **Filter:** archived orders; work orders without incidents. **Change detection:** service orders whose service item lines or service lines changed are sent although the header did not (`DVI IChangeDetection`; Microsoft re-enters its engine from an internal event). **To Field Service:** every line must have a service item line; company ID on insert and modify; after insert, modify and unchanged the service item lines and item and service lines are queued. **From Field Service:** after insert the customer is validated again; after insert, modify and unchanged lines whose Field Service record was deleted are removed (the order archived first, once) and incidents, products, services and completed bookings are queued (skipping lines marked *Skip Reimport*). **Coupling:** company ID; **uncouple:** removed. **Redirect:** a link to a work order opens the service order, or its archive when the order was deleted (`DVI ILocalRecordView`). |
| Service Item Line - Work Order Incident (470) | Service Item Line ↔ FS Work Order Incident | **From:** order, line number, description from the incident type. **To:** work order, default incident type (created when missing), company ID. |
| Service Line - Work Order Product/Service/Booking (480) | Service Line ↔ FS Work Order Product, FS Work Order Service, FS Bookable Resource Booking | **Filter:** lines of archived work orders. **From:** order, line number, type; quantities (estimated lines have nothing to ship, invoice or consume; used lines ship the larger of quantity and quantity to bill); bookings get the order's *FS Bookings* service item line. **To:** work order, company ID, estimate. |

### Field values

`DVI FS Value Converter` (value 5 of `DVI Value Converter`, before the generic converters) is the default for:
work order status (not sent; received as Pending / In Process / Finished), durations in minutes ↔ hours, the creation
date, quantities and durations net of consumed and invoiced quantities for journal lines (nothing to invoice on budget
lines), descriptions, units ↔ item units of measure, incidents ↔ service item line numbers.

### Reset

*Use Default Synchronization Setup* on *FS Connection Setup* runs `DVI FS Mapping Defaults.ResetConfiguration`: the
Field Service mappings of the integration type are created again (definitions as in Microsoft's `FS Setup Defaults`),
with their job queue entries, then switched to this app's handlers. Differences: the location field of work order
products is mapped whenever locations are mandatory (Microsoft only does it when the setting changes); ITEM-PRODUCT is
not recreated (Microsoft's procedure is on-premises only) but gets the product type field mapping when missing.

### UI

Field Service pages get a *Field Service* group bound to the Field Service table (`DVI Record Actions.Refresh(RecordId,
IntegrationTableId)`), so a resource shows its product and its bookable resource separately; the Field Service app's
group is hidden while the redesigned integration is enabled.

## Data Model

No new tables or fields.

## Objects

| Type | ID | Name | Purpose |
|---|---|---|---|
| Interface | — | DVI IChangeDetection | Records changed through related records |
| Interface | — | DVI ILocalRecordView | Open the local record of a Dataverse link |
| Enum values | 400–480 | DVI Sync Handler::DVIFS… | See above |
| Enum value | 5 | DVI Value Converter::DVIFieldServiceValue | Field Service value |
| Codeunit | 80810–80818 | DVI Bookable Resource Handler, DVI Customer Asset Handler, DVI Warehouse Handler, DVI Work Order Type Handler, DVI Project Task Handler, DVI Project Line Handler, DVI Work Order Handler, DVI Incident Handler, DVI Work Order Line Handler | Handlers |
| Codeunit | 80830 | DVI FS Records | Company ID on Field Service records, integration type, mapping lookup |
| Codeunit | 80831 | DVI FS Projects | Planning quantities, journal line setup, budget lines, posting, deletion, write-back |
| Codeunit | 80832 | DVI FS Value Converter | Field values |
| Codeunit | 80833 | DVI FS Service Orders | Service order cascade, quantities, archive, change detection, redirect |
| Codeunit | 80834 | DVI FS Mapping Defaults | Field Service reset |
| Page extension | 80800–80811 | Resource, Service Item, Location, Service Order Type, Project Task and Service Order pages; FS Connection Setup | *Field Service* group; reset |

`DVI Table Synch.` asks the handler for indirectly changed records; `DVI Record Mapping Resolver` resolves by
integration table; `DVI Redirect` opens local records through `DVI ILocalRecordView` (default: the coupled record's
card); the CRM resource pages are bound to *CRM Product*.

## Files

```
app/src/Core/interfaces/          IChangeDetection, ILocalRecordView
app/src/FieldService/codeunits/   handlers, FSRecords, FSProjects, FSValueConverter, FSServiceOrders, FSMappingDefaults
app/src/FieldService/pageextensions/
test/src/Core/codeunits/          FieldServiceTests
```

## Dependencies

| Dependency | App | Usage |
|---|---|---|
| Field Service Integration | Microsoft | FS tables and table extensions, FS Connection Setup |
| FEAT-DVI-001..005b | this app | Engine, UI, converters, company ID, prerequisites, completion step |

## Known Limitations

- Field Service subscribers to non-engine events stay active: consumption write-back on project posting, archive and
  deletion tracking of service orders, the *Location Mandatory* mapping creation, the service item mapping filter check,
  multi-company filter for journal line mappings.
- `OnSetUpNewLineOnNewLine` (Field Service's only runtime publisher) is not raised; a partner replaces the journal line
  setup with its own handler value.
- Verified by compilation and unit tests only.
