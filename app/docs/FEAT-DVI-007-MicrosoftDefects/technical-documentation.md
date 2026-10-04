# FEAT-DVI-007 - Microsoft Defects

> **Source/legacy reference:** the analyses in `analysis/` and the "Microsoft behaviour corrected" sections of
> FEAT-DVI-001 to FEAT-DVI-006.
> **Affected objects:** tests only, plus three procedures made callable for them.
> **Namespaces:** `DataverseIntegration.Test`.

## Purpose

Every defect found in Microsoft's CDS, CRM and Field Service integration code during the analysis is listed here
with what proves the redesign does not have it: a unit test, a case of an integration test plan, or the design itself
(the code that had the defect does not exist in the redesign).

## Defects

| # | Microsoft defect | Where | Redesign | Proof |
|---|---|---|---|---|
| 1 | `CDS Int. Table Uncouple` without filters uncouples every coupling of the table, also those of another mapping | Uncouple job | Couplings carry the mapping name; only the mapping's own and unnamed couplings are uncoupled | `DVI Microsoft Defect Tests.UncouplingLeavesCouplingsOfOtherMappingsAlone` |
| 2 | Orphan couplings are read with `Get("Integration ID", "CRM ID")` against the key (CRM ID, Integration ID) and never deleted | Uncouple job | Key order | `…OrphanCouplingIsDeletedByItsPrimaryKey` |
| 3 | Option synchronization decides whether a record changed from `CRM Integration Record`, which option couplings never use | `Int. Option Synch. Invoke` | Compared with the option coupling | `…OptionChangeIsDetectedOnTheOptionCoupling` |
| 4 | Mappings are picked by table and `FindFirst`; a resource always resolves to the Field Service mapping, also from Sales actions | `CRM Integration Management`, pages | Mapping per action group and coupling per Dataverse table | `…ResourceResolvesToTheMappingOfTheRequestedTable` |
| 5 | *Service Item Card*/*List* (Field Service) never assign `CRMIsCoupledToRecord`, so *Delete Coupling* is always disabled | FS page extensions | Availability from the coupling | `…CoupledServiceItemCanBeUncoupled` |
| 6 | Subscribers re-query the mapping with `FindFirst` on the table pair (template, contact rewind, related mapping) | CDS / CRM subscribers | The engine's mapping; lookups prefer the switched mapping | `…RelatedMappingPrefersTheSwitchedMapping` |
| 7 | Inverted `if FSConnectionSetup.IsEnabled() then exit;`: bookable resource types and project task status are filtered only while Field Service is *disabled* | `OnQueryPostFilterIgnoreRecord` (FS) | Filters belong to the handler and always apply | `DVI Field Service Tests.CrewsAndPoolsAreNotSynchronized`, `…OnlyTasksOfOpenProjectsWithUsageLinkGoToFieldService` |
| 8 | Branches check records that were never loaded: the unchanged service order is never checked for unassigned lines; new service lines copy service item line fields from an empty record | FS subscribers | The source record is read | `DVI Microsoft Defect Tests.ServiceLinesWithoutServiceItemLineAreRejected`; service item line from the converter (`DVI FS Value Converter`) |
| 9 | The error for an uncoupled sell-to customer of a project names the bill-to customer | FS project task insert | Names the customer that is missing | `…UncoupledSellToCustomerIsNamedInTheError` |
| 10 | Match-based coupling hard-codes per mapping name (`SALESPEOPLE`, `SALESORDER-ORDER`) whether unmatched records are created | `CRM Integration Management` | Mapping setting through the handler | `…MatchBasedCouplingHonoursTheMappingSettingForSalespeople` |
| 11 | Synchronizing posted invoice lines on their own raises an error | CRM subscriber | Lines wait for their invoice | `DVI Sales Document Tests.LinesOfAnUncoupledInvoiceWaitForTheirInvoice` |
| 12 | With every booking skipped, `SetFilter(BookableResourceBookingId, '')` clears the filter and re-synchronizes every booking | FS service order cascade | Bookings are queued one by one; nothing is queued when there is nothing to do | By design; FEAT-DVI-006 integration test TEST-07 |
| 13 | Posting synchronized project journal lines with *Job Jnl.-Post Line* leaves the consumption write-back buffered until a later batch posting | FS subscribers | Posting through *Job Jnl.-Post Batch* in a completion step | FEAT-DVI-006 integration test TEST-04 |
| 14 | Company ID is written to the Field Service record before the Business Central record is inserted, also when the insert fails | FS inbound customer asset / bookable resource | Written after insert | FEAT-DVI-006 integration test TEST-02 |
| 15 | The reset of SRVORDERLINE-SERVICE raises the event of SRVORDERLINE-ITEM; the Resource branch of the custom-mapping reset is unreachable and never sets `IsHandled` | `FS Setup Defaults` | The app's own reset has no such events | By design (`DVI FS Mapping Defaults`) |
| 16 | The location field of work order products is mapped only when *Location Mandatory* changes, not by a full reset | `FS Setup Defaults` | Mapped whenever locations are mandatory | FEAT-DVI-006 integration test TEST-01 |
| 17 | `AreFieldsRelatedToMappedTables` raises an error when a related table has no mapping | CRM field transfer | The coupled-key converter declines instead | By design (`DVI Coupled Key Converter.AppliesTo`) |
| 18 | Engine re-entry from inside engine events (`SynchRecordsToIntegrationTable`), `Commit` and `Sleep` inside events | CRM / FS subscribers | Follow-ups, prerequisites, completion steps | `DVI Sync Context Tests`, `DVI Sales Document Tests.Completion…` |
| 19 | A completely shipped order is fulfilled only through an internal, on-premises .NET helper | CRM subscriber | Not available in the cloud; documented | Known limitation of FEAT-DVI-005b |

## Objects

| Type | ID | Name | Change |
|---|---|---|---|
| Codeunit | 80015 | DVI Coupling Runner | `SetCouplingFilter` and `DeleteOrphanCoupling` are internal procedures |
| Codeunit | 80027 | DVI Option Coupling Store | `IsUnchangedSinceLastSynch`, used by `DVI Option Record Synch.` |
| Test codeunit | 84022 | DVI Microsoft Defect Tests | Defects 1–6 and 8–10 |

## Known Limitations

- Defects 12–14 and 16 need a Dataverse environment and are covered by the integration test plans.
- Verified by compilation; the unit tests run with `tools\test.ps1`.
