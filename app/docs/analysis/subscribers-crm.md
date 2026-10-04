# CRM (D365 Sales) module -> Integration Synch Engine: event-subscriber inventory (BC 29 Base App)

Source root: the Base Application source (`Base Application.Source.zip` in the BC 29.0.54011.55616 artifact). File abbreviations used in citations:

| Abbrev | File | Object |
|---|---|---|
| **S** | `Integration\D365Sales\CRMIntTableSubscriber.Codeunit.al` | codeunit 5341 "CRM Int. Table. Subscriber" (3329 lines) |
| **M** | `Integration\Dataverse\CRMIntegrationManagement.Codeunit.al` | codeunit 5330 "CRM Integration Management" (4259 lines) |
| **T** | `Integration\Dataverse\CRMIntegrationTableSynch.Codeunit.al` | codeunit 5340 "CRM Integration Table Synch." (1027 lines) |
| **H** | `Integration\D365Sales\CRMSynchHelper.Codeunit.al` | codeunit 5342 "CRM Synch. Helper" |
| **I** | `Integration\SynchEngine\IntegrationRecSynchInvoke.Codeunit.al` | codeunit "Integration Rec. Synch. Invoke" (engine publisher) |
| **R** | `Integration\SynchEngine\IntegrationRecordSynch.Codeunit.al` | codeunit "Integration Record Synch." (engine publisher) |
| **E** | `Integration\SynchEngine\IntegrationTableSynch.Codeunit.al` | codeunit "Integration Table Synch." (engine publisher) |

Counts verified: S has 23 `[EventSubscriber]`s (S:100,114,130,172,227,247,272,446,500,553,797,831,861,886,911,996,1025,1043,1082,1088,3203,3213,3228); M has 11 (M:2645,2680,2722,2751,2761,3184,3617,3626,3645,3658,4157); T has 3 (T:980,998,1009).

## 0. How the dispatch works (read this first)

* **Dispatch key is a string of table *names*, not the Integration Table Mapping.** Every record-level subscriber in S calls `GetSourceDestCode(SourceRecordRef, DestinationRecordRef)` (S:1172-1177), which returns `StrSubstNo('%1-%2', SourceRecordRef.Name(), DestinationRecordRef.Name())` (pattern `SourceDestCodePatternTxt` S:71), and then does `case ... of '<BC table name>-<CRM table name>'`. The table pair is therefore hard-coded as literal strings such as `'Sales Header-CRM Salesorder'`.
* **The `IntegrationTableMapping` parameter is ignored.** The engine publishers `OnBeforeInsertRecord`, `OnAfterInsertRecord`, `OnFindUncoupledDestinationRecord` pass `IntegrationTableMapping` (I:778, I:783, I:808), but the S subscribers declare a parameter subset without it (S:501, S:554, S:997). `OnBeforeModifyRecord` / `OnAfterModifyRecord` / `OnAfterUnchangedRecordHandled` / `OnBeforeIgnoreUnchangedRecordHandled` receive it but never read it (S:798, 832, 862, 887). `OnBeforeTransferRecordFields` / `OnAfterTransferRecordFields` do not even get it from the publisher (I:753, I:758). Only `OnTransferFieldData` re-derives a mapping, and only for PK lookups via `CRMSynchHelper.AreFieldsRelatedToMappedTables` (S:424, H:1596).
* **Most record-level subscribers have no connection guard at all.** S:247, 446, 500, 553, 797, 831, 861, 886, 911 do not check `IsCRMIntegrationEnabled`/`IsCDSIntegrationEnabled`/connection type; they rely only on the table-name pair matching. Only `OnTransferFieldData` (S:292) and `OnFindUncoupledDestinationRecord` (S:1002-1004) check an enablement flag. Sales-order branches are additionally gated by `CRMConnectionSetup.IsBidirectionalSalesOrderIntEnabled()`.
* The engine raises these events for *every* integration that uses it (CRM, CDS, Field Service, other `TableConnectionType`s). The events are raised at I:154 (`OnBeforeIgnoreUnchangedRecordHandled`), I:165 (`OnUpdateConflictDetected`), I:210 (`OnAfterUnchangedRecordHandled`), I:234/244 (`OnBefore/AfterInsertRecord`), I:259/264 (`OnBefore/AfterModifyRecord`), I:355 (`OnDeletionConflictDetected`), I:452 (`OnFindUncoupledDestinationRecord`), I:509/530 (`OnBeforeTransferRecordFields`), I:521/537 (`OnAfterTransferRecordFields`), R:489 (`OnTransferFieldData`), E:71/93 (`OnAfterInitSynchJob`).

---

## 1. Subscriber table

Columns: **#**, subscriber (file:line, procedure), publisher + event (exact), parameters as declared in the subscriber, guard conditions, branches (BC table <-> CRM table) with a 1-2 line summary per branch.

### 1A. CRM Int. Table. Subscriber (codeunit 5341, S)

#### S1. `OnAfterJobQueueEntryRun` (S:100-112), local
* **Publisher:** `Codeunit::"Job Queue Start Codeunit"`, `'OnAfterRun'`.
* **Params:** `var JobQueueEntry: Record "Job Queue Entry"`.
* **Guard:** `IsJobQueueEntryCRMIntegrationJob(JobQueueEntry, IntegrationTableMapping)` (S:106; helper S:185-225 treats as CRM: `CRM Statistics Job`, `CRM Archived Sales Orders Job`, and `Integration Synch. Job Runner`/`Int. Uncouple Job Runner`/`Int. Coupling Job Runner` whose mapping has `Synch. Codeunit ID = CRM Integration Table Synch.` / `Uncouple Codeunit ID = CDS Int. Table Uncouple` / `Coupling Codeunit ID = CDS Int. Table Couple`).
* **Branches:** none (not table-pair).
* **Logic:** if `IntegrationSynchJob.HaveJobsBeenIdle(...)` and recurring -> Status `On Hold with Inactivity Timeout`, else Status `Ready` (S:107-111).

#### S2. `DeleteCouplingOnAfterDeleteAfterPosting` (S:114-128), local
* **Publisher:** `Codeunit::"Sales-Post"`, `'OnAfterDeleteAfterPosting'`.
* **Params:** `SalesHeader: Record "Sales Header"; SalesInvoiceHeader: Record "Sales Invoice Header"; SalesCrMemoHeader: Record "Sales Cr.Memo Header"; CommitIsSuppressed: Boolean`.
* **Guard:** exit if `CRMConnectionSetup.IsBidirectionalSalesOrderIntEnabled()` (S:120); exit if `SalesHeader.SystemId` null (S:122).
* **Branch:** Sales Header <-> CRM Salesorder (implicit, `"Table ID" = Database::"Sales Header"`, S:125).
* **Logic:** deletes `CRM Integration Record`s for the posted/deleted sales header (unidirectional order integration only).

#### S3. `OnFindingIfJobNeedsToBeRun` (S:130-170), local
* **Publisher:** `Database::"Job Queue Entry"` (Table), `'OnFindingIfJobNeedsToBeRun'`.
* **Params:** `var Sender: Record "Job Queue Entry"; var Result: Boolean`.
* **Guard:** exit if `Result` already true (S:139); `IsJobQueueEntryCRMIntegrationJob(...)` AND `CRMIntegrationManagement.IsCRMTable(IntegrationTableMapping."Integration Table ID")` (S:142-143); `CRMConnectionSetup."Is Enabled" or CDSIntegrationImpl.IsIntegrationEnabled()` (S:146).
* **Branches:** none.
* **Logic:** if another JQE for the same mapping is "In Process" -> Result false (S:147-152). Else registers a temp connection (CDS: `CDSIntegrationImpl.RegisterConnection` + `SetDefaultTableConnection`, S:154-156; CRM: `RegisterConnectionWithName`, S:158), opens the integration table with `IntegrationTableMapping.SetIntRecordRefFilter`, sets Result := not empty, unregisters (S:159-167).

#### S4. `OnShowDetailedLog` (S:172-183), local
* **Publisher:** `Page::"Job Queue Log Entries"`, `'OnShowDetails'`.
* **Params:** `JobQueueLogEntry: Record "Job Queue Log Entry"`.
* **Guard:** object type Codeunit and Object ID in [`Integration Synch. Job Runner`, `CRM Statistics Job`, `Int. Uncouple Job Runner`, `Int. Coupling Job Runner`] (S:177-178).
* **Logic:** opens `Integration Synch. Job List` filtered by log entry no (S:180-181).

#### S5. `OnCleanupAfterJobExecution` (S:227-245), local
* **Publisher:** `Database::"Job Queue Entry"`, `'OnAfterDeleteEvent'`.
* **Params:** `var Rec: Record "Job Queue Entry"; RunTrigger: Boolean`.
* **Guard:** not temporary (S:234); `Record ID to Process` is an `Integration Table Mapping` (S:238). **No CRM/CDS check** - applies to any integration type.
* **Logic:** if mapping has `Delete After Synchronization` -> `IntegrationTableMapping.Delete(true)` (S:241-243).

#### S6. `OnBeforeTransferRecordFields` (S:247-270), **global** `procedure`
* **Publisher:** `Codeunit::"Integration Rec. Synch. Invoke"`, `'OnBeforeTransferRecordFields'` (declared I:753, raised I:509, I:530).
* **Params:** `SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef`.
* **Guard:** none at top level (no CRM/CDS enabled check).
* **Branches (`case GetSourceDestCode`)**:

| Branch | Direction | Summary | Branch guard |
|---|---|---|---|
| `'Sales Invoice Header-CRM Invoice'` (S:254-255) | BC->CRM | `CheckItemOrResourceIsNotBlocked` - if invoice not yet coupled, `TestField(Blocked,false)` on every Item/Resource line (S:2713-2741). | none |
| `'Sales Line-CRM Salesorderdetail'` (S:256-257) | BC->CRM | `AddSalesOrderIdToCRMSalesorderdetail` - sets `SalesOrderId` from the coupled CRM order of the BC header; errors if header uncoupled (S:2743-2761). | inside helper: `IsBidirectionalSalesOrderIntEnabled` (S:2752) |
| `'CRM Salesorderdetail-Sales Line'` (S:258-262) | CRM->BC | `AddDocumentNoToSalesOrderLine` (sets Document No. from coupled header, S:2763-2781) + `AddTypeToSalesOrderLine` (Item/Resource from CRM ProductTypeCode or write-in product setup, S:2873-2907). | inside helpers: `IsBidirectionalSalesOrderIntEnabled` (S:2772, S:2881) |
| `'CRM Salesorder-Sales Header'` (S:263-268) | CRM->BC | Forces `SalesHeader.Status := Open` before transfer. | `IsBidirectionalSalesOrderIntEnabled` (S:264) |

#### S7. `OnTransferFieldData` (S:272-429), **global**
* **Publisher:** `Codeunit::"Integration Record Synch."`, `'OnTransferFieldData'` (declared R:601, raised R:489).
* **Params:** `SourceFieldRef: FieldRef; DestinationFieldRef: FieldRef; var NewValue: Variant; var IsValueFound: Boolean; var NeedsConversion: Boolean`.
* **Guards (sequential):** exit if `IsValueFound` (S:289); exit unless `IsCDSIntegrationEnabled() or IsCRMIntegrationEnabled()` (S:292); exit if same field no. in same table (S:295-297); **if CDS enabled, exit for Customer/Vendor/Currency/Contact/Salesperson-Purchaser on either side** (S:299-302) - those are handled by "CDS Int. Table. Subscriber" (`Integration\Dataverse\CDSIntTableSubscriber.Codeunit.al:262`).
* **Branches (first match wins, each `exit`s):**

| # | Condition (lines) | Pair | Summary | Extra guard |
|---|---|---|---|---|
| a | S:304-310 | CRM Salesorderdetail -> Sales Line, field `"No."` | `AddWriteInProductNo` - null ProductId -> use `Sales & Receivables Setup."Write-in Product No."` (error if blank) (S:2783-2797). | `IsBidirectionalSalesOrderIntEnabled` |
| b | S:312-326 | any `"Currency Code"` -> `TransactionCurrencyId` (matched **by field name**) | blank BC currency + CDS base currency <> LCY -> map to CRM currency whose ISO = LCY Code. | `CDSConnectionSetup.BaseCurrencyCode <> ''` and LCY <> base |
| c | S:328-342 | `TransactionCurrencyId` -> `"Currency Code"` (by name) | CRM currency that equals LCY -> blank BC currency code. | same as b |
| d | S:344-350 | Sales Line `"No."` -> CRM Salesorderdetail | `AddWriteInSalesorderdetail` - write-in product no. -> empty ProductId GUID (S:2799-2811). | `IsBidirectionalSalesOrderIntEnabled` |
| e | S:352-373 | * -> CRM Salesorder `OwnerId` (by field **name** 'OwnerId') | Team model: keep destination value; Person model: `CRMSynchHelper.GetCoupledCDSUserId` (H:1628). | `IsBidirectionalSalesOrderIntEnabled` |
| f | S:375-380 | generic table->option | `CRMSynchHelper.ConvertTableToOption` (H:1917). | none |
| g | S:382-387 | generic option->table | `CRMSynchHelper.ConvertOptionToTable` (H:1937). | none |
| h | S:389-394 | any CRM table `OwnerId` | `ShouldKeepOldValue` (S:431-444): keep old OwnerId when CDS enabled and Ownership Model = Team. | CDS enabled + `IsCRMTable` |
| i | S:396-400 | generic | `CRMSynchHelper.FindNewValueForSpecialMapping(Src, Dst, NewValue)` (internal overload H:1995). | none |
| j | S:402-422 | Item/Resource `"Base Unit of Measure"`, Price List Line `"Unit of Measure Code"` -> CRM; CRM Product `DefaultUoMId` -> BC; Unit Group -> CRM | `ConvertBaseUnitOfMeasureToUomId`, `ConvertUomIdToBaseUnitOfMeasure`, `PrefixUnitGroupCode` (all H). Note the Unit Group sub-branch (S:417-421) sets IsValueFound but does **not** `exit`, so it falls through to k. | `IsUnitGroupMappingEnabled()` |
| k | S:424-428 | any FK field whose related tables are both mapped | `FindNewValueForCoupledRecordPK` (S:3148-3192): translate BC PK <-> CRM GUID via `CRM Integration Record`; blank / clear-on-fail / error `RecordMustBeCoupledErr`. | `AreFieldsRelatedToMappedTables` (H:1596) |

#### S8. `OnAfterTransferRecordFields` (S:446-498), **global**
* **Publisher:** `Codeunit::"Integration Rec. Synch. Invoke"`, `'OnAfterTransferRecordFields'` (I:758; raised I:521, I:537).
* **Params:** `SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef; var AdditionalFieldsWereModified: Boolean; DestinationIsInserted: Boolean`.
* **Guard:** `OnBeforeGetSourceDestCodeOnAfterTransferRecordFields(..., IsHandled)` - whole-subscriber IsHandled (S:451-453, event S:3289-3292). No CRM-enabled check.
* **Branches:**

| Branch | Summary |
|---|---|
| `'CRM Account-Customer'` (S:456-458) | `UpdateCustomerBlocked` - CRM StatusCode Inactive and Customer.Blocked = ' ' -> Blocked::All (S:1179-1198). |
| `'Sales Price-CRM Productpricelevel'` (S:459-461) | `UpdateCRMProductPricelevelAfterTransferRecordFields` - recompute UoMId/UoMScheduleId via `FindCRMUoMIdForSalesPrice` (S:1896-1911). |
| `'Price List Line-CRM Productpricelevel'` (S:462-464) | `UpdateCRMProductPricelevelAfterTransferRecordFieldsPriceListLine` - same for Price List Line (S:1913-1931). |
| `'Currency-CRM Transactioncurrency'` (S:465-467) | `UpdateCRMTransactionCurrencyAfterTransferRecordFields` - sets ExchangeRate from `GetCRMLCYToFCYExchangeRate`; errors if 0 (S:2115-2134). |
| `'Item-CRM Product'`, `'Resource-CRM Product'` (S:468-471) | `UpdateCRMProductAfterTransferRecordFields` - currency id, UoM/UoM schedule, negative price/QOH -> 0, default price list item(s), vendor name, ProductTypeCode, StateCode on insert (S:1933-2006). |
| `'CRM Product-Item'` (S:472-474) | `UpdateItemAfterTransferRecordFields` - Item.Blocked from CRM StateCode (S:2073-2087). |
| `'CRM Product-Resource'` (S:475-477) | `UpdateResourceAfterTransferRecordFields` - Resource.Blocked from StateCode (S:2089-2103). |
| `'Unit of Measure-CRM Uomschedule'` (S:478-480) | `UpdateCRMUoMScheduleAfterTransferRecordFields` - name "NAV <UoM>", validate schedule (inactive -> error, >1 unit -> error, rename unit) (S:2211-2243, S:2392-2420). |
| `'Unit Group-CRM Uomschedule'` (S:481-482) | `CheckCRMUoMScheduleAfterTransferRecordFields` - error if CRM schedule inactive (S:2245-2258). Never sets AdditionalFieldsWereModified. |
| `'Item Unit of Measure-CRM Uom'` (S:483-485) | `UpdateCRMUomFromItemAfterTransferRecordFields` - resolve UoMScheduleId from item's Unit Group (couple+sync group if missing), update price list item for UoM (S:2260-2305). |
| `'Resource Unit of Measure-CRM Uom'` (S:486-488) | Resource variant (S:2307-2352). |
| `'Sales Line-CRM Salesorderdetail'` (S:489-491) | `UpdateCRMSalesorderdetailUom` - UoMId from UoM coupling (legacy) or Item/Resource UoM coupling (unit-group mode) (S:2970-3015). **No bidirectional guard here.** |
| `'CRM Salesorderdetail-Sales Line'` (S:492-496) | `UpdateSalesLineUnitOfMeasure` (unit-group mode only, S:2909-2954) and, only if that returned true, `UpdateSalesLinePriceOverride` (Unit Price := PricePerUnit, S:2956-2968). |

#### S9. `OnBeforeInsertRecord` (S:500-551), **global**
* **Publisher:** `Codeunit::"Integration Rec. Synch. Invoke"`, `'OnBeforeInsertRecord'` (I:778, raised I:234). Publisher also passes `IntegrationTableMapping` and `var InsertWithSystemId` - subscriber omits both.
* **Params:** `SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef`.
* **Guard:** none at top.
* **Branches:**

| Branch | Summary | Branch guard |
|---|---|---|
| `'CRM Contact-Contact'` (S:507-508) | `UpdateContactParentCompany` - `CRMSynchHelper.SetContactParentCompany(ParentCustomerId)`; error `ContactMissingCompanyErr` unless business relation optional (S:1200-1218). | none |
| `'Contact-CRM Contact'` (S:509-510) | `UpdateCRMContactParentCustomerId` - set ParentCustomerId from customer coupled via Contact Business Relation (S:1328-1344, S:2422-2441). | exits if CDS enabled (S:1335) |
| `'Currency-CRM Transactioncurrency'` (S:511-512) | `UpdateCRMTransactionCurrencyBeforeInsertRecord` - CurrencyPrecision := `GetCRMCurrencyDefaultPrecision` (S:2105-2113). | none |
| `'Customer Price Group-CRM Pricelevel'` (S:513-514) | `UpdateCRMPricelevelBeforeInsertRecord` - validate all sales prices (currency, coupled product, UoM), set currency id, description, CompanyId (S:1601-1621, S:2654-2699). | none |
| `'Price List Header-CRM Pricelevel'` (S:515-516) | `UpdateCRMPricelevelBeforeInsertPriceListHeader` - same + StateCode from Status (S:1623-1648, S:2669-2711). | none |
| `'Item-CRM Product'`, `'Resource-CRM Product'` (S:517-519) | `UpdateCRMProductBeforeInsertRecord` - decimals supported, default price list, CompanyId (S:2062-2071). | none |
| `'Sales Invoice Header-CRM Invoice'` (S:520-524) | `CheckSalesInvoiceLineItemsAreCoupled` (locks posted invoice tables, **`Commit()`** S:1373, forces sync of each line's product, S:1346-1384) then `UpdateCRMInvoiceBeforeInsertRecord` (link to CRM order via "Your Reference" or to customer's account + price level; owner + CompanyId) (S:1471-1544). | none |
| `'Opportunity-CRM Opportunity'` (S:525-526) | `UpdateCRMOpportunityBeforeInsertRecord` -> `UpdateOwnerIdAndCompanyId` (S:1650-1653, S:1148-1159). | CDS enabled inside helper (S:1152) |
| `'Sales Invoice Line-CRM Invoicedetail'` (S:527-528) | `UpdateCRMInvoiceDetailsBeforeInsertRecord` - get header (with `Sleep(5000)` + `SelectLatestVersion` retry, S:1582-1584), require coupled header, initialize line from CRM header / BC header / line / product details, `CreateCRMProductpriceIfAbsent` (S:1566-1599, S:2443-2539). | none |
| `'Sales Header-CRM Salesorder'` (S:529-536) | `UpdateCRMSalesOrderPriceList`, `SetCompanyId`, `SetCRMOrderName` (Name := Sell-to Customer Name), `SetDocOccurenceNumber`, `CDSIntTableSubscriber.SetOwnerId`. | `IsBidirectionalSalesOrderIntEnabled` (S:530) |
| `'CRM Salesorder-Sales Header'` (S:537-539) | `UpdateSalesOrderQuoteNo` - find BC quote by CRM QuoteNumber in "Your Reference", set "Quote No.", archive quote (S:3123-3146). | bidirectional (S:538) |
| `'Sales Line-CRM Salesorderdetail'` (S:540-544) | `SetWriteInProduct` (IsProductOverridden + description, S:3105-3121), `ApplySalesLineTax` (S:1828-1845). | bidirectional (S:541) |
| *second case* `DestinationRecordRef.Number() = Database::"Salesperson/Purchaser"` (S:547-550) | `UpdateSalesPersOnBeforeInsertRecord` - generate code `SP NO. 0000n` (S:1304-1326). Applies to **any source table**. | exits if CDS enabled or neither enabled (S:1310-1314) |

#### S10. `OnAfterInsertRecord` (S:553-601), **global**
* **Publisher:** `Codeunit::"Integration Rec. Synch. Invoke"`, `'OnAfterInsertRecord'` (I:783, raised I:244). Subscriber omits `IntegrationTableMapping`.
* **Params:** `var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef`.
* **Guard:** none at top.
* **Branches:**

| Branch | Summary | Guard |
|---|---|---|
| `'Customer Price Group-CRM Pricelevel'` (S:561-562) | `ResetCRMProductpricelevelFromCustomerPriceGroup` - nested `SynchRecordsToIntegrationTable` of all Sales Prices of the group (S:1685-1700). | none |
| `'Price List Header-CRM Pricelevel'` (S:563-564) | `ResetCRMProductpricelevelFromPriceListHeader` - nested sync of all Price List Lines (S:1702-1716). | none |
| `'Item-CRM Product'`, `'Resource-CRM Product'` (S:565-567) | `UpdateCRMProductAfterInsertRecord` - price list item(s), StateCode Active, `CRMProduct.Modify()` (S:2008-2020). | none |
| `'Sales Invoice Header-CRM Invoice'` (S:568-572) | `UpdateCRMInvoiceAfterInsertRecord` (**`Commit()`** S:1397, nested sync of invoice lines, totals, status, **`Commit()`** S:1426; S:1386-1427) + `UpdatePricesIncludeVATRounding` (inserts a 'Rounding' write-in CRM invoicedetail, S:1429-1469). | totals branch on `"Is S.Order Integration Enabled" or "Bidirectional Sales Order Int."` (S:1412) |
| `'Sales Invoice Line-CRM Invoicedetail'` (S:573-574) | `UpdateCRMInvoiceDetailsAfterInsertRecord` - discounts/tax/base/extended amounts, `Modify()` (S:1546-1564). | none |
| `'Item Unit of Measure-CRM Uom'` (S:575-576) | `UpdateCRMUomFromItemAfterInsertRecord` - `UpdateCRMPriceListItemForUom` (S:2022-2040). | none |
| `'Resource Unit of Measure-CRM Uom'` (S:577-578) | resource variant (S:2042-2060). | none |
| `'Sales Header-CRM Salesorder'` (S:579-583) | `ResetCRMSalesorderdetailFromSalesOrderLine` (delete orphan CRM lines + nested sync of BC lines, S:1718-1764), `SetCRMSalesOrderStateCode` (fulfill if completely shipped else Submitted, S:747-759). | bidirectional (S:580) |
| `'CRM Salesorder-Sales Header'` (S:584-592) | `ResetSalesOrderLineFromCRMSalesorderdetail` (delete orphan BC lines + nested sync from CRM, S:1766-1826), `ApplySalesOrderDiscounts` (S:1847-1866), `CreateFreightLines` (S:1868-1894), `SetSalesOrderStatus` (release/reopen via prepayment test, S:733-745, S:774-795), `SetOrderNumberAndDocOccurenceNumber` (writes back to CRM, S:3090-3103), `CreateSalesOrderNotes` (CRM annotations -> Record Links, S:2813-2871). | bidirectional (S:585) |
| `'CRM Product-Item'` (S:593-594) | `CreateUnitGroupAndItemUnitOfMeasure` - couple Unit Group to CRM schedule, create base Item UoM, couple to DefaultUoMId, nested sync (S:603-648). | only when both mappings Unit Group<->CRM Uomschedule and Item UoM<->CRM Uom exist with "Synch. Only Coupled Records" = false (S:615-623) |
| `'CRM Product-Resource'` (S:595-596) | resource variant (S:650-695). | same pattern (S:662-670) |
| `'CRM Salesorderdetail-Sales Line'` (S:597-599) | `AutoReserveSalesLine` - Item with Reserve::Always -> `AutoReserve()` (S:3194-3201). | bidirectional (S:598) |

#### S11. `OnBeforeModifyRecord` (S:797-829), **global**
* **Publisher:** `Codeunit::"Integration Rec. Synch. Invoke"`, `'OnBeforeModifyRecord'` (I:763, raised I:259).
* **Params:** `IntegrationTableMapping: Record "Integration Table Mapping"; SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef` (mapping unused).
* **Guard:** none at top.
* **Branches:**

| Branch | Summary | Guard |
|---|---|---|
| `'CRM Contact-Contact'` (S:804-805) | `UpdateContactParentCompany` (as S9). | none |
| `'Contact-CRM Contact'` (S:806-807) | `UpdateCRMContactParentCustomerId` (as S9). | CDS -> exit |
| `'Customer Price Group-CRM Pricelevel'` (S:808-809) | `UpdateCRMPricelevelBeforeModifyRecord` - validate prices, `TestField(TransactionCurrencyId, ...)`, CompanyId (S:1655-1668). | none |
| `'Price List Header-CRM Pricelevel'` (S:810-811) | `UpdateCRMPricelevelBeforeModifyPriceListHeader` (S:1670-1683). | none |
| `'Item-CRM Product'`, `'Resource-CRM Product'`, `'Opportunity-CRM Opportunity'`, `'Sales Invoice Header-CRM Invoice'` (S:812-816) | `SetCompanyId` (S:1161-1170). | CDS enabled inside helper |
| `'Sales Header-CRM Salesorder'` (S:817-824) | Unidirectional: `ChangeSalesOrderStateCode(..., Active)` - a separate `Get`+`Modify` on CRM (S:697-712); bidirectional: `UpdateCRMSalesOrderPriceList` (S:3017-3046). Then `SetCompanyId`. | `IsBidirectionalSalesOrderIntEnabled` selects path; `ChangeSalesOrderStateCode` exits unless `IsCRMIntegrationEnabled` (S:702) |
| `'Sales Line-CRM Salesorderdetail'` (S:825-827) | `ApplySalesLineTax`. | bidirectional |

#### S12. `OnAfterModifyRecord` (S:831-859), **global**
* **Publisher:** `Codeunit::"Integration Rec. Synch. Invoke"`, `'OnAfterModifyRecord'` (I:768, raised I:264).
* **Params:** `IntegrationTableMapping: Record "Integration Table Mapping"; SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef` (mapping unused).
* **Branches:**

| Branch | Summary | Guard |
|---|---|---|
| `'Customer Price Group-CRM Pricelevel'` (S:837-838) | `ResetCRMProductpricelevelFromCustomerPriceGroup`. | none |
| `'Price List Header-CRM Pricelevel'` (S:839-840) | `ResetCRMProductpricelevelFromPriceListHeader`. | none |
| `'Sales Header-CRM Salesorder'` (S:841-846) | bidirectional: `ResetCRMSalesorderdetailFromSalesOrderLine` + `SetCRMSalesOrderStateCode`; else `SubmitOrInvoiceSalesOrder` (StateCode Invoiced/Submitted via `CRMSalesDocumentPostingMgt.IsSalesOrderFullyInvoiced`, S:761-772). | bidirectional flag |
| `'CRM Salesorder-Sales Header'` (S:847-854) | `ResetSalesOrderLineFromCRMSalesorderdetail`, `ApplySalesOrderDiscounts`, `CreateFreightLines`, `SetSalesOrderStatus`, `CreateSalesOrderNotes`. | bidirectional |
| *post-case* `DestinationRecordRef.Number() = DATABASE::Customer` (S:857-858) | `CRMSynchHelper.UpdateContactOnModifyCustomer` (H:1137) for **any** source table. | none |

#### S13. `OnAfterUnchangedRecordHandled` (S:861-884), **global**
* **Publisher:** `Codeunit::"Integration Rec. Synch. Invoke"`, `'OnAfterUnchangedRecordHandled'` (I:788, raised I:210).
* **Params:** `IntegrationTableMapping: Record "Integration Table Mapping"; SourceRecordRef: RecordRef; DestinationRecordRef: RecordRef` (mapping unused).
* **Branches:** `'Customer Price Group-CRM Pricelevel'` (S:868-869) and `'Price List Header-CRM Pricelevel'` (S:870-871): reset product price levels as S12; `'Sales Header-CRM Salesorder'` (S:872-874, bidirectional): `ResetCRMSalesorderdetailFromSalesOrderLine`; `'CRM Salesorder-Sales Header'` (S:875-882, bidirectional): `ChangeSalesOrderStatus(Open)` (direct `Modify` without release codeunit, S:714-731), `ResetSalesOrderLineFromCRMSalesorderdetail`, `CreateFreightLines`, `SetSalesOrderStatus`, `CreateSalesOrderNotes`.
* Note: `CDSIntTableSubscriber` also subscribes to this event (`CDSIntTableSubscriber.Codeunit.al:982`).

#### S14. `OnBeforeIgnoreUnchangedRecordHandled` (S:886-909), local
* **Publisher:** `Codeunit::"Integration Rec. Synch. Invoke"`, `'OnBeforeIgnoreUnchangedRecordHandled'` (I:828, raised I:154).
* **Params:** `IntegrationTableMapping: Record "Integration Table Mapping"; SourceRecordRef: RecordRef; DestinationRecordRef: RecordRef` (mapping unused).
* **Guard:** `OnHandleOnBeforeIgnoreUnchangedRecordHandled(..., IsHandled)` whole-subscriber (S:893-895, event S:3294-3297).
* **Branches:** `'Sales Header-CRM Salesorder'` (S:898-900, bidirectional): `ResetCRMSalesorderdetailFromSalesOrderLine`; `'CRM Salesorder-Sales Header'` (S:901-907, bidirectional): `ChangeSalesOrderStatus(Open)`, `ResetSalesOrderLineFromCRMSalesorderdetail`, `SetSalesOrderStatus`, `CreateSalesOrderNotes` (note: no `CreateFreightLines`, unlike S13).

#### S15. `OnQueryPostFilterIgnoreRecord` (S:911-937), **global**
* **Publisher:** `Codeunit::"CRM Integration Table Synch."`, `'OnQueryPostFilterIgnoreRecord'` (declared T:935-938, raised T:592 and T:626). This is a CRM-owned publisher, not engine.
* **Params:** `SourceRecordRef: RecordRef; var IgnoreRecord: Boolean`.
* **Guard:** exit if `IgnoreRecord` (S:914). Dispatch is by **source table number only** (`case SourceRecordRef.Number()`), no destination.
* **Branches:**

| Source table | Summary |
|---|---|
| Contact (S:918-919) | `HandleContactQueryPostFilterIgnoreRecord` - ignore if no related Customer (or Vendor when CDS) unless business relation optional (S:1220-1238). |
| Opportunity (S:920-921) | `HandleOpportunityQueryPostFilterIgnoreRecord` - CDS + Team model: ignore if contact isn't a person with company; then contact check (S:1276-1302). |
| Sales Invoice Line (S:922-923) | `Error(CannotSynchOnlyLinesErr)` - hard error. |
| Item (S:924-925) | `HandleItemQueryPostFilterIgnoreRecord` - ignore write-in product item (S:1240-1256). |
| Resource (S:926-927) | `HandleResourceQueryPostFilterIgnoreRecord` - ignore write-in product resource (S:1258-1274). |
| Sales Invoice Header (S:928-929) | `IgnoreReadOnlyInvoiceOnQueryPostFilterIgnoreRecord` - ignore if coupled CRM invoice not Active (S:977-994). |
| Sales Header (S:930-931) | `IgnoreArchievedSalesOrdersOnQueryPostFilterIgnoreRecord` - ignore "Archived Sales Order" couplings when bidirectional (S:939-956). |
| CRM Salesorder (S:932-933) | `IgnoreArchievedCRMSalesordersOnQueryPostFilterIgnoreRecord` - same for CRM side (S:958-975). |

* After the case: `OnAfterHandlePostFilterIgnoreRecord(SourceRecordRef, IgnoreRecord)` (S:936, event S:3324-3327).

#### S16. `OnFindUncoupledDestinationRecord` (S:996-1023), **global**
* **Publisher:** `Codeunit::"Integration Rec. Synch. Invoke"`, `'OnFindUncoupledDestinationRecord'` (I:808, raised I:452). Subscriber omits `IntegrationTableMapping`.
* **Params:** `SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef; var DestinationIsDeleted: Boolean; var DestinationFound: Boolean`.
* **Guard:** exit if `DestinationFound` (S:999); exit unless `IsCRMIntegrationEnabled or IsCDSIntegrationEnabled` (S:1002-1004).
* **Branches:** `'Unit of Measure-CRM Uomschedule'` (S:1007-1009): `CRMUoMScheduleFindUncoupledDestinationRecord` - match CRM unit group "NAV <UoM>" (S:2363-2390); `'Currency-CRM Transactioncurrency'` (S:1010-1012): match by ISOCurrencyCode (S:2136-2150). Second case by **source number only**: `Sales Price` (S:1016-1018) -> `CRMPriceListLineFindUncoupledDestinationRecord` (S:2152-2174); `Price List Line` (S:1019-1021) -> `CRMExtPriceListLineFindUncoupledDestinationRecord` (S:2176-2209) - match productpricelevel on PriceLevelId+UoMId+ProductId.

#### S17. `OnAfterDeleteIntegrationTableMapping` (S:1025-1041), **global**
* **Publisher:** `Database::"Integration Table Mapping"`, `'OnAfterDeleteEvent'`.
* **Params:** `var Rec: Record "Integration Table Mapping"; RunTrigger: Boolean`.
* **Guard:** not temporary; `Rec.Type = Dataverse` (S:1033).
* **Logic:** delete JQ tasks for Synch/Uncouple/Coupling job runners pointing to the mapping (S:1036-1040).

#### S18. `LogTelemetryOnAfterInitSynchJob` (S:1043-1073), local
* **Publisher:** `Codeunit::"Integration Table Synch."`, `'OnAfterInitSynchJob'` (E:679, `[Scope('OnPrem')]`, raised E:71, E:93). Subscriber attribute uses `SkipOnMissingLicense/Permission = true, true`.
* **Params:** `ConnectionType: TableConnectionType; IntegrationTableID: Integer`.
* **Guard:** `ConnectionType = CRM` (S:1051); IntegrationTableID in fixed list [CRM Salesorder, CRM Invoice, CRM Quote, CRM Opportunity, CRM Pricelevel, CRM Product, CRM Productpricelevel, CRM Uom, CRM Uomschedule, CRM Account Statistics] (S:1053-1063).
* **Logic:** telemetry + Feature uptake (S:1064-1071).

#### S19. `HandleOnAfterUncoupleRecord` (S:1082-1086), local
* **Publisher:** `Codeunit::"Int. Rec. Uncouple Invoke"`, `'OnAfterUncoupleRecord'` (`IntRecUncoupleInvoke.Codeunit.al:210`).
* **Params:** `IntegrationTableMapping: Record "Integration Table Mapping"; var LocalRecordRef: RecordRef; var IntegrationRecordRef: RecordRef`.
* **Guard:** none (no enabled check); effective branch: `IntegrationRecordRef.Number() = CRM Salesorder` inside `GetCoupledSalesLines` (S:1126).
* **Branch:** Sales Header <-> CRM Salesorder: `RemoveChildCouplings` -> `CRMIntegrationManagement.RemoveCoupling(Database::"Sales Line", SalesLineList, false)` (S:1111-1146).

#### S20. `HandleOnAfterDeleteAfterPosting` (S:1088-1095), local
* **Publisher:** `Database::"Sales Header"`, `'OnAfterDeleteEvent'`.
* **Params:** `var Rec: Record "Sales Header"`.
* **Guard:** not temporary; inside `MarkArchivedSalesOrder` (public, S:1097-1109): `IsBidirectionalSalesOrderIntEnabled`.
* **Logic:** sets `CRM Integration Record."Archived Sales Order" := true` for the deleted header.

#### S21. `HandleOnIsCRMIntegrationRecord` (S:3203-3211), local
* **Publisher:** `Codeunit::"CRM Integration Management"`, `'OnIsCRMIntegrationRecord'` (M:4196-4199, raised M:3707).
* **Params:** `TableID: Integer; var isIntegrationRecord: Boolean`.
* **Guard/branch:** `TableID = Sales Header Archive` and bidirectional -> true.

#### S22. `HandleOnIsIntegrationRecordChild` (S:3213-3226), local
* **Publisher:** `Codeunit::"CRM Integration Management"`, `'OnIsIntegrationRecordChild'` (M:4216-4219).
* **Params:** `TableId: Integer; var Handled: Boolean; var ReturnValue: Boolean`.
* **Guard:** `CRMConnectionSetup.IsEnabled()` (S:3218); `TableId = Sales Line` and bidirectional -> Handled := true, ReturnValue := false (Sales Line is a first-class integration record, not a child).

#### S23. `HandleOnBeforeSetMatchingFilter` (S:3228-3267), local
* **Publisher:** `Codeunit::"CDS Int. Table Couple"`, `'OnBeforeSetMatchingFilter'` (`CDSIntTableCouple.Codeunit.al:367`).
* **Params:** `var IntegrationRecordRef: RecordRef; var MatchingIntegrationRecordFieldRef: FieldRef; var LocalRecordRef: RecordRef; var MatchingLocalFieldRef: FieldRef; var SetMatchingFilterHandled: Boolean`.
* **Guard:** none (does not check `SetMatchingFilterHandled` on entry, no enabled check).
* **Branches:** Unit Group <-> CRM Uomschedule, match field Name/"Source No." -> filter Name = `UnitGroup.GetCode()`, Handled := true (S:3240-3245). Item UoM / Resource UoM <-> CRM Uom, match field Name/Code -> add extra filter on `UoMScheduleId` of the owning Unit Group; does **not** set Handled (S:3247-3266).

### 1B. CRM Integration Management (codeunit 5330, M)

| # | Subscriber (file:line) | Publisher + event (exact) | Params | Guards | Branches / logic |
|---|---|---|---|---|---|
| M1 | `HandleOnUpdateConflictDetected` M:2645-2678, local | `Codeunit::"Integration Rec. Synch. Invoke"`, `'OnUpdateConflictDetected'` (I:733) | `var IntegrationTableMapping; var SourceRecordRef; var DestinationRecordRef; var UpdateConflictHandled: Boolean; var SkipRecord: Boolean` | exit if handled (M:2648); `IsCDSIntegrationEnabled() or IsCRMIntegrationEnabled()` (M:2651) | `case IntegrationTableMapping."Update-Conflict Resolution"`: "Get Update from Integration" -> handled, skip unless source is integration table (M:2655-2665); "Send Update to Integration" -> handled, skip unless source is local table (M:2666-2676). Generic, no table pair. |
| M2 | `HandleOnDeletionConflictDetected` M:2680-2720, local | `Codeunit::"Integration Rec. Synch. Invoke"`, `'OnDeletionConflictDetected'` (I:738) | `var IntegrationTableMapping; var SourceRecordRef; var DeletionConflictHandled: Boolean` | exit if handled; CDS or CRM enabled (M:2689) | "Remove Coupling": `RemoveCoupling(RecordId,false)` or `RemoveCoupling(TableID, IntTableID, CRMID, false)` (M:2695-2700); **hard-coded pair branch: `"Table ID" = Sales Line` + bidirectional -> `SourceRecordRef.Delete()`** (M:2702-2704). "Restore Records": delete coupling by BC id / CRM id (+ `Commit()` in helpers M:2623-2643) (M:2709-2718). |
| M3 | `HandleCRMRegisterServiceConnection` M:2722-2749, **global** | `Database::"Service Connection"`, `'OnRegisterServiceConnection'` | `var ServiceConnection: Record "Service Connection"` | creates CRM Connection Setup if missing and has write permission (M:2728-2735) | Status Enabled/Disabled/Connected/Error via `TestConnection`; `InsertServiceConnectionExtended` (M:2737-2748). Not synch-engine. |
| M4 | `HandleOnGetIntegrationSolutions` M:2751-2759, local | `Codeunit::"CDS Integration Mgt."`, `'OnGetIntegrationSolutions'` | `var SolutionUniqueNameList: List of [Text]` | CRM `"Is Enabled"` | adds `CRMProductName.UNIQUE()`. |
| M5 | `HandleOnGetIntegrationRequiredRoles` M:2761-2771, local | `Codeunit::"CDS Integration Mgt."`, `'OnGetIntegrationRequiredRoles'` | `var RequiredRoleIdList: List of [Guid]` | CRM `"Is Enabled"` | adds hard-coded role GUIDs (`GetIntegrationAdminRoleID` M:3228-3231, `GetIntegrationUserRoleID` M:3233-3236). |
| M6 | `OnInitializingNotificationWithDefaultState` M:3184-3191, local | `Page::"My Notifications"`, `'OnInitializingNotificationWithDefaultState'` | none | none | inserts 2 default notifications. |
| M7 | `IsDataIntegrationEnabled` M:3617-3624, local | `Database::"Integration Synch. Job Errors"`, `'OnIsDataIntegrationEnabled'` | `var IsIntegrationEnabled: Boolean` | only if not already true | `:= CRMConnectionSetup.IsEnabled()`. |
| M8 | `DisableConnectionOnAfterLongSynchError` M:3626-3643, local | `Database::"Integration Synch. Job Errors"`, `'OnAfterLogSynchError'` | `IntegrationSynchJobErrors: Record "Integration Synch. Job Errors"` | message contains `'CrmCreate'` AND `'prvCreate'` (M:3631-3635); **no CRM-enabled / connection-type check** | `DisableConnection()` (M:3545-3562: `Message`, set Is Enabled false + Disable Reason) then overwrite Disable Reason (M:3639-3642). |
| M9 | `ForceSynchronizeDataIntegration` M:3645-3656, local | `Database::"Integration Synch. Job Errors"`, `'OnForceSynchronizeDataIntegration'` | `LocalRecordID: RecordID; var SynchronizeHandled: Boolean` | handled; CDS or CRM enabled | `UpdateOneNow(LocalRecordID)` (M:603-607 -> `UpdateMultipleNow`), handled := true. |
| M10 | `ForceSynchronizeRecords` M:3658-3682, local | `Database::"Integration Synch. Job Errors"`, `'OnForceSynchronizeRecords'` | `var LocalRecordIdList: List of [RecordId]; var SynchronizeHandled: Boolean` | handled; CDS or CRM enabled | marks matching `CRM Integration Record`s and `UpdateMultipleNow` (M:3671-3681). |
| M11 | `HandleOnOptionDeletionConflictDetected` M:4157-4174, local | `Codeunit::"Int. Option Synch. Invoke"`, `'OnDeletionConflictDetected'` (`IntOptionSynchInvoke.Codeunit.al:379`) | `var IntegrationTableMapping; var SourceRecordRef; var DeletionConflictHandled: Boolean` | handled; CDS or CRM enabled | for both "Remove Coupling" and "Restore Records": delete `CRM Option Mapping` (`RemoveOptionMappingFromRecRef` M:1291-1299 or `RemoveOptionMapping` M:1280-1289). "Restore Records" therefore behaves as remove-coupling for options. |

### 1C. CRM Integration Table Synch. (codeunit 5340, T)

| # | Subscriber | Publisher + event | Params | Guards | Logic |
|---|---|---|---|---|---|
| T1 | `IgnoreCompanyContactOnQueryPostFilterIgnoreRecord` T:980-996, local | `Codeunit::"CRM Integration Table Synch."`, `'OnQueryPostFilterIgnoreRecord'` (self-subscription to own publisher T:935) | `SourceRecordRef: RecordRef; var IgnoreRecord: Boolean` | exit if IgnoreRecord; `SourceRecordRef.Number = Contact`; skip if `CRMSynchHelper.IsContactTypeCheckIgnored()` (T:990, raises `OnGetIsContactTypeCheckIgnored` H:2051) | Ignore Company-type contacts (T:992-994). Parallel to S15's Contact branch - two subscribers on the same event, order undefined. |
| T2 | `OnBeforeModifyJobQueueEntry` T:998-1007, local | `Database::"Job Queue Entry"`, `'OnBeforeModifyEvent'` | `var Rec; var xRec; RunTrigger` | not temporary | delegates to `CRMFullSynchReviewLine.OnBeforeModifyJobQueueEntry(Rec)`. |
| T3 | `OnSynchJobEntryCanBeRemoved` T:1009-1025, local | `Database::"Integration Synch. Job"`, `'OnCanBeRemoved'` | `IntegrationSynchJob; var AllowRemoval: Boolean` | exit if already allowed; **no connection check** | allow removal only if no skipped `CRM Integration Record` references the job id (either direction). |

---

## 2. Helper procedures per branch and their extensibility

Legend: **EXT** = helper raises an IntegrationEvent that lets a partner change/skip it (name given); **after-only** = event exists but cannot suppress; **NONE** = no event.

All events in S are declared `[IntegrationEvent(false, false)] local procedure` (S:3269-3327), so partners can subscribe but there is no sender access.

### 2.1 Whole-subscriber hooks that exist in S
| Event | Declared | Raised | Scope |
|---|---|---|---|
| `OnBeforeGetSourceDestCodeOnAfterTransferRecordFields(var SourceRecordRef; var DestinationRecordRef; var AdditionalFieldsWereModified; DestinationIsInserted; var IsHandled)` | S:3289-3292 | S:451 | Skips **all** S8 branches at once (not per pair). |
| `OnHandleOnBeforeIgnoreUnchangedRecordHandled(SourceRecordRef; DestinationRecordRef; var IsHandled)` | S:3294-3297 | S:893 | Skips all S14 branches. |
| `OnAfterHandlePostFilterIgnoreRecord(SourceRecordRef; var IgnoreRecord)` | S:3324-3327 | S:936 | After-only for S15 (can set IgnoreRecord true, or flip it back to false). |

No equivalent whole-subscriber hook exists for S6, S7, S9, S10, S11, S12, S13, S16, S19, S23.

### 2.2 Per-helper map

| Subscriber / branch | Helper(s) (S line) | Events raised inside (exact) | Extensible? |
|---|---|---|---|
| S6 Sales Invoice Header-CRM Invoice | `CheckItemOrResourceIsNotBlocked` (2713) | `OnCheckItemOrResourceIsNotBlockedOnAfterSalesInvLineLoop(SalesInvLine)` S:2739 - raised **after** `TestField(Blocked,false)` S:2734/2737 | after-only; cannot bypass the blocked test |
| S6 Sales Line-CRM Salesorderdetail | `AddSalesOrderIdToCRMSalesorderdetail` (2743) | none | NONE |
| S6 CRM Salesorderdetail-Sales Line | `AddDocumentNoToSalesOrderLine` (2763), `AddTypeToSalesOrderLine` (2873) | none | NONE |
| S6 CRM Salesorder-Sales Header | inline Status := Open (S:265-267) | none | NONE |
| S7 a/d write-in | `AddWriteInProductNo` (2783), `AddWriteInSalesorderdetail` (2799) | none | NONE (only by pre-empting via own `OnTransferFieldData` subscriber that sets IsValueFound, order-dependent) |
| S7 b/c LCY currency | inline (S:312-342) | none | NONE |
| S7 e OwnerId | inline + `CRMSynchHelper.GetCoupledCDSUserId` (H:1628) | none found | NONE |
| S7 f/g option<->table | `CRMSynchHelper.ConvertTableToOption` (H:1917), `ConvertOptionToTable` (H:1937) | `OnConvertOptionToTableOnBeforeSetRangeForIntegrationFieldID` (H:1956, IsHandled on the SetRange only) | partial (g only) |
| S7 h | `ShouldKeepOldValue` (431) | none | NONE |
| S7 i | `CRMSynchHelper.FindNewValueForSpecialMapping` (H:1995, internal) | none | NONE |
| S7 j unit group | `ConvertBaseUnitOfMeasureToUomId`, `ConvertUomIdToBaseUnitOfMeasure`, `PrefixUnitGroupCode` (H) | none | NONE |
| S7 k coupled FK | `CRMSynchHelper.AreFieldsRelatedToMappedTables` (H:1596) -> `GetFieldRelation` raises `OnAfterGetFieldRelation(RecRef, FldRef, var TableID)` (H:1891); `FindNewValueForCoupledRecordPK` (3148) raises `OnFindNewValueForCoupledRecordPK(IntegrationTableMapping, SourceFieldRef, DestinationFieldRef, var NewValue, var IsValueFound)` (S:3154) | EXT (both) |
| S8 CRM Account-Customer | `UpdateCustomerBlocked` (1179) | none | only via whole-subscriber IsHandled (S:451) |
| S8 Sales Price / Price List Line -> Productpricelevel | `UpdateCRMProductPricelevelAfterTransferRecordFields[PriceListLine]` (1896/1913) -> `FindCRMUoMIdForSalesPrice` (2610) | none | whole-subscriber only |
| S8 Currency-CRM Transactioncurrency | `UpdateCRMTransactionCurrencyAfterTransferRecordFields` (2115) -> `GetCRMLCYToFCYExchangeRate` (H:568) -> `GetCRMBaseCurrencyId` raises `OnGetCDSBaseCurrencyId` (H:539) | value source only | whole-subscriber + base currency id |
| S8 Item/Resource-CRM Product | `UpdateCRMProductAfterTransferRecordFields` (1933) | `OnUpdateCRMProductAfterTransferRecordFieldsOnAfterCalcItemBlocked(SourceRecordRef, var Blocked)` S:1948 (**Item only**, not Resource) | partial |
| S8 CRM Product-Item / -Resource | `UpdateItemAfterTransferRecordFields` (2073), `UpdateResourceAfterTransferRecordFields` (2089) | none | whole-subscriber only |
| S8 UoM-CRM Uomschedule / Unit Group-CRM Uomschedule | `UpdateCRMUoMScheduleAfterTransferRecordFields` (2211), `ValidateCRMUoMSchedule` (2392), `CheckCRMUoMScheduleAfterTransferRecordFields` (2245) | none | whole-subscriber only |
| S8 Item/Resource UoM-CRM Uom | `UpdateCRMUomFrom{Item,Resource}AfterTransferRecordFields` (2260/2307), `CoupleAndSyncUnitGroup` (2354) -> `SynchRecordsToIntegrationTable` raises `OnBeforeSynchRecordsToIntegrationTable` (T:496) | whole-subscriber only |
| S8 Sales Line <-> Salesorderdetail | `UpdateCRMSalesorderdetailUom` (2970), `UpdateSalesLineUnitOfMeasure` (2909), `UpdateSalesLinePriceOverride` (2956) | none | whole-subscriber only |
| S9/S11 CRM Contact-Contact | `UpdateContactParentCompany` (1200) -> `CRMSynchHelper.SetContactParentCompany` (H:672) raises `OnFailedFindContactByAccountId` (H:686); `IsContactBusinessRelationOptional` raises `OnGetIsContactBusinessRelationOptional` (H:2041) | partial (failure fallback + optional flag) |
| S9/S11 Contact-CRM Contact | `UpdateCRMContactParentCustomerId` (1328), `FindParentCRMAccountForContact` (2422) | `OnGetIsContactBusinessRelationOptional` only (silences errors) | partial |
| S9 Currency-CRM Transactioncurrency | `UpdateCRMTransactionCurrencyBeforeInsertRecord` (2105) -> `GetCRMCurrencyDefaultPrecision` raises `OnGetCDSCurrencyDecimalPrecision` (H:524) | value source only |
| S9/S11 Customer Price Group / Price List Header -> CRM Pricelevel | `UpdateCRMPricelevelBefore{Insert,Modify}*` (1601/1623/1655/1670), `CheckCustPriceGroupForSync` (2688), `CheckPriceListHeaderForSync` (2701), `CheckSalesPricesForSync` (2654), `CheckPriceListLinesForSync` (2669), `FindCRMProductIdForItem/Resource` (2568/2589) | none | NONE |
| S9 Item/Resource-CRM Product | `UpdateCRMProductBeforeInsertRecord` (2062) | none | NONE |
| S9 Sales Invoice Header-CRM Invoice | `CheckSalesInvoiceLineItemsAreCoupled` (1346), `FindCRMProductId` (2541) | none | NONE (includes a `Commit()` S:1373) |
| " | `UpdateCRMInvoiceBeforeInsertRecord` (1471) | `OnBeforeUpdateCRMInvoiceBeforeInsertRecord(SourceRecordRef, DestinationRecordRef, var IsHandled)` S:1487; `OnUpdateCRMInvoiceBeforeInsertRecordOnBeforeDestinationRecordRefGetTable(var CRMInvoice, SalesInvoiceHeader)` S:1517 (only on the "linked CRM order" path) | EXT |
| S9 Opportunity-CRM Opportunity | `UpdateOwnerIdAndCompanyId` (1148) | none | NONE |
| S9 Sales Invoice Line-CRM Invoicedetail | `UpdateCRMInvoiceDetailsBeforeInsertRecord` (1566), `InitializeCRMInvoiceLineFrom*` (2443-2488), `InitializeCRMInvoiceLineWithProductDetails` (2490), `CRMSynchHelper.CreateCRMProductpriceIfAbsent` | none | NONE |
| S9 Sales Header-CRM Salesorder | `UpdateCRMSalesOrderPriceList` (3017), `SetCompanyId` (1161), `SetCRMOrderName` (3048), `SetDocOccurenceNumber` (3060/3073 public), `CDSIntTableSubscriber.SetOwnerId` | none | NONE |
| S9 CRM Salesorder-Sales Header | `UpdateSalesOrderQuoteNo` (3123) | `OnBeforeFindQuoteSalesHeader(var QuoteSalesHeader)` S:3138; `OnAfterArchSalesDocumentNoConfirm(var QuoteSalesHeader)` S:3142 | partial (filter + after archive; cannot skip archiving) |
| S9/S11 Sales Line-CRM Salesorderdetail | `SetWriteInProduct` (3105) none; `ApplySalesLineTax` (1828) raises `OnApplySalesLineTaxOnBeforeSetTax(var CRMSalesorderdetail, var SalesLine, var IsHandled)` S:1838 | tax: EXT; write-in: NONE |
| S9 dest Salesperson/Purchaser | `UpdateSalesPersOnBeforeInsertRecord` (1304) | none | NONE |
| S10 Price group/list -> Pricelevel | `ResetCRMProductpricelevelFrom{CustomerPriceGroup,PriceListHeader}` (1685/1702) -> `SynchRecordsToIntegrationTable` raises `OnBeforeSynchRecordsToIntegrationTable(..., var IsHandled)` (T:496) | indirect EXT (generic, not pair-specific) |
| S10 Item/Resource-CRM Product | `UpdateCRMProductAfterInsertRecord` (2008) | none | NONE |
| S10 Sales Invoice Header-CRM Invoice | `UpdateCRMInvoiceAfterInsertRecord` (1386) -> `CRMSynchHelper.UpdateCRMInvoiceStatus` (H:734) -> `UpdateCRMInvoiceStatusFromEntry` raises `OnUpdateCRMInvoiceStatusFromEntryOnBeforeCheckFieldsChanged` (H:770), `OnUpdateCRMInvoiceStatusFromEntryOnBeforeModify` (H:775), `CalculateActualStatusCode` raises `OnBeforeCalculateActualStatusCode(..., IsHandled)` (H:788); lines via `SynchRecordsToIntegrationTable` (T:496). Totals calc (S:1406-1424) has **no** event. `UpdatePricesIncludeVATRounding` (1429) none. | status: EXT; totals/rounding: NONE |
| S10 Sales Invoice Line-CRM Invoicedetail | `UpdateCRMInvoiceDetailsAfterInsertRecord` (1546) | none | NONE |
| S10 Item/Resource UoM-CRM Uom | `UpdateCRMUomFrom{Item,Resource}AfterInsertRecord` (2022/2042) | none | NONE |
| S10/S12/S13/S14 Sales Header-CRM Salesorder | `ResetCRMSalesorderdetailFromSalesOrderLine` (1718; nested sync -> T:496), `SetCRMSalesOrderStateCode` (747) -> `CRMSynchHelper.FulfillSalesOrder` raises `OnBeforeFulfillSalesOrder(SalesOrderId)` (H:2094, notify-only, no IsHandled) / `ChangeSalesOrderStateCode` (697) none; `SubmitOrInvoiceSalesOrder` (761) none | mostly NONE |
| S10/S12/S13/S14 CRM Salesorder-Sales Header | `ResetSalesOrderLineFromCRMSalesorderdetail` (1766; nested sync -> `OnBeforeSynchRecordsFromIntegrationTable` T:525), `ApplySalesOrderDiscounts` (1847) none, `CreateFreightLines` (1868) none, `SetSalesOrderStatus` (733)/`ChangeValidateSalesOrderStatus` (774)/`ChangeSalesOrderStatus` (714) raise `OnChangeSalesOrderStatusOnBeforeCompareStatus(var SalesHeader, var NewSalesDocumentStatus)` (S:724, S:785), `SetOrderNumberAndDocOccurenceNumber` (3090) none, `CreateSalesOrderNotes` (2813)/`CreateNote` (2852) none | status: EXT (can change target status); rest NONE |
| S10 CRM Product-Item/Resource | `CreateUnitGroupAndItemUnitOfMeasure` (603), `CreateUnitGroupAndResourceUnitOfMeasure` (650) | none (nested sync -> T:496) | NONE |
| S10 CRM Salesorderdetail-Sales Line | `AutoReserveSalesLine` (3194) | none | NONE |
| S12 dest Customer | `CRMSynchHelper.UpdateContactOnModifyCustomer` (H:1137) | none found | NONE |
| S15 branches | `Handle*QueryPostFilterIgnoreRecord` / `Ignore*OnQueryPostFilterIgnoreRecord` (939-1302) | Contact: `OnGetIsContactBusinessRelationOptional` (H:2041) (switch only; `FindContactRelatedCustomer/Vendor` not inspected for events); all: after-hook `OnAfterHandlePostFilterIgnoreRecord` (S:936). `Sales Invoice Line` -> `Error` (S:923) **before** after-hook. | after-only |
| S16 branches | `CRMUoMScheduleFindUncoupledDestinationRecord` (2363), `CRMTransactionCurrencyFindUncoupledDestinationRecord` (2136), `CRMPriceListLineFindUncoupledDestinationRecord` (2152), `CRMExtPriceListLineFindUncoupledDestinationRecord` (2176) | none | Partner can pre-empt only by subscribing to the engine event and setting `DestinationFound` first (order not guaranteed) |
| S19 | `RemoveChildCouplings` (1111), `GetCoupledSalesLines` (1119) | none | NONE |
| S23 | inline | none | NONE |
| M1 | inline | none | NONE (pre-empt via `UpdateConflictHandled` only) |
| M2 | `RemoveCoupling` overloads (M:1396, M:1421), `DeleteIntegrationRecordByBCID/CRMID` (M:2623/2633) | none in shown code | NONE |
| M8 | `DisableConnection` (M:3545) | none | NONE |
| M11 | `RemoveOptionMapping*` (M:1280/1291) | none | NONE |

---

## 3. Not extensible today (concrete, file:line)

1. **Table-pair routing itself.** The pair set is a closed `case` over literal strings built from `RecordRef.Name()` (S:1172-1177; e.g. S:253-269, 455-497, 506-550, 559-600, 803-828, 836-855, 867-883, 897-908, 1006-1013). A partner cannot add a pair to, remove a pair from, or replace the behaviour of one pair without suppressing others. The `IntegrationTableMapping` passed by the engine (I:763-808) is never used to route, so a second mapping between the same tables (e.g. a custom "Sales Header-CRM Salesorder" variant) gets the same hard-coded logic.
2. **No per-pair IsHandled in S6 `OnBeforeTransferRecordFields`** (S:247-270): blocked-item test (S:2734, 2737), sales order line ID/doc no./type (S:2743-2781, 2873-2907), forced Status := Open (S:265-267).
3. **S7 `OnTransferFieldData`** (S:272-429): no event before/after; ordering of rules a-k is fixed; LCY currency translation (S:312-342), OwnerId Team/Person rule (S:352-373), keep-old-OwnerId (S:389-394, S:431-444), unit-group conversions (S:402-422), write-in product mapping (S:304-310, 344-350) are all closed. Field matching by **name** (`'OwnerId'` S:352, `FieldName(TransactionCurrencyId)` S:312/328) is hard-coded. The CDS exclusion list `[Customer, Vendor, Currency, Contact, Salesperson/Purchaser]` (S:300-301) is hard-coded.
4. **S8 per-pair after-transfer logic** can only be skipped all-or-nothing via `OnBeforeGetSourceDestCodeOnAfterTransferRecordFields` (S:451); individually not extensible: `UpdateCustomerBlocked` (S:1179-1198, only Inactive->Blocked::All), price level UoM (S:1896-1931), exchange rate (S:2115-2134), CRM Product enrichment except Item.Blocked (S:1960-2005), Item/Resource Blocked from StateCode (S:2073-2103), UoM schedule naming "NAV ..." and single-unit rule (S:2211-2258, 2392-2420), sales line UoM/price override (S:2909-3015).
5. **S9 `OnBeforeInsertRecord`**: contact parent customer (S:1328-1344), price level validation incl. `TestField("Currency Code")` (S:2654-2711), CRM Product defaults (S:2062-2071), invoice line coupling check with `Commit()` (S:1346-1384), invoice detail initialization (S:1566-1599, 2443-2539) incl. `Sleep(5000)` retry (S:1582), opportunity owner (S:1650-1653), sales order price list / name / doc occurrence / owner (S:529-536, 3017-3088), write-in product (S:3105-3121), Salesperson code generation `SP NO. n` (S:1304-1326). Only `UpdateCRMInvoiceBeforeInsertRecord` (S:1487) and sales line tax (S:1838) have IsHandled.
6. **S10 `OnAfterInsertRecord`**: invoice totals calculation and the two `Commit()`s (S:1397, 1406-1426), VAT rounding write-in line (S:1429-1469), invoice detail amounts (S:1546-1564), CRM product activation (S:2008-2020), auto-create Unit Group / base UoM for CRM products (S:603-695), sales order discount application (S:1847-1866), freight line creation (S:1868-1894), CRM order number write-back (S:3090-3103), notes import (S:2813-2871), auto-reserve (S:3194-3201).
7. **S11/S12 modify path**: unidirectional order state transitions Active/Submitted/Invoiced (S:820, 846, 697-712, 761-772) - direct `Get`+`Modify` on CRM outside the engine; price level `TestField(TransactionCurrencyId)` (S:1665, 1680); `UpdateContactOnModifyCustomer` for any source into Customer (S:857-858).
8. **S13/S14 unchanged path**: forced re-open of BC order (S:877, 903) and line re-sync - S13 has no hook at all; S14 has only whole-subscriber IsHandled (S:893).
9. **S15 post-filter**: `Error(CannotSynchOnlyLinesErr)` for Sales Invoice Line (S:923) fires before `OnAfterHandlePostFilterIgnoreRecord`, so it cannot be overridden; dispatch is by source table only, so a partner mapping a custom CRM entity from Contact/Item/Resource/Sales Header inherits these filters. T1 Company-contact filter (T:989-995) has only a boolean switch (`OnGetIsContactTypeCheckIgnored`).
10. **S16 uncoupled-destination matching** (S:1006-1022): currency ISO match, UoM schedule match, product price level match - no event; only engine-level pre-emption.
11. **S19 child uncouple** (S:1111-1146): Sales Line cascade hard-coded to CRM Salesorder.
12. **S23 matching filter** (S:3240-3266): Unit Group / UoM matching filter hard-coded and does not respect an incoming `SetMatchingFilterHandled = true`.
13. **M2 deletion conflict**: hard-coded `Sales Line` + bidirectional -> delete local record (M:2702-2704) with no event.
14. **M8**: substring-based auto-disable of the whole connection on `'CrmCreate'`+`'prvCreate'` (M:3631-3642) - no event, no connection-type check, issues `Message` (M:3553).
15. **M11**: "Restore Records" for option mappings simply removes the mapping (M:4168-4173).
16. **S1/S3 job orchestration**: CRM job detection list (S:185-225) and the "needs to run" probe (S:146-168) are hard-coded to specific codeunit IDs.
17. **S18 telemetry** list of CRM tables (S:1053-1063) - harmless, but closed.

---

## 4. State, SingleInstance, manual binding

* **codeunit 5341 "CRM Int. Table. Subscriber" is `SingleInstance = true`** (S:39). Globals (S:45-50): `CRMSynchHelper: Codeunit "CRM Synch. Helper"`, `CRMProductName: Codeunit "CRM Product Name"`, `CDSIntegrationImpl: Codeunit "CDS Integration Impl."`, `CRMIntegrationManagement: Codeunit "CRM Integration Management"`, `PrepaymentMgt: Codeunit "Prepayment Mgt."`; rest are Labels (S:52-93). No record/boolean state of its own.
  * Because 5341 is single-instance, its `CRMSynchHelper` global (not itself single-instance) lives for the session and carries the helper's temp-table caches: `TempCRMPricelevel`, `TempCRMTransactioncurrency`, `TempCRMUom`, `TempCRMUomschedule` (H:41-44). `ClearCache()` (S:95-98 -> H:80+) is the only reset.
  * Cache reset path: `CRMIntegrationTableSynch.ClearCache()` (T:140-145) calls `CRMIntTableSubscriber.ClearCache()` then `Clear(CRMIntTableSubscriber)` - `Clear` on a single-instance codeunit variable does not discard the instance, so the explicit `ClearCache()` is what matters. `ClearCache` is called from `InitConnection` (T:96) and `CloseConnection` (T:131), i.e. per scheduled `OnRun` of T (T:34, T:54). Ad-hoc paths (`SynchRecord` T:474, `SynchRecordsToIntegrationTable` T:489, `SynchRecordsFromIntegrationTable` T:518, which the subscribers call recursively) do **not** clear it.
  * Many local procedures also instantiate `CRMIntegrationTableSynch` locally to run nested synchs from inside a subscriber (S:611/631/644, 658/678/691, 1392/1404, 1689/1698, 1706/1714, 1727/1756, 1777/1824, 2356/2360) - re-entrancy into the engine from within engine events.
* **codeunit 5330 "CRM Integration Management" is `SingleInstance = true`** (M:40). Session state (M:52-100): `CachedCoupledToCRMFieldNo: Dictionary of [Integer, Integer]` (M:55), `CachedDisableEventDrivenSynchJobReschedule: Dictionary of [Integer, Boolean]` (M:56), `CachedIsCRMIntegrationRecord: Dictionary of [Integer, Boolean]` (M:57), `CachedDoesJobActOnTable: Dictionary of [Text, Boolean]` (M:58), `CRMIntegrationEnabledState` / `CDSIntegrationEnabledState` options (M:97-98), `CRMIntegrationEnabledLastError: Text` (M:100). `IsCRMIntegrationEnabled()` caches the enabled state for the session (M:179-194; reset only by `ClearState()` M:2773-2776). `IsCDSIntegrationEnabled()` is not cached; it re-raises `OnIsCDSIntegrationEnabled` + `OnInitCDSConnection` on every call (M:203-205) - and S7 calls it up to 2x per field (S:292, S:299).
  * Note: S holds `CRMIntegrationManagement` as a global (S:49), but since 5330 is single-instance, all callers share the same state anyway.
* **codeunit 5340 "CRM Integration Table Synch."** is not single-instance; globals: `CRMIntTableSubscriber` (T:58), `MappedFieldDictionary: Dictionary of [Text, Boolean]` (T:61, BLOB-field-mapped cache per instance), `OutOfMapFilter: Boolean` (T:64, set as side effect of `GetSourceRecordRef` T:358/367 and read via `GetOutOfMapFilter` T:338-341).
* **Manual subscriber binding:** `BindSubscription(IntTableManualSubscribers)` / `UnbindSubscription` around the scheduled loops in `SynchNAVTableToCRM` (T:558, T:579) and `SynchCRMTableToNAV` (T:616, T:641). `IntTableManualSubscribers` is codeunit 5368 "Int. Table Manual Subscribers", `EventSubscriberInstance = Manual` (`Integration\SynchEngine\IntTableManualSubscribers.Codeunit.al:9-11`) with one subscriber: `Database::Item`, `'OnValidateBaseUnitOfMeasure'` -> `ValidateBaseUnitOfMeasure := true` (same file :13-17). It is **not** bound for ad-hoc `SynchRecord*` calls or option synchs. No other `BindSubscription` in S, M or T.
* **Commits inside subscribers:** S:1373 (OnBeforeInsert invoice), S:1397 and S:1426 (OnAfterInsert invoice), M:2629/M:2641 (deletion-conflict restore). These constrain any transactional redesign.
* **Duplicate subscribers to the same event (undefined order):** `OnQueryPostFilterIgnoreRecord` - S:911 and T:980; `OnTransferFieldData` - S:272 and `CDSIntTableSubscriber.Codeunit.al:262` (coordinated only by the CDS table exclusion list S:299-302); `OnAfterUnchangedRecordHandled` - S:861 and `CDSIntTableSubscriber.Codeunit.al:982`.
* **Public surface of subscriber procedures:** S6-S13, S15-S17 are declared `procedure` (global), not `local`, so they can be invoked directly (S:248, 273, 447, 501, 554, 798, 832, 862, 912, 997, 1026); also public helpers `MarkArchivedSalesOrder` (S:1097), `SetDocOccurenceNumber(var CRMSalesorder; var SalesHeader)` (S:3073), `ClearCache` (S:95). Any redesign must keep or obsolete these.
