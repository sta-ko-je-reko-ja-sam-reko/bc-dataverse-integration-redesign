# Field Service Integration (BC 29) – event-subscriber inventory

Source: `src/fs` (app "Field Service Integration", Microsoft, 29.0.54011.55616, `app.json`; `internalsVisibleTo` = only "Field Service Integration Test Library", `app.json:16-22`).
Base references: `src/base/Integration/...`.

Path abbreviations:
- **SUB** = `fs/src/Codeunits/FSIntTableSubscriber.Codeunit.al` (codeunit 6610 "FS Int. Table Subscriber", `SingleInstance = true` SUB:32)
- **DEF** = `fs/src/Codeunits/FSSetupDefaults.Codeunit.al` (codeunit 6611 "FS Setup Defaults", not SingleInstance)
- **IRSI** = `base/Integration/SynchEngine/IntegrationRecSynchInvoke.Codeunit.al`
- **CRMSUB** = `base/Integration/D365Sales/CRMIntTableSubscriber.Codeunit.al`
- **CDSSUB** = `base/Integration/Dataverse/CDSIntTableSubscriber.Codeunit.al`
- **CRMIM** = `base/Integration/Dataverse/CRMIntegrationManagement.Codeunit.al`
- **CRMITS** = `base/Integration/Dataverse/CRMIntegrationTableSynch.Codeunit.al`
- **ITM** = `base/Integration/SynchEngine/IntegrationTableMapping.Table.al`

Important: there is **no explicit mapping-name dispatch** anywhere. Almost all record-level subscribers dispatch on
`GetSourceDestCode()` = `SourceRecordRef.Name() + '-' + DestinationRecordRef.Name()` (SUB:2776-2781), i.e. *table names as strings*,
not the `Integration Table Mapping` record (even where the event passes it). The global guard is `FSConnectionSetup.IsEnabled()`
(`FSConnectionSetup.Table.al:1056-1061`); some use `IsIntegrationTypeServiceEnabled()` / `IsIntegrationTypeProjectEnabled()`
(`FSConnectionSetup.Table.al:1063-1071`; note "Project" = only enum value `Projects`, **not** "Service and projects").

Table pairs registered by FS (DEF, see section 5):

| Mapping name | BC table | FS/Dataverse table |
|---|---|---|
| PROJECTTASK | Job Task | FS Project Task (bcbi_projecttask) |
| PJLINE-WORDERPRODUCT | Job Journal Line | FS Work Order Product |
| PJLINE-WORDERSERVICE | Job Journal Line | FS Work Order Service |
| SVCITEM-CUSTASSET | Service Item | FS Customer Asset |
| RESOURCE-BOOKABLERSC | Resource | FS Bookable Resource |
| LOCATION | Location | FS Warehouse |
| SRVORDERTYPE | Service Order Type | FS Work Order Type |
| SRVORDER | Service Header | FS Work Order |
| SRVORDERITEMLINE | Service Item Line | FS Work Order Incident |
| SRVORDERLINE-ITEM | Service Line | FS Work Order Product |
| SRVORDERLINE-SERVICE | Service Line | FS Work Order Service |
| SRVORDERLINE-RESOURC | Service Line | FS Bookable Resource Booking |
| ITEM-PRODUCT (base CRM mapping, reused) | Item | CRM Product |

Note: the same BC table (Service Line, Job Journal Line) and the same FS table (FS Work Order Product / Service) each appear in
**two or three** mappings. Record-level events disambiguate only by the source/dest table-name pair, which is sufficient for
Service Line vs. Job Journal Line, but **not** for events that pass only a SourceRecordRef (QueryPostFilter, DeletionConflict uses the mapping).

---

## 1. Subscriber table

### 1a. FS Int. Table Subscriber (33 subscribers)

Columns: # · SUB line · procedure · publisher + exact event · params (as subscribed) · pairs / branches (code) · summary · guards.

| # | Line | Subscriber proc | Publisher → event | Params | Branch (Source-Dest code or table) → summary | Guards |
|---|---|---|---|---|---|---|
| 1 | 66 | `OnEnsureConnectionSetupIsDisabled` | Table "CDS Connection Setup" → `OnEnsureConnectionSetupIsDisabled` | () | n/a – blocks setting up plain Dataverse connection while FS connection enabled: logs `0000MQW`, raises ErrorInfo with navigation to page "FS Connection Setup" (SUB:72-82). | `FSConnectionSetup.Get()` and `IsEnabled()`; skip when Server Address = `@@test@@` (SUB:75). |
| 2 | 85 | `OnEnableMultiCompanySynchronization` | Table "Integration Table Mapping" → `OnEnableMultiCompanySynchronization` (internal event, ITM:1240, raised ITM:1001) | var IntegrationTableMapping; var IsHandled | **Table ID = Job Journal Line** (any Integration Table, i.e. both PJLINE-WORDERPRODUCT and PJLINE-WORDERSERVICE) → sets IsHandled, adds `CompanyId = CDSCompany.CompanyId` to integration table filter, confirm + message (SUB:105-127). | `IsHandled` (96), `Type = Dataverse` (99), FS enabled (102). Does not check Integration Table ID. |
| 3 | 130 | `IntegrationTableMappingOnAfterModifyEvent` | Table "Integration Table Mapping" → `OnAfterModifyEvent` | var Rec; RunTrigger | **Table ID = Service Item** (SVCITEM-CUSTASSET) → Error if table filter does not include "Service Item Components" (unless filter on SystemId) (SUB:144-151). | FS enabled (137), RunTrigger (139), not temporary (141). |
| 4 | 154 | `OnBeforeTransferRecordFields` | CU "Integration Rec. Synch. Invoke" → `OnBeforeTransferRecordFields` (IRSI:753, raised IRSI:509/530) | SourceRecordRef; var DestinationRecordRef | (a) `FS Work Order Product-Job Journal Line`, `FS Work Order Service-Job Journal Line` → resolve ProjectTask → coupled Job Task; set Job No./Job Task No. on JJL; Error if not coupled / coupled to deleted (SUB:179-201). (b) `FS Work Order Incident-Service Item Line` → if new: Document Type Order, Document No. from coupled Service Header, Line No. via GetNextLineNo; description from incident type or "Service Order Incident" when no customer asset (SUB:202-224). (c) `FS Work Order Product-Service Line` / (d) `FS Work Order Service-Service Line` → if new: doc type/no., Line No., Type=Item; Service Item Line No./Service Item No. copied from an **uninitialised** local ServiceItemLine (=0/'') (SUB:225-264). (e) `FS Bookable Resource Booking-Service Line` → if new: doc type/no., Line No., Type=Resource (SUB:265-282). | FS enabled (173). (b)-(e) skip when destination Document No. <> '' (=existing line). |
| 5 | 286 | `OnAfterTransferRecordFields` | CU "Integration Rec. Synch. Invoke" → `OnAfterTransferRecordFields` (IRSI:758) | SourceRecordRef; var DestinationRecordRef; var AdditionalFieldsWereModified (omits `DestinationIsInserted`) | `FS Work Order Product-Service Line` / `Service Line-FS Work Order Product` / `FS Work Order Service-Service Line` / `Service Line-FS Work Order Service` → `UpdateQuantities(..., ToFieldService)` (qty/estimate/qty to ship/invoice/consume) and AdditionalFieldsWereModified := true (SUB:302-346). `FS Bookable Resource Booking-Service Line` → `UpdateQuantities(Booking, ServiceLine)` (Duration/60 → Quantity, Qty. to Consume) (SUB:348-357). | FS enabled (296). |
| 6 | 361 | `OnTransferFieldData` | CU "Integration Record Synch." → `OnTransferFieldData` (IntegrationRecordSynch.Codeunit.al:601) | SourceFieldRef; DestinationFieldRef; var NewValue; var IsValueFound; var NeedsConversion | Branches by **field-ref table numbers + field names**: Service Header→FS Work Order `SystemStatus` = keep destination (no outbound status update) (395-406); FS Work Order→Service Header `Status` mapping Unscheduled/Scheduled→Pending, InProgress→In Process, Completed→Finished (407-430); Service Line→FS WO Service `DurationShipped/Invoiced/Consumed` = hours*60 (432-465); FS Work Order `CreatedOn` → Date (467-477); FS WO Service `EstimateDuration` → hours; `Duration`/`DurationToBill` → hours minus already consumed/invoiced (only when dest = Job Journal Line), DurationToBill=0 for Budget/blank line types (479-518); FS WO Service `Description` → JJL: Booking name for Resource lines, Service name for Item lines (519-545); FS WO Product `Quantity`/`QtyToBill` minus consumed/invoiced (when dest JJL) (550-568), `Description` → Name (569-578), `Unit` → coupled Item Unit of Measure code (579-594). | FS enabled (385), `IsValueFound` (388), same-field/same-table skip (391-393). |
| 7 | 675 | `OnFindNewValueForCoupledRecordPK` | CU "CRM Int. Table. Subscriber" → `OnFindNewValueForCoupledRecordPK` (CRMSUB:3280, raised CRMSUB:3154 inside FindNewValueForCoupledRecordPK, itself only reached via CRM's OnTransferFieldData when `AreFieldsRelatedToMappedTables`) | IntegrationTableMapping; SourceFieldRef; DestinationFieldRef; var NewValue; var IsValueFound | FS WO Product→Service Line: `WorkOrderIncident` → coupled Service Item Line's Line No.; `Unit` → Item UoM code (695-724). FS WO Service→Service Line: same (725-754). Service Line→FS WO Product / FS WO Service: `Service Item Line No.` → coupled Work Order Incident id (756-780). Service Line→(WOP or WOS): `Service Item Line No.` again using **uninitialised** FSWorkOrderProduct (dead/buggy, 782-793); `Unit of Measure Code` → CRM Uom id (794-811). | FS enabled (692). Does not check IsValueFound on entry. Does not use IntegrationTableMapping. |
| 8 | 815 | `HandleOnAfterInsertRecord` | CU "Integration Rec. Synch. Invoke" → `OnAfterInsertRecord` (IRSI:783, raised IRSI:244) | SourceRecordRef; DestinationRecordRef | `FS Work Order Product-Job Journal Line` → ConditionallyPostJobJournalLine (836-841). `FS Work Order Service-Job Journal Line` → couple the extra Budget JJL (Line No. − 37) created in OnBeforeInsert via `CRMIntegrationRecord.InsertRecord` + **Commit()**, then ConditionallyPostJobJournalLine (842-857). `Sales Invoice Header-CRM Invoice` → for each Job Planning Line Invoice of the posted invoice, via Job Usage Link External Id, add QuantityInvoiced to FS WOP / DurationInvoiced (min) to FS WOS, Modify (failures logged `0000MMV`/`0000MMW`) (858-887). `FS Work Order-Service Header` → ValidateServiceHeaderAfterInsert + 4× ResetServiceOrder*From FS* (888-895). `Service Header-FS Work Order` → 3× ResetFS*FromServiceOrder* (896-901). | FS enabled (830). |
| 9 | 913 | `HandleOnBeforeIgnoreUnchangedRecordHandled` | CU "Integration Rec. Synch. Invoke" → `OnBeforeIgnoreUnchangedRecordHandled` (IRSI:828, raised IRSI:154) | SourceRecordRef; DestinationRecordRef (omits mapping) | `FS Work Order Product-Job Journal Line` → ConditionallyPost (930-935). `FS Work Order Service-Job Journal Line` → UpdateCorrelatedJobJournalLine + ConditionallyPost (936-942). `FS Work Order-Service Header` → 4× ResetServiceOrder* (943-949). `Service Header-FS Work Order` → ProofAllServiceItemLinesAssigned(**uninitialised ServiceHeader** – no-op, 952) + 3× ResetFS* (950-956). | FS enabled (924). |
| 10 | 971 | `HandleOnAfterUnchangedRecordHandled` | CU "Integration Rec. Synch. Invoke" → `OnAfterUnchangedRecordHandled` (IRSI:788, raised IRSI:210) | SourceRecordRef; DestinationRecordRef | `FS Work Order-Service Header` → 4× ResetServiceOrder* (984-990); `Service Header-FS Work Order` → 3× ResetFS* (991-996). | FS enabled (978). |
| 11 | 1373 | `HandleOnBeforeModifyRecord` | CU "Integration Rec. Synch. Invoke" → `OnBeforeModifyRecord` (IRSI:763, raised IRSI:259) | IntegrationTableMapping; SourceRecordRef; var DestinationRecordRef | `FS Work Order Service-Job Journal Line` → UpdateCorrelatedJobJournalLine (1386-1387). `Service Header-FS Work Order` → ProofAllServiceItemLinesAssigned (TestField on lines with Service Item Line No. 0) + SetCompanyId (1388-1393). | FS enabled (1380). |
| 12 | 1397 | `HandleOnUpdateIntegrationRecordCoupling` | CU "Integration Rec. Synch. Invoke" → `OnUpdateIntegrationRecordCoupling` (IRSI:813, raised IRSI:598) | IntegrationTableMapping; SourceRecordRef; var DestinationRecordRef (omits IsHandled, ConnectionType) | `Service Header-FS Work Order` → ProofAllServiceItemLinesAssigned + SetCompanyId (1410-1415). | FS enabled (1404). Never sets IsHandled. |
| 13 | 1420 | `AfterValidateLocationMandatory` | Table "Inventory Setup" → `OnAfterValidateEvent` field 'Location Mandatory' | var Rec; var xRec; CurrFieldNo | When Location Mandatory turned on: create LOCATION mapping if missing (`ResetLocationMapping(...,'LOCATION',true,true)`), and if PJLINE-WORDERPRODUCT lacks a "Location Code" field mapping → `SetLocationFieldMapping(true)` + `ResetProjectJournalLineWOProductMapping` (SUB:1435-1443). Mapping names hard-coded. | `Rec."Location Mandatory"` (1429), FS enabled (1432). |
| 14 | 1446 | `AddFieldServiceProductTypeFieldMapping` | CU "CRM Setup Defaults" → `OnResetItemProductMappingOnAfterInsertFieldsMapping` (CRMSetupDefaults.Codeunit.al:2733) | var Sender: "CRM Setup Defaults"; IntegrationTableMappingName | **Item ↔ CRM Product** (base ITEM-PRODUCT) → adds field mapping Item.Type → CRM Product.FieldServiceProductType, ToIntegrationTable (1458-1463). | FS enabled (1454). |
| 15 | 1526 | `HandleOnAfterModifyRecord` | CU "Integration Rec. Synch. Invoke" → `OnAfterModifyRecord` (IRSI:768, raised IRSI:264) | IntegrationTableMapping; var SourceRecordRef; var DestinationRecordRef | `FS Work Order Product-Job Journal Line` / `FS Work Order Service-Job Journal Line` → ConditionallyPostJobJournalLine (1542-1553). `FS Work Order-Service Header` → 4× ResetServiceOrder* (1554-1560). `Service Header-FS Work Order` → 3× ResetFS* (1561-1566). | FS enabled (1536). |
| 16 | 1629 | `HandleOnBeforeInsertRecord` | CU "Integration Rec. Synch. Invoke" → `OnBeforeInsertRecord` (IRSI:778, raised IRSI:234) | SourceRecordRef; DestinationRecordRef (**both by value**, omits mapping & `InsertWithSystemId`) | `Location-FS Warehouse` → SetCompanyId (1665-1666). `Service Item-FS Customer Asset` → SetCompanyId (1667-1668). `FS Customer Asset-Service Item` → SetCompanyId on **source** + `SourceRecordRef.Modify()` (writes to Dataverse during inbound, 1669-1673). `Resource-FS Bookable Resource` → SetCompanyId; TimeZone := 92; ResourceType from Resource.Type/Vendor No./Time Sheet Owner; UserId from User Setup e-mail → CRM Systemuser (1674-1694). `FS Bookable Resource-Resource` → SetCompanyId on source; Resource.Type from ResourceType; Base UoM := FS setup Hour UoM; Time Sheet Owner from CRM user e-mail; `SourceRecordRef.Modify()` (1695-1712). `Job Task-FS Project Task` → SetCompanyId; ProjectDescription; BillingAccountId/ServiceAccountId from Job bill-to/sell-to customers (must be coupled, else Error) (1713-1734). `FS Work Order Product-Job Journal Line` / `FS Work Order Service-Job Journal Line` → raise `OnSetUpNewLineOnNewLine`; if not Handled: template/batch from FS setup, Line No., document no./posting date (CheckPostingRuleAndSetDocumentNo), source/reason code, price/cost calc method, SetJobJournalLineTypesAndNo (which may **insert an extra Budget JJL** for the booked resource) (1735-1761). `FS Bookable Resource Booking-Service Line` → GenerateServiceItemLineForBooking (inserts a "FS Bookings" Service Item Line if none) (1762-1767). `Service Order Type-FS Work Order Type` → SetCompanyId (1768-1769). `Service Header-FS Work Order` → ProofAllServiceItemLinesAssigned + SetCompanyId (1770-1775). `Service Item Line-FS Work Order Incident` → SetCompanyId; WorkOrder from coupled Service Header; IncidentType := default incident (1776-1786). `Service Line-FS Work Order Product` / `Service Line-FS Work Order Service` → SetCompanyId; WorkOrder from coupled header (1787-1806). | FS enabled (1659). |
| 17 | 2015 | `OnSynchNAVTableToCRMOnBeforeCheckLatestModifiedOn` | CU "CRM Integration Table Synch." → `OnSynchNAVTableToCRMOnBeforeCheckLatestModifiedOn` (CRMITS:951, raised CRMITS:577 while `Int. Table Manual Subscribers` is bound) | var SourceRecordRef; IntegrationTableMapping | **SourceRecordRef = Service Header** (SRVORDER outbound) → collects Service Item Lines / Service Lines modified in the same SystemModifiedAt window whose header was not in this run, and re-enters `CRMIntegrationTableSynch.SynchRecordsToIntegrationTable` for each such Service Order (2028-2067). | Only `SourceRecordRef.Number = Service Header` (2028). **No FS-enabled guard**, mapping not checked. |
| 18 | 2070 | `HandleOnDeletionConflictDetectedSetRecordStateAndSynchAction` | CU "Integration Rec. Synch. Invoke" → `OnDeletionConflictDetectedSetRecordStateAndSynchAction` (IRSI:748, raised IRSI:357) | var IntegrationTableMapping; var SourceRecordRef; var CoupledRecordRef; var RecordState; var SynchAction; var DeletionConflictHandled | Mapping **Table ID = Job Journal Line and Integration Table ID ∈ {FS WO Service, FS WO Product}** (coupled JJL was posted & deleted): if FS qty/qty-to-bill == already consumed/invoiced on Job Planning Lines → Skip; else `PrepareNewDestination` + SynchAction Insert, and delete broken couplings (2091-2144). | `DeletionConflictHandled` (2085), FS enabled (2088), mapping table IDs (2091-2095). Only subscriber that uses the mapping record for dispatch. |
| 19 | 2209 | `HandleOnAfterApplyUsage` | CU "Job Link Usage" → `OnAfterApplyUsage` | var JobLedgerEntry; var JobJournalLine | Project posting flow: sets Job Planning Line "Qty. to Transfer to Invoice" from JJL; stores coupled CRM ID in Job Usage Link "External Id"; buffers consumption delta into SingleInstance temp tables TempFSWorkOrderProduct.QuantityConsumed / TempFSWorkOrderService.DurationConsumed (only Budget line when booking resource coupled) (2228-2276). | FS setup ReadPermission (2220), FS enabled (2225), CRM Integration Record ReadPermission (2248), coupling exists (2252). Runs on **every** project usage posting, not only sync-originated. |
| 20 | 2279 | `HandleOnAfterPostJnlLines` | CU "Job Jnl.-Post Batch" → `OnAfterPostJnlLines` | var JobJournalBatch; var JobJournalLine; JobRegNo; var SuppressCommit | Flush the temp buffers: add QuantityConsumed / DurationConsumed to FS WOP / WOS in Dataverse (Modify failures logged `0000MMZ`/`0000MN0`), then clear (2303-2326). | FS enabled (2286); if SuppressCommit → discard buffers (2289-2293); WritePermission on FS tables (2298-2301). Note: sync-path posting uses `Job Jnl.-Post Line` directly (SUB:1577 etc.), which does **not** raise this event – buffers then stay in the SingleInstance temp tables until a later batch post. |
| 21 | 2458 | `HandleOnHasCompanyIdField` | CU "CDS Integration Mgt." → `OnHasCompanyIdField` (CDSIntegrationMgt.Codeunit.al:446) | TableId; var HasField | FS Work Order, FS Bookable Resource, FS Customer Asset, FS WO Product, FS WO Service, FS Resource Pay Type, FS Project Task, FS Warehouse → HasField := true (2466-2476). Not included: FS Work Order Type, FS Work Order Incident, FS Bookable Resource Booking. | FS enabled (2463). |
| 22 | 2479 | `HandleOnBeforeUncoupleRecord` | CU "Int. Rec. Uncouple Invoke" → `OnBeforeUncoupleRecord` (IntRecUncoupleInvoke.Codeunit.al:205) | IntegrationTableMapping; var LocalRecordRef; var IntegrationRecordRef | Any table with company id field → `CDSIntegrationMgt.ResetCompanyId(IntegrationRecordRef)` (2488-2495). **Duplicate** of CDSSUB:735-747 (same logic). | FS enabled (2485), HasField (2489), record not empty (2492). |
| 23 | 2498 | `OnQueryPostFilterIgnoreRecord` | CU "CRM Integration Table Synch." → `OnQueryPostFilterIgnoreRecord` (CRMITS:936) | SourceRecordRef; var IgnoreRecord | Dispatch on **SourceRecordRef.Number only**: FS WO Product / FS WO Service → IgnorePostedJobJournalLines… (project mode, Line Synch Rule = LineUsed: ignore if IntegrateToService or quantities already consumed/invoiced) then IgnoreArchivedWorkOrderLines… (2510-2516). Service Header → ignore archived (2517-2518). FS Work Order → ignore if no incidents or archived (2519-2520). Service Item → ignore uncoupled service items whose item's CRM Product has ConvertToCustomerAsset = false (2521-2522). Then **`if FSConnectionSetup.IsEnabled() then exit;`** (2525) – so FS Bookable Resource type filter (Contact/Crew/Facility/Pool ignored, 2529-2533) and Job Task filter (job missing/blocked/not Open/no Apply Usage Link, 2534-2553) **run only when FS is disabled** (appears inverted). | `IgnoreRecord` (2506); helpers each guard FS enabled (2614, 2635, 2662, 2696) / project enabled (2569). |
| 24 | 2722 | `LogTelemetryOnAfterInitSynchJob` | CU "Integration Table Synch." → `OnAfterInitSynchJob` | ConnectionType; IntegrationTableID | FS tables list (Project Task, WOP, WOS, WO Incident, Customer Asset, Bookable Resource, Booking, Incident Type, Resource Pay Type, Warehouse) → telemetry `0000M9F/M9E/M9D` (2743-2758). Note FS Work Order / Work Order Type not in list. | ConnectionType = CRM (2732), FS enabled (2735). Subscriber flags `true, true`. |
| 25 | 2783 | `ServiceMgtSetupOnBeforeValidateOneServiceItemLinePerOrder` | Table "Service Mgt. Setup" → `OnBeforeValidateEvent` 'One Service Item Line/Order' | var Rec | Delegates to `FSIntegrationMgt.TestOneServiceItemLinePerOrderModificationIsAllowed` (2788). | none in subscriber. |
| 26 | 2791 | `HandleOnIsCRMIntegrationRecord` | CU "CRM Integration Management" → `OnIsCRMIntegrationRecord` (CRMIM:4197) | TableID; var isIntegrationRecord | Service Header Archive → true (2794-2795). | **No FS-enabled guard**. |
| 27 | 2798 | `HandleOnAfterDeleteServiceHeader` | Table "Service Header" → `OnAfterDeleteEvent` | var Rec | MarkArchivedServiceOrder: CRM Integration Record of the header gets "Archived Service Header Id" (latest archive) + "Archived Service Order" := true (2875-2890). | not temporary (2801); helper: Service integration type enabled (2880). |
| 28 | 2807 | `OnAfterStoreServiceLineArchive` | CU "Service Document Archive Mgmt." → `OnAfterStoreServiceLineArchive` | var ServiceLine; var ServiceLineArchive | MarkArchivedServiceOrderLine: coupling of Service Line gets "Archived Service Line Id" (2892-2906). | helper: Service type enabled (2897). |
| 29 | 2813 | `HandleOnAfterDeleteServiceItemLine` | Table "Service Item Line" → `OnAfterDeleteEvent` | var Rec | UncoupleRecord(ServiceItemLine): coupling marked Skipped + "Skip Reimport", synch results = Success (2831-2851). | not temporary (2816); Service type enabled (2836). |
| 30 | 2822 | `HandleOnAfterDeleteServiceLine` | Table "Service Line" → `OnAfterDeleteEvent` | var Rec | UncoupleRecord(ServiceLine) – same as #29 (2853-2873). | not temporary (2825); Service type enabled (2858). |
| 31 | 2921 | `OnBeforeOpenCoupledNavRecordPage` | CU "CRM Integration Management" → `OnBeforeOpenCoupledNavRecordPage` (CRMIM:4222) | CRMID; CRMEntityTypeName; var Result; var IsHandled | Entity `msdyn_workorder` whose Service Header no longer exists but archive does → open "Service Order Archive" (2924-2931, 2951-2984). | IsHandled/Result/entity name (2924). No FS-enabled guard. |
| 32 | 2934 | `OnBeforeOpenRecordCardPage` | CU "CRM Integration Management" → `OnBeforeOpenRecordCardPage` (CRMIM:266) | RecordID; var IsHandled | Service Header → `Page.Run("Service Order")`, IsHandled := true (2941-2948). | **No IsHandled-on-entry check, no FS-enabled guard**. |
| 33 | 2991 | `HandleOnBeforeFindCoupledToCRMField` | CU "CRM Integration Management" → `OnBeforeFindCoupledToCRMField` (CRMIM:4227) | TableNo; var IsHandled; var CoupledFieldNo | Service Item → "Coupled to FS" field (2999-3003). | IsHandled (2996). No FS-enabled guard. |

Subscriber attribute flags: #4-#12, #15-#18, #23 (record-level engine events) use `SkipOnMissingLicense = true` (`'', true, false`); CRM/CDS base subscribers use `false, false`.

### 1b. FS Setup Defaults (4 subscribers)

| # | Line | Subscriber proc | Publisher → event | Params | Branches → summary | Guards |
|---|---|---|---|---|---|---|
| D1 | DEF:1142 | `ReturnProxyTableNoOnGetCDSTableNo` | CU "CRM Setup Defaults" → `OnGetCDSTableNo` (CRMSetupDefaults.Codeunit.al:2618) | BCTableNo; var CDSTableNo; var Handled | Resource→FS Bookable Resource; Service Order Type→FS Work Order Type; Service Header→FS Work Order; Service Item→FS Customer Asset; Job Task→FS Project Task; Location→FS Warehouse; Handled if found (DEF:1153-1169). No entry for Job Journal Line / Service Item Line / Service Line. | Handled (1147), FS enabled (1150). |
| D2 | DEF:1172 | `AddProxyTablesOnAddEntityTableMapping` | CU "CRM Setup Defaults" → `OnAddEntityTableMapping` (CRMSetupDefaults.Codeunit.al:2623) | var TempNameValueBuffer | Adds entity names: bookableresource (Resource, FS Bookable Resource), msdyn_customerasset (Service Item, FS Customer Asset), bcbi_projecttask (Job Task, FS Project Task), msdyn_workorderproduct (JJL, FS WOP), msdyn_workorderservice (JJL, FS WOS), msdyn_warehouse (Location, FS Warehouse), msdyn_workordertype (Service Order Type, FS WO Type), msdyn_workorder (Service Header, FS Work Order) (1181-1203). **Deletes** the base 'product'↔Resource entry (1205-1209) – order-dependent on other subscribers. | FS enabled (1178). |
| D3 | DEF:1212 | `ReturnNameFieldNoOnBeforeGetNameFieldNo` | CU "CRM Setup Defaults" → `OnBeforeGetNameFieldNo` (CRMSetupDefaults.Codeunit.al:2713) | TableId; var FieldNo | Name field per table: Service Order Type.Code, Service Header."No.", Service Item."No.", FS Customer Asset.Name, FS Bookable Resource.Name, FS WO Type.Code, FS Work Order.Name, FS WOP.Name, FS WOS.Name, FS Project Task.ProjectNumber, Job Task."Job Task No.", JJL.Description, FS Warehouse.Name, Location.Code (1234-1263). | FS enabled (1231). |
| D4 | DEF:1299 | `OnBeforeHandleCustomIntegrationTableMapping` | CU "CRM Integration Management" → `OnBeforeHandleCustomIntegrationTableMapping` (CRMIM:4187, raised CRMIM:2340 in the `else` of the "reset to default" case) | var IsHandled; IntegrationTableMappingName (omits mapping, EnqueueJobQueEntries) | Table ID Resource+FS Bookable Resource → ResetResourceBookableResourceMapping (1312-1314, **unreachable**: base handles `Database::Resource` before the else, CRMIM:2316-2318); Job Task+FS Project Task → ResetProjectTaskMapping; Service Item+FS Customer Asset → ResetServiceItemCustomerAssetMapping; JJL+FS WOP / JJL+FS WOS → ResetProjectJournalLineWO*Mapping; Location+FS Warehouse → ResetLocationMapping (1315-1330). Service Order Type / Service Header / Service Item Line / Service Line mappings **not handled**. **Never sets IsHandled** → base then prompts "reset all custom mappings" and runs CDS/CRM SetCustomIntegrationsTableMappings (CRMIM:2341-2348). | FS enabled (1305), mapping exists (1308). |

### 1c. Other [EventSubscriber]s in the FS app

| File:line | Proc | Publisher → event | Purpose |
|---|---|---|---|
| `FSAssistedSetupSubscriber.Codeunit.al:20` | RegisterFSAssistedSetup | CU "Guided Experience" → `OnRegisterAssistedSetup` | Register the FS setup wizard. |
| `FSDataClassification.Codeunit.al:12` | OnClassifyTables | CU "Data Classification Eval. Data" → `OnCreateEvaluationDataOnAfterClassifyTablesToNormal` | Data classification of FS tables. |
| `FSEnvironmentCleanupSubs.Codeunit.al:13` | ClearFSConnectionOnEnvironmentCopy | CU "Environment Cleanup" → `OnClearCompanyConfig` | Disable/clear FS connection on environment copy. |
| `FSInstall.Codeunit.al:120` | RegisterPerCompanyTags | CU "Upgrade Tag" → `OnGetPerCompanyUpgradeTags` | Upgrade tags. |
| `FSUpgrade.Codeunit.al:37` | RegisterPerCompanyTags | CU "Upgrade Tag" → `OnGetPerCompanyUpgradeTags` | Upgrade tags. |
| `FSIntegrationMgt.Codeunit.al:393` | RegisterFSConnectionOnRegisterServiceConnection | Table "Service Connection" → `OnRegisterServiceConnection` | Show FS connection in Service Connections (status via TestConnection). |
| `FSLookupFSTables.Codeunit.al:11` | HandleOnLookupCRMTables | CU "Lookup CRM Tables" → `OnLookupCRMTables` | Lookup pages for FS Bookable Resource, FS Customer Asset, FS Work Order, FS Work Order Type (coupling UI). Guard Handled + FS enabled. No lookup for FS Project Task, WOP, WOS, Warehouse, Incident, Booking. |

---

## 2. Per-branch helpers and extensibility

Helper visibility: in SUB everything is `local` except `GetMaxQuantity` (648, 660) and `SynchRecordsToIntegrationTable` (1329) which are public, and `UpdateQuantities` (598/619/640), `ArchiveServiceOrder` (1357), `Ignore*OnQueryPostFilterIgnoreRecord` (2557/2608/2628/2654/2688), `MarkArchivedServiceOrder*` (2875/2892) which are `internal` (only visible to the test library per app.json). In DEF the Reset*Mapping procedures are `internal` (Projects/Resource/ServiceItem/Location) or `local` (all service-order ones, 491-1032).

| Pair / branch | Helpers (SUB line) | Own IntegrationEvent / IsHandled? | Extensible today? |
|---|---|---|---|
| FS WOP/WOS → Job Journal Line: OnBeforeTransfer (Job/Job Task) | inline 179-201 | none | No |
| FS WOP/WOS → JJL: OnBeforeInsert (new line setup) | `CheckPostingRuleAndSetDocumentNo` 1852, `SetPostingDocumentNo` 1886, `SetDocumentNo` 1904, `SetJobJournalLineTypesAndNo` 2329, `SetCurrentProjectPlanningQuantities` 2147, `BudgetJobJournalLineNoOffset` 905 | **`OnSetUpNewLineOnNewLine(var JobJournalLine; var JobJournalTemplate; var JobJournalBatch; var Handled)`** SUB:2986, raised SUB:1739 | **Partially** – all-or-nothing: Handled=true skips template/batch, document no., *and* item/resource/qty logic incl. budget-line creation (1740-1759). No events inside the helpers. |
| FS WOP/WOS → JJL: field transforms (qty minus consumed, description, unit) | OnTransferFieldData 479-595 + `SetCurrentProjectPlanningQuantities` 2147 | none | No (only by racing another OnTransferFieldData subscriber that sets IsValueFound first – order not guaranteed) |
| FS WOP/WOS → JJL: after insert/modify/unchanged (auto-post) | `ConditionallyPostJobJournalLine` 1570 / 1590, `PostJobJournalLine` 1604, `UpdateCorrelatedJobJournalLine` 1466; budget-line coupling + Commit 846-855 | none | No |
| FS WOP/WOS → JJL: deletion conflict | inline 2097-2144, `SetCurrentProjectPlanningQuantities`, base `IntegrationRecSynchInvoke.PrepareNewDestination` | none (subscriber honours `DeletionConflictHandled` so an earlier subscriber can pre-empt, order not guaranteed) | Only by pre-empting |
| Project posting write-back (Job Link Usage / Job Jnl.-Post Batch) | 2209-2327, SingleInstance temp buffers | none | No |
| Sales Invoice Header → CRM Invoice (invoiced qty write-back to WOP/WOS) | inline 858-887 | none | No |
| Job Task → FS Project Task | inline 1713-1734, `SetCompanyId` 2768; QueryPostFilter Job Task branch 2534-2553 | none | No |
| Resource ↔ FS Bookable Resource | inline 1674-1712, `ReturnCRMUserGuidForResource` 1836, `SetUserIDFromFSBookableResource` 1810 | none | No |
| Service Item ↔ FS Customer Asset | `SetCompanyId` 2768, `IgnoreServiceItemsByConvertToCustomerAssetFlag` 2688, filter enforcement SUB:130-152, `HandleOnBeforeFindCoupledToCRMField` 2991 | none | No |
| Location → FS Warehouse | `SetCompanyId` only (1665-1666); Inventory Setup subscriber 1420-1444 | none | No |
| Service Order Type → FS Work Order Type | `SetCompanyId` only (1768-1769) | none | No |
| Service Header ↔ FS Work Order (header + cascade) | `ValidateServiceHeaderAfterInsert` 1000, `ResetServiceOrderItemLineFromFSWorkOrderIncident` 1010, `ResetServiceOrderLineFromFSWorkOrderProduct` 1078, `ResetServiceOrderLineFromFSWorkOrderService` 1135, `ResetServiceOrderLineFromFSBookableResourceBooking` 1192, `SkipReimport` 1250, `ArchiveServiceOrder` 1357, `DeleteServiceLines` 1067, `DeleteServiceItemLineForBooking` 1948, `ResetFSWorkOrderIncidentFromServiceOrderItemLine` 1267, `ResetFSWorkOrderProductFromServiceOrderLine` 1287, `ResetFSWorkOrderServiceFromServiceOrderLine` 1308, `SynchRecordsToIntegrationTable` 1329, `ProofAllServiceItemLinesAssigned` 960, `SetCompanyId` 2768; status mapping in OnTransferFieldData 395-430; change detection via OnSynchNAVTableToCRMOnBeforeCheckLatestModifiedOn 2015-2068 | none | No |
| Service Item Line ↔ FS Work Order Incident | inline 202-224, 1776-1786; `GetNextLineNo` 1977 | none | No |
| Service Line ↔ FS WOP / FS WOS | inline 225-264, 1787-1806; `UpdateQuantities` 598/619; `GetMaxQuantity`; OnFindNewValueForCoupledRecordPK 695-811; `GetServiceOrderItemLineRecordId` 2007, `GetServiceOrderRecordId` 1999 | none | No |
| Service Line ← FS Bookable Resource Booking | inline 265-282, 348-357; `UpdateQuantities` 640; `GenerateServiceItemLineForBooking` 1931, `GetServiceItemLine` 1969 | none | No |
| Archive / delete tracking | `MarkArchivedServiceOrder` 2875, `MarkArchivedServiceOrderLine` 2892, `UncoupleRecord` 2831/2853, `OnlyServiceHeaderArchiveExists` 2951, `OpenServiceHeaderArchive` 2969 | none | No |

### All IntegrationEvent / BusinessEvent publishers declared by the FS app (no BusinessEvent / InternalEvent exists)

| File:line | Event (signature) | Raised at |
|---|---|---|
| SUB:2986 | `OnSetUpNewLineOnNewLine(var JobJournalLine: Record "Job Journal Line"; var JobJournalTemplate: Record "Job Journal Template"; var JobJournalBatch: Record "Job Journal Batch"; var Handled: Boolean)` | SUB:1739 |
| `FSIntegrationMgt.Codeunit.al:423` | `OnGetBookingStatusCompletedOnSetFilterForFSBookingStatus(var FSBookingStatus: Record "FS Booking Status")` | inside FSIntegrationMgt.GetBookingStatusCompleted (used by DEF:986, SUB:1233) |
| `FSConnectionSetup.Table.al:885` | `OnGetDefaultFSConnection(var ConnectionName: Text)` | `FSConnectionSetup.Table.al:881` |
| DEF:1334 | `OnAfterResetConfiguration(FSConnectionSetup)` | DEF:1296 (via SetCustomIntegrationsTableMappings, DEF:78) |
| DEF:1339 | `OnAfterResetProjectJournalLineWOProductMapping(IntegrationTableMappingName)` | DEF:218 |
| DEF:1344 | `OnAfterResetProjectJournalLineWOServiceMapping(IntegrationTableMappingName)` | DEF:298 |
| DEF:1349 | `OnAfterResetServiceItemCustomerAssetMapping(IntegrationTableMappingName)` | DEF:432 |
| DEF:1354 | `OnAfterResetResourceBookableResourceMapping(var IntegrationTableMappingName)` | DEF:363 |
| DEF:1359 | `OnBeforeResetConfiguration(var FSConnectionSetup; var IsHandled)` | DEF:46 |
| DEF:1364 | `OnBeforeResetProjectJournalLineWOProductMapping(var Name; var ShouldRecreateJobQueueEntry; var IsHandled)` | DEF:146 |
| DEF:1369 | `OnBeforeResetProjectJournalLineWOServiceMapping(var Name; var ShouldRecreateJobQueueEntry; var IsHandled)` | DEF:235 |
| DEF:1374 | `OnBeforeResetServiceItemCustomerAssetMapping(var Name; var ShouldRecreate; var IsHandled)` | DEF:385 |
| DEF:1379 | `OnBeforeResetProjectTaskMapping(var Name; var ShouldRecreate; var IsHandled)` | DEF:90 |
| DEF:1384 | `OnBeforeResetResourceBookableResourceMapping(var Name; var ShouldRecreate; var IsHandled)` | DEF:315 |
| DEF:1389 | `OnBeforeResetServiceOrderTypeMapping(Name; ShouldRecreate; var IsHandled)` | DEF:502 |
| DEF:1394 | `OnBeforeResetServiceOrderMapping(Name; ShouldRecreate; var IsHandled)` | DEF:564 |
| DEF:1399 | `OnBeforeResetServiceOrderItemLineMapping(Name; ShouldRecreate; var IsHandled)` | DEF:670 |
| DEF:1404 | `OnBeforeResetServiceOrderLineItemMapping(Name; ShouldRecreate; var IsHandled)` | DEF:735 **and DEF:865** (copy-paste: SRVORDERLINE-SERVICE reset raises the *LineItem* event; no `OnBeforeResetServiceOrderLineServiceItemMapping` exists) |
| DEF:1409 | `OnBeforeResetServiceOrderLineResourceMapping(Name; ShouldRecreate; var IsHandled)` | DEF:973 |
| DEF:1414 | `OnCreateJobQueueEntryOnBeforeJobQueueEnqueue(var JobQueueEntry; var IntegrationTableMapping; JobCodeunitId; JobDescription)` | DEF:1100 (only the one-off CreateJobQueueEntry, not the recurring RecreateJobQueueEntryFromIntTableMapping) |
| DEF:1419 | `OnResetServiceOrderTypeMappingOnAfterInsertFieldsMapping(Name)` | DEF:546 |
| DEF:1424 | `OnResetServiceOrderMappingOnAfterInsertFieldsMapping(Name)` | DEF:653 |
| DEF:1429 | `OnResetServiceOrderItemLineMappingOnAfterInsertFieldsMapping(Name)` | DEF:719 |
| DEF:1434 | `OnResetServiceOrderLineItemMappingOnAfterInsertFieldsMapping(Name)` | DEF:850 |
| DEF:1439 | `OnResetServiceOrderLineServiceItemMappingOnAfterInsertFieldsMapping(Name)` | DEF:957 |
| DEF:1444 | `OnResetServiceOrderLineResourceMappingOnAfterInsertFieldsMapping(Name)` | DEF:1031 |
| DEF:1449 | `OnResetLocationMappingOnAfterInsertFieldMapping(Name)` | DEF:486 |

Observation: all 25 DEF events are about **mapping setup**; the only runtime-sync event is `OnSetUpNewLineOnNewLine`. No events for: ProjectTask after-reset (no `OnAfterResetProjectTaskMapping`), Location before-reset (no IsHandled in ResetLocationMapping 437-489).

---

## 3. Overlaps with base CRM / CDS subscribers on the same events

| Event | Base subscribers | Overlap / disambiguation |
|---|---|---|
| OnBeforeTransferRecordFields | CRMSUB:247 (Sales Invoice/Sales Line/Salesorder codes) | Disjoint codes. CRM has no FS guard and no FS check; FS uses SourceDest code. |
| OnAfterTransferRecordFields | CRMSUB:446 (has its own IsHandled event `OnBeforeGetSourceDestCodeOnAfterTransferRecordFields`, CRMSUB:451) | Disjoint codes (CRM includes `Resource-CRM Product`, FS uses `Resource-FS Bookable Resource` only in OnBeforeInsert). |
| OnTransferFieldData | CRMSUB:272, CDSSUB:261 | **Real overlap**: all three fire for every FS field. Each exits if `IsValueFound` (FS SUB:388, CRM, CDS). CRM's generic tail (option/table conversion, ShouldKeepOldValue, FindNewValueForSpecialMapping, `AreFieldsRelatedToMappedTables`→`FindNewValueForCoupledRecordPK`) is what resolves FS lookup fields (Customer No.↔ServiceAccount, Item No.↔Product, etc.); FS hooks into it via `OnFindNewValueForCoupledRecordPK` (CRMSUB:3154). FS duplicates WOP.Unit→UoM in both OnTransferFieldData (579-594) and OnFindNewValueForCoupledRecordPK (709-723). Result depends on subscriber order for fields both could claim. |
| OnFindNewValueForCoupledRecordPK | publisher CRMSUB:3280 | Only FS subscribes. FS ignores the `IntegrationTableMapping` param and `IsValueFound` on entry. |
| OnBeforeInsertRecord | CRMSUB:500, CDSSUB:452 | Disjoint codes. CDS dispatches by `SourceRecordRef.Number in [CRM Account, CRM Product]` (CDSSUB:472) – not FS tables. |
| OnAfterInsertRecord | CRMSUB:553, CDSSUB:131 | **Same pair `Sales Invoice Header-CRM Invoice`** handled by CRM (UpdateCRMInvoiceAfterInsertRecord etc., CRMSUB:570) **and** FS (SUB:858-887, invoiced qty write-back). FS adds behaviour to a CRM-owned mapping; only guard is FS enabled. |
| OnBeforeModifyRecord / OnAfterModifyRecord | CRMSUB:797/831, CDSSUB:508/531 | Disjoint codes. |
| OnBeforeIgnoreUnchangedRecordHandled | CRMSUB:886 (with IsHandled event `OnHandleOnBeforeIgnoreUnchangedRecordHandled`) | Disjoint. |
| OnAfterUnchangedRecordHandled | CRMSUB:861, CDSSUB:981 | Disjoint. |
| OnQueryPostFilterIgnoreRecord | CRMSUB:911, CDSSUB:1006, CRMITS:980 | Event carries **only SourceRecordRef** (CRMITS:936). CRM dispatches on `SourceRecordRef.Number` incl. **Resource** (`HandleResourceQueryPostFilterIgnoreRecord`, CRMSUB:1258 – ignores the Write-in Product resource) and Item → these also apply to FS's RESOURCE-BOOKABLERSC sync. FS cannot tell PJLINE-WORDERPRODUCT from SRVORDERLINE-ITEM (both source FS WOP) except via `FSWorkOrder.IntegrateToService` in project mode (SUB:2584-2602). |
| OnHasCompanyIdField | CDSSUB:719 | Disjoint table lists. |
| OnBeforeUncoupleRecord | CDSSUB:735 | **Duplicate logic**: CDS already does `OnHasCompanyIdField` → `ResetCompanyId` for every table (CDSSUB:735-747) – FS's SUB:2479-2496 resets company id a second time for FS tables. |
| OnAfterInitSynchJob | CRMSUB:1043, CDSSUB:1423 | Telemetry only, separate table lists. |
| OnIsCRMIntegrationRecord | CRMSUB:3203 (Sales Header Archive) | FS adds Service Header Archive. |
| OnGetCDSTableNo / OnAddEntityTableMapping | CDSSetupDefaults.Codeunit.al:1067 / :1103 | FS checks `Handled` on OnGetCDSTableNo; on OnAddEntityTableMapping FS removes base 'product'↔Resource row – order-dependent. |
| OnBeforeHandleCustomIntegrationTableMapping | base raises only for tables not in its case list (CRMIM:2288-2338) | FS Resource branch unreachable; FS never sets IsHandled. |

**Does FS re-check `SourceRecordRef.Number` for tables CRM also handles?** For record-level events FS uses the full Source-Dest name pair, so Resource (CRM Product vs FS Bookable Resource) and Item are disambiguated. Where only a table number is available it does **not** disambiguate: OnQueryPostFilterIgnoreRecord (CRM's Resource/Item handlers fire for FS syncs too); `OnEnableMultiCompanySynchronization` checks only `Table ID = Job Journal Line` (SUB:105); `IntegrationTableMappingOnAfterModifyEvent` checks only `Table ID = Service Item` (SUB:144); OnBeforeFindCoupledToCRMField / OnBeforeOpenRecordCardPage / OnSynchNAVTableToCRMOnBeforeCheckLatestModifiedOn check only the BC table number, without FS-enabled guard. The `Sales Invoice Header-CRM Invoice` branch is deliberately added to CRM's own mapping.

---

## 4. "Not extensible today" (hard-coded, no publisher, no IsHandled)

1. Auto-posting of synced project journal lines: `Job Jnl.-Post Line.RunWithCheck` + `Delete(true)` driven by "Line Post Rule" – SUB:1570-1588, 1590-1602, 1604-1627; called from SUB:840, 856, 934, 941, 1546, 1552.
2. Budget-line creation for booked resource on FS WOS (extra JJL at Line No. − 37, Budget type, Resource, Hour UoM, zero price) – SUB:2410-2438; magic offset SUB:905-911; coupling + explicit `Commit()` SUB:846-855.
3. Correlated budget/billable JJL quantity sync – SUB:1466-1524.
4. Qty-netting against Job Planning Lines (consumed/invoiced) – SUB:2147-2207, used at 497, 556, 1482, 2097, 2350, 2599. Only active for Integration Type = Projects (2162).
5. Item validation for FS WOS (must be non-Inventory, not blocked, base UoM = Hour UoM) – SUB:2386-2403; item price/cost policy (`Unit Cost`/`Unit Price` from Item) – SUB:2371-2376, 2446-2453.
6. Job journal Document No./Posting Date policy – SUB:1852-1929 (only overridable as a whole via `OnSetUpNewLineOnNewLine`).
7. Deletion-conflict policy for JJL (skip vs. restore) – SUB:2070-2145 (only pre-emptable).
8. Consumption write-back to FS WOP/WOS on project posting (SingleInstance buffer) – SUB:2209-2327.
9. Invoiced-quantity write-back on Sales Invoice → CRM Invoice insert – SUB:858-887.
10. Work order status mapping (FS SystemStatus → Service Header Status; BC→FS status suppressed) – SUB:395-430.
11. Duration unit conversions (minutes ↔ hours) – SUB:432-465, 479-518, 619-646, 2111-2113, 2383-2384.
12. Service order cascade: header insert/modify/unchanged triggers delete-missing + re-sync of incidents, products, services, bookings (incl. archiving before deletion) – SUB:1010-1248, 1267-1327, invoked at 890-901, 943-956, 984-996, 1554-1566.
13. Service Line / Service Item Line key assignment (Document No., Line No. = last+10000, Type) – SUB:202-282, 1977-1997.
14. Synthetic "FS Bookings" Service Item Line for resource bookings – SUB:1931-1975; delete rule SUB:1948-1967.
15. Quantity rules for service lines (estimate vs used, max(Quantity,QtyToBill), qty to ship/invoice/consume) – SUB:598-646.
16. Bookable resource defaults: TimeZone 92, ResourceType derivation, UserId via User Setup e-mail – SUB:1679-1692; inverse SUB:1700-1709, 1810-1850.
17. Project Task account derivation from Job bill-to/sell-to customers – SUB:1717-1733.
18. Work Order Incident defaults (WorkOrder, default IncidentType) – SUB:1782-1784.
19. QueryPostFilter rules (posted/archived lines, archived orders, work orders without incidents, Service Item ConvertToCustomerAsset, Bookable Resource types, Job Task status) – SUB:2498-2720 (and the inverted guard at 2525).
20. Delta detection of service orders via modified lines – SUB:2015-2068.
21. Delete/archive tracking on Service Header/Line/Item Line – SUB:2798-2919.
22. Company-id stamping per pair – SUB:1665-1806 via SetCompanyId 2768-2774; source-side Modify on inbound Customer Asset / Bookable Resource SUB:1671-1672, 1697, 1711.
23. Service Item mapping filter enforcement – SUB:130-152.
24. Multi-company filter for JJL mappings – SUB:85-128.
25. Location mapping auto-creation on Location Mandatory – SUB:1420-1444; `ResetLocationMapping` has no OnBefore/IsHandled – DEF:437-489.
26. Mapping registration list in ResetConfiguration (which mappings exist per Integration Type; enum "FS Integration Type" is `Extensible = true` but branching is hard-coded on its two values) – DEF:53-76; `FSIntegrationType.Enum.al:7-19`. Overridable only wholesale via `OnBeforeResetConfiguration`.
27. Default directions – DEF:1266-1283 (Service Item Line / Service Line fall through → 0 = Bidirectional; "Work Type" listed without any mapping).
28. Proxy table / entity name / name-field registries – DEF:1142-1264.
29. "Use default synchronization setup" routing – DEF:1299-1332 (no IsHandled set; Service* mappings unhandled).
30. Job-queue creation for mappings (`RecreateJobQueueEntryFromIntTableMapping`, no event) – DEF:1104-1135; service-order sub-mappings get **no** job queue (no call in DEF:659-1032, ShouldRecreateJobQueueEntry unused there).

Bugs/oddities spotted (relevant to a redesign):
- SUB:952 `ProofAllServiceItemLinesAssigned(ServiceHeader)` on an unassigned local → no-op.
- SUB:239-240, 259-260 use an unassigned `ServiceItemLine` (Service Item Line No. 0; real value only via field mapping/OnFindNewValueForCoupledRecordPK).
- SUB:782-793 uses unassigned `FSWorkOrderProduct.WorkOrderIncident` (dead/overwriting branch).
- SUB:1240-1246 no `if Filter <> ''` guard (unlike 1059, 1127, 1184): with all bookings skipped, `SetFilter(BookableResourceBookingId, '')` clears the filter → re-sync of the whole booking table (within mapping filters).
- SUB:1730 error message uses Bill-to Customer No. for the sell-to case.
- SUB:2525 inverted IsEnabled guard (see #23).
- DEF:865 wrong OnBefore event for SRVORDERLINE-SERVICE.
- DEF:1312-1314 unreachable Resource branch; IsHandled never set.
- Sync-path posting (Job Jnl.-Post Line) does not raise `Job Jnl.-Post Batch.OnAfterPostJnlLines`, so consumption buffered by SUB:2209 is flushed only by a later batch post (SingleInstance state leak, see section 5).

---

## 5. State, binding and mapping registration

**State / SingleInstance / binding**
- SUB is `SingleInstance = true` (SUB:32). Session-lived globals: `TempFSWorkOrderProduct`, `TempFSWorkOrderService` (temporary buffers, SUB:35-36) filled in `HandleOnAfterApplyUsage` (2258-2260, 2273-2275), flushed/cleared in `HandleOnAfterPostJnlLines` (2290-2291, 2303-2326). Also global codeunit vars `CDSIntegrationMgt`, `CDSIntegrationImpl`, `CRMSynchHelper`, `CRMIntegrationManagement` (SUB:37-40) – stateless use.
- No `BindSubscription`/`UnbindSubscription`/`EventSubscriberInstance = Manual` anywhere in the FS app (grep). All subscribers are static.
- Re-entrancy: subscribers call the engine recursively – `CRMIntegrationTableSynch.SynchRecordsFromIntegrationTable` (SUB:1062, 1130, 1187, 1246), `SynchRecordsToIntegrationTable` (SUB:1283, 2066), and FS's own `SynchRecordsToIntegrationTable` that opens a nested job via `IntegrationTableSynch.BeginIntegrationSynchJob/Synchronize/EndIntegrationSynchJob` (SUB:1329-1355). SUB:2015 runs while base has `Int. Table Manual Subscribers` bound (CRMITS:558-578).
- Explicit `Commit()` inside sync: SUB:854. `Codeunit.Run(Codeunit::"CRM Integration Management")` (initialisation) at SUB:2228, 2295.
- DEF global `LocationFieldMapping: Boolean` (DEF:31) set via `SetLocationFieldMapping` (DEF:1137-1140) and read in DEF:210 – instance state, works only because SUB:1441-1442 uses the same local DEF instance.
- FS connection-level config read at runtime: "Line Synch. Rule", "Line Post Rule", "Job Journal Template/Batch", "Hour Unit of Measure", "Integration Type", "Default Work Order Incident ID".

**How mappings are registered**
- Entry: `ResetConfiguration` (DEF:38-79), called from FS Connection Setup table (`FSConnectionSetup.Table.al:117`, `:796`) and page action (`FSConnectionSetup.Page.al:285`). It registers/activates the CDS connection (DEF:50-51), then:
  - Integration Type = Projects: PROJECTTASK, PJLINE-WORDERPRODUCT, PJLINE-WORDERSERVICE (DEF:53-57).
  - Always: SVCITEM-CUSTASSET (skipped unless Premium experience, DEF:379-382, 1034-1039), RESOURCE-BOOKABLERSC, LOCATION (skipped unless Inventory Setup "Location Mandatory", DEF:447-449), and base `CRMSetupDefaults.ResetItemProductMapping('ITEM-PRODUCT')` (DEF:62) which triggers FS subscriber #14.
  - Integration Type = "Service and projects": SRVORDERTYPE, SRVORDER, SRVORDERITEMLINE, SRVORDERLINE-ITEM, SRVORDERLINE-SERVICE, SRVORDERLINE-RESOURC; default incident; enable service order archive (DEF:64-76). (Note: project mappings are **not** created in this mode per DEF:53.)
  - `OnAfterResetConfiguration` (DEF:78 → 1296).
- Each Reset*Mapping: build filter views → `InsertIntegrationTableMapping` (DEF:1041-1055) → SetTableFilter/SetIntegrationTableFilter, Dependency Filter, conflict resolution → field mappings via `IntegrationFieldMapping.CreateRecord` (DEF:1057-1063) → `RecreateJobQueueEntryFromIntTableMapping` (DEF:1104-1135; runner `Integration Synch. Job Runner`).
- `InsertIntegrationTableMapping` calls the 12-arg `IntegrationTableMapping.CreateRecord(..., Direction, 'Dynamics CRM', Codeunit::"CRM Integration Table Synch.", UncoupleCodeunitId)` (DEF:1051-1054 → ITM:904-930):
  - **Synch. Codeunit ID** = `CRM Integration Table Synch.` for all FS mappings.
  - **Uncouple Codeunit ID** = `CDS Int. Table Uncouple` only if Direction ∈ {ToIntegrationTable, Bidirectional} and `HasCompanyIdField(IntegrationTable)` (DEF:1047-1050, which depends on FS subscriber #21 being active, i.e. FS enabled at reset time); else 0.
  - **Coupling Codeunit ID** = `CDS Int. Table Couple` (ITM:921-924; all FS UIDs are Guid, not Option).
  - Caption prefix 'Dynamics CRM' (DEF:36).

| Mapping | Direction (DEF:1266-1283) | Uncouple CU | Synch-only-coupled | Dependency filter | Conflict / JQ (interval min, inactivity) |
|---|---|---|---|---|---|
| PROJECTTASK | ToIntegrationTable | CDS Int. Table Uncouple | no | CUSTOMER\|RESOURCE-BOOKABLERSC[\|SVCITEM-CUSTASSET] (DEF:104-107) | JQ 1, 5 (DEF:131) |
| PJLINE-WORDERPRODUCT | FromIntegrationTable | 0 | no | CUSTOMER\|ITEM-PRODUCT | Deletion: Restore Records (DEF:172); JQ 1, 5 |
| PJLINE-WORDERSERVICE | FromIntegrationTable | 0 | no | CUSTOMER\|ITEM-PRODUCT\|RESOURCE-BOOKABLERSC | Deletion: Restore Records (DEF:260); JQ 1, 5 |
| RESOURCE-BOOKABLERSC | Bidirectional | CDS Int. Table Uncouple | **yes** (DEF:333) | CUSTOMER\|ITEM-PRODUCT | JQ 30, 1440 |
| SVCITEM-CUSTASSET | Bidirectional | CDS Int. Table Uncouple | **yes** (DEF:402) | CUSTOMER\|ITEM-PRODUCT | JQ 30, 1440 |
| LOCATION | ToIntegrationTable | CDS Int. Table Uncouple | no | – | JQ 30, 1440 |
| SRVORDERTYPE | Bidirectional | 0 (FS Work Order Type not in #21 list) | no | – | JQ 30, 1440 |
| SRVORDER | Bidirectional | CDS Int. Table Uncouple | no | CUSTOMER\|SRVORDERTYPE | JQ 1, 30 + "FS Archived Service Orders Job" every 30 (DEF:655-656) |
| SRVORDERITEMLINE | 0 = Bidirectional (fallthrough) | 0 (Incident not in list) | no | SRVORDER\|SVCITEM-CUSTASSET | Update conflict: Get Update from Integration (DEF:696); **no JQ** |
| SRVORDERLINE-ITEM | 0 = Bidirectional | CDS Int. Table Uncouple | no | SRVORDER\|SRVORDERITEMLINE | Get Update from Integration; no JQ |
| SRVORDERLINE-SERVICE | 0 = Bidirectional | CDS Int. Table Uncouple | no | SRVORDER\|SRVORDERITEMLINE | Get Update from Integration; no JQ |
| SRVORDERLINE-RESOURC | 0 = Bidirectional | 0 (Booking not in list) | no | SRVORDER\|SRVORDERITEMLINE\|RESOURCE-BOOKABLERSC | Get Update from Integration; no JQ |

- Constant field mappings used to stamp FS records: `IntegrateToService = 'true'` on SRVORDERTYPE, SRVORDER, SRVORDERLINE-* (DEF:539-544, 646-651, 843-848, 950-955, 1024-1029); `Document Type = 'Order'` inbound (DEF:598-602, 699-703, 765-769, 895-899, 1004-1008).
- Re-registration after "Use default synchronization setup": DEF:1299-1332 (see D4 limitations).
- Proxy/entity registries consumed by base CRM UI/coupling: DEF:1142-1264 (D1-D3); lookups: `FSLookupFSTables.Codeunit.al:11`.
- Separate non-mapping job: codeunit 6618 "FS Archived Service Orders Job" uses `IntegrationTableSynch.BeginIntegrationSynchJobLoging` directly (`FSArchivedServiceOrdersJob.Codeunit.al:45-61`).
