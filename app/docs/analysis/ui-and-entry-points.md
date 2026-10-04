# Dataverse / D365 Sales / Field Service: UI and other non-engine entry points (BC 29)

Scope: everything that is **not** a synch-engine event subscriber (those are in `subscribers-crm.md`, `subscribers-cds.md`, `subscribers-fs.md`). That means the page actions, factboxes and indicators, the management procedures those actions call, and the other entry points (redirect, coupling dialog, match-based coupling, create flows, statistics, full synch, option mapping, setup pages, lookups).

Paths are relative to `src\base`. Paths starting with `fs:` are relative to `src\fs\src`. File abbreviations:

| Abbrev | File | Object |
|---|---|---|
| **M** | `Integration\Dataverse\CRMIntegrationManagement.Codeunit.al` | codeunit 5330 "CRM Integration Management" |
| **CM** | `Integration\Dataverse\CRMCouplingManagement.Codeunit.al` | codeunit 5331 "CRM Coupling Management" (158 lines) |
| **CRB** | `Integration\Dataverse\CouplingRecordBuffer.Table.al` | table "Coupling Record Buffer" |
| **CRP** | `Integration\Dataverse\CRMCouplingRecord.Page.al` | page 5336 "CRM Coupling Record" |
| **CIR** | `Integration\Dataverse\CRMIntegrationRecord.Table.al` | table "CRM Integration Record" |
| **LT** | `Integration\Dataverse\LookupCRMTables.Codeunit.al` | codeunit 5332 "Lookup CRM Tables" |
| **SD** | `Integration\D365Sales\CRMSetupDefaults.Codeunit.al` | codeunit "CRM Setup Defaults" |
| **ITM** | `Integration\SynchEngine\IntegrationTableMapping.Table.al` | table "Integration Table Mapping" |
| **FSR** | `fs:Codeunits\FSIntTableSubscriber.Codeunit.al` | FS Int. Table Subscriber |

---

## 0. Key findings (read first)

1. **No page action uses the mapping Direction for visibility.** I searched every page and pageextension for `.Direction` and `Direction::` (base + fs). The only Direction-dependent UI is:
   * `Integration\SynchEngine\IntegrationTableMappingList.Page.al:333`: `UnconditionalSynchronizeAll` has `Enabled = HasRecords and (Rec."Parent Name" = '') and (Rec.Direction <> Rec.Direction::Bidirectional)`.
   * `Integration\SynchEngine\MatchBasedCouplingCriteria.Page.al:180,183`: field visibility only (`ConflictResolutionControlVisible := Direction = Bidirectional`; `CreateNewInCaseOfNoMatchControlVisible := Direction <> FromIntegrationTable`, with the overridable event `ITM:1230 OnIsCreateNewInCaseOfNoMatchControlVisible`).
   * `Integration\SynchEngine\IntegrationFieldMappingList.Page.al:70` (Transformation Direction editable only for Bidirectional field mappings), and `Integration\Dataverse\CRMCouplingFields.Page.al:80-99` (column order in the coupling dialog).
   
   Every "Open in Dataverse" (`ShowCRMEntityFromRecordID`), "Synchronize" (`UpdateOneNow`/`UpdateMultipleNow`), "Set Up Coupling", "Match-Based Coupling", "Delete Coupling", "Synchronization Log", "Create ... in Dataverse" and "Create ... in Business Central" action is shown regardless of Direction. Visibility is driven only by `IsCRMIntegrationEnabled()` / `IsCDSIntegrationEnabled()` / `FSConnectionSetup.IsEnabled()` (plus record-state Enabled expressions).
2. **Direction is honoured only *inside* the Synchronize procedure, as a prompt.** `M:2479-2511 GetSelectedMultipleSyncDirection` and `M:2513-2621 GetSelectedSingleSyncDirection` read `IntegrationTableMapping.Direction`. For Bidirectional mappings they offer a StrMenu: multi-record shows 'Send…,Get…' (M:65, M:2492); single-record shows 'Send…,Get…,Merge data.' (M:66, M:2590). For uni-directional mappings they ask a Confirm for the allowed direction only (M:2497-2510, M:2601-2620). So "Synchronize" on a FromIntegrationTable mapping is still *visible*, but it only pulls.
3. **The coupling dialog does not honour Direction.** `CRB:206-209` picks the default "Sync Action" from the hard-coded `SD:2273-2307 GetDefaultDirection(NAVTableID)` (per BC table, with `OnBeforeGetDefaultDirection` IsHandled), not from the mapping. The user can choose either "Use the Business Central data" or "Use the Dataverse data" (`CRP:47`). `M:1694-1707 EnqueueSyncJob` then overwrites `IntegrationTableMapping.Direction := Direction` on the temporary child mapping. The result is that a one-way mapping can be synchronized the other way from the coupling dialog. Options are the exception: they use the mapping direction through `ITM:453 GetDirection()` (`CRB:217-221`).
4. **The mapping is found by BC table ID, not by mapping name.** `M:1564-1576 GetIntegrationTableMapping(…, TableID)` filters `Type = Dataverse`, `"Synch. Codeunit ID" = CRM Integration Table Synch.`, `"Delete After Synchronization" = false` and `"Table ID"` (or `"Integration Table ID"` for CRM tables), then calls `FindFirst()`. Coupling and uncoupling use the same pattern with `"Coupling Codeunit ID"` and `"Uncouple Codeunit ID"` (`M:1527-1553`). When two mappings share a BC table (Resource has `RESOURCE-PRODUCT` from `SD:75` and `RESOURCE-BOOKABLERSC` from `fs:Codeunits\FSSetupDefaults.Codeunit.al:60`, both with synch codeunit "CRM Integration Table Synch." per `fs:…FSSetupDefaults.Codeunit.al:1054`), the first one by Name (`RESOURCE-BOOKABLERSC`) is used. This applies whether the user clicked the D365 Sales group or the Field Service group. `CIR:388 IsRecordCoupled` does not know the integration table either: CIR has no Integration Table ID column (fields `CIR:20-107`, key `"CRM ID","Integration ID"` `CIR:116`).
5. **Hard-coded mapping names and filter strings on pages:**
   * `IntegrationTableMapping.Get('CUSTOMER')` + `Contains('Field39=1(0)')` (Customer Card and List)
   * `Get('VENDOR')` + `'Field39=1(0)'` (Vendor Card and List)
   * `Get('ITEM-PRODUCT')` + `'Field54=1(0)'` (Item Card and List)
   * `Get('RESOURCE-PRODUCT')` + `'Field38=1(0)'` (Resource Card and List)
   * `Get('PLHEADER-PRICE')` + `'Field20=1(1)'` (Sales Price List, Sales Price Lists)
   * FS: mapping found by table pair Resource/FS Bookable Resource + `'Field38=1(0)'`, and Service Item/FS Customer Asset + `'Field40=1(0)'`
   * `'SALESORDER-ORDER'` in the Integration Table Mapping List Match-Based Coupling Enabled expression
   * mapping-name lists in `Integration\Dataverse\CRMFullSynchReviewLine.Table.al:186-199`
6. **No master-data page action can be fully taken over.** None of `ShowCRMEntityFromRecordID`, `UpdateOneNow`/`UpdateMultipleNow`, `DefineCoupling`, `MatchBasedCoupling`, `RemoveCoupling`, `ShowLog`, `CreateNewRecordsInCRM`, `CreateNewRecordsFromCRM` or `CreateOrUpdateCRMAccountStatistics` raises an OnBefore…IsHandled event. The only levers are:
   * mapping-selection events (`OnBeforeGetIntegrationTableMapping*`, not IsHandled, see B.0)
   * `OnBeforeSynchronyzeNowQuestion` (skips the confirm only)
   * `OnGetCDSServerAddress` / `OnAfterGetCRMEntityUrlFromCRMID` (URL)
   * `OnLookupCRMTables` / `OnLookupCRMOption` (the lookup inside the coupling dialog)
   * `OnBeforeOpenCoupledNavRecordPage` / `OnBeforeOpenRecordCardPage` (redirect)

---

## A. Pages with Dataverse / CRM / FS actions

Notation per action: `Name` "Caption" calls `procedure` [Visible / Enabled]. **G** = the enclosing action group. "CRMEnabled" = `CRMIntegrationManagement.IsCRMIntegrationEnabled()` (M:172-195). "CDSEnabled" = `IsCDSIntegrationEnabled()` (M:197-211). "Coupled" = `CRMCouplingManagement.IsRecordCoupledToCRM(Rec.RecordId)` (CM:19-24, which calls CIR:388, any CIR row for SystemId + Table ID). Unless noted, action-level Visible is absent, so it inherits **G**. The promoted `Category_Synchronize`/`Category_Coupling` groups only hold actionrefs.

### A.1 Master data: cards

| Page | Table / mapping | Group G (Visible / Enabled) | Actions (OnAction calls) | How the flags are computed |
|---|---|---|---|---|
| 21 "Customer Card" `Sales\Customer\CustomerCard.Page.al` (Card) | Customer / `CUSTOMER` | `ActionGroupCRM` "Dataverse" 1165-1271: Visible `CRMIntegrationEnabled or CDSIntegrationEnabled` (1169); Enabled `(BlockedFilterApplied and (Rec.Blocked = Rec.Blocked::" ")) or not BlockedFilterApplied` (1168) | `CRMGotoAccount` "Account" calls `ShowCRMEntityFromRecordID` (1182) [V CRM or CDS 1176]; `CRMSynchronizeNow` "Synchronize" calls `UpdateOneNow` (1198) [V 1192]; `UpdateStatisticsInCRM` "Update Account Statistics" calls `CreateOrUpdateCRMAccountStatistics(Rec)` (1214) [V `CRMIntegrationEnabled` 1208, E Coupled 1205]; sub-group `Coupling` 1217-1255: `ManageCRMCoupling` "Set Up Coupling" calls `DefineCoupling` (1235) [V 1229], `DeleteCRMCoupling` "Delete Coupling" calls `CRMCouplingManagement.RemoveCoupling(Rec.RecordId)` (1252) [V 1246, E Coupled 1243]; `ShowLog` "Synchronization Log" calls `ShowLog` (1268) [V 1262]. Promoted `Category_Synchronize` V CRM or CDS (2336). | OnOpenPage 2442: CRM/CDS flags at 2464-2465; `if IntegrationTableMapping.Get('CUSTOMER') then BlockedFilterApplied := GetTableFilter().Contains('Field39=1(0)')` (2467-2468). OnAfterGetCurrRecord 2366: if CRM or CDS, Coupled (2396) + `SendResultNotification(Rec)` when the record changes (2398). **Factbox** `part(Control39; "CRM Statistics FactBox")` 969-974, Visible `CRMIsCoupledToRecord` only (973). This is also true on a CDS-only setup, where the factbox fields return 0 (M:2436). |
| 26 "Vendor Card" `Purchases\Vendor\VendorCard.Page.al` | Vendor / `VENDOR` | `ActionGroupCDS` "Dataverse" 1021-1107: V `CRMIntegrationEnabled or CDSIntegrationEnabled` (1025); E Blocked filter (1026) | `CDSGotoAccount` "Account" calls `ShowCRMEntityFromRecordID` (1038); `CDSSynchronizeNow` calls `UpdateOneNow` (1053); `ManageCDSCoupling` calls `DefineCoupling` (1073); `DeleteCDSCoupling` calls `CRMCouplingManagement.RemoveCoupling(RecordId)` (1089) [E Coupled 1081]; `ShowLog` calls `ShowLog` (1104) | OnOpenPage 1811: flags 1828-1829, `Get('VENDOR')` + `'Field39=1(0)'` (1831-1832). OnAfterGetCurrRecord 1758: Coupled only if CRM or CDS (1789-1791). |
| 5050 "Contact Card" `CRM\Contact\ContactCard.Page.al` (ListPlus) | Contact / `CONTACT` | `ActionGroupCRM` "Dataverse" 580-665: V CRM or CDS (584); E `(Rec.Type <> Rec.Type::Company) and (Rec."Company No." <> '')` (583) | `CRMGotoContact` calls `ShowCRMEntityFromRecordID` (596); `CRMSynchronizeNow` calls `UpdateOneNow` (611); `ManageCRMCoupling` calls `DefineCoupling` (631); `DeleteCRMCoupling` calls `CM.RemoveCoupling(RecordId)` (647) [E Coupled 639]; `ShowLog` (662) | OnOpenPage 1485: flags 1492-1493. OnAfterGetCurrRecord 1435: Coupled 1440. |
| 5116 "Salesperson/Purchaser Card" `CRM\Team\SalespersonPurchaserCard.Page.al` | Salesperson/Purchaser / `SALESPEOPLE` | `ActionGroupCRM` "Dataverse" 218-302: V `CDSIntegrationEnabled or CRMIntegrationEnabled` (221) | `CRMGotoSystemUser` "User" (233); `CRMSynchronizeNow` calls `UpdateOneNow` (248); `ManageCRMCoupling` calls `DefineCoupling` (268); `DeleteCRMCoupling` calls `CM.RemoveCoupling` (284) [E Coupled 276]; `ShowLog` (299) | OnOpenPage 455: 457-458. OnAfterGetCurrRecord 438: 443. |
| 495 "Currency Card" `Finance\Currency\CurrencyCard.Page.al` | Currency / `CURRENCY` | `ActionGroupCRM` "Dataverse" 277-378: V CRM or CDS (281) | `CRMGotoTransactionCurrency` (293); `CRMSynchronizeNow` calls `UpdateOneNow`/`UpdateMultipleNow` on the selection (312-319); `ManageCRMCoupling` calls `DefineCoupling` (342); `DeleteCRMCoupling` calls `CM.RemoveCoupling` (360) [E Coupled 350]; `ShowLog` (375) | OnOpenPage 466: 468-469; OnAfterGetCurrRecord 455: 460. |
| 30 "Item Card" `Inventory\Item\ItemCard.Page.al` | Item / `ITEM-PRODUCT` | `ActionGroupCRM` "Dynamics 365 Sales" 1777-1871: V `CRMIntegrationEnabled` (1780); E `(BlockedFilterApplied and (not Rec.Blocked)) or not BlockedFilterApplied` (1781) | `CRMGoToProduct` "Product" (1793); `CRMSynchronizeNow` calls `UpdateOneNow` (1817); `ManageCRMCoupling` calls `DefineCoupling` (1837); `DeleteCRMCoupling` calls `CM.RemoveCoupling` (1853) [E Coupled 1845]; `ShowLog` (1868) | OnOpenPage 2491: CRM only (2513); `Get('ITEM-PRODUCT')` + `'Field54=1(0)'` (2515-2516). OnAfterGetCurrRecord 2432: 2449. |
| 76 "Resource Card" `Projects\Resources\Resource\ResourceCard.Page.al` | Resource / `RESOURCE-PRODUCT` | `ActionGroupCRM` "Dynamics 365 Sales" 356-450: V `CRMIntegrationEnabled` (359); E Blocked (360) | `CRMGoToProduct` (372); `CRMSynchronizeNow` calls `UpdateOneNow` (396); `ManageCRMCoupling` calls `DefineCoupling` (416); `DeleteCRMCoupling` calls `CM.RemoveCoupling` (432) [E Coupled 424]; `ShowLog` (447) | OnOpenPage 732: 736; `Get('RESOURCE-PRODUCT')` + `'Field38=1(0)'` (737-738). OnAfterGetCurrRecord 721: 726. When FS is also enabled the procedures still resolve `RESOURCE-BOOKABLERSC` first (see 0.4). |
| 7016 "Sales Price List" `Sales\Pricing\SalesPriceList.Page.al` (ListPlus) | Price List Header / `PLHEADER-PRICE` | `ActionGroupCRM` "Dynamics 365 Sales" 359-448: V `CRMIntegrationEnabled` (363); E `CRMIntegrationAllowed` (362) | `CRMGoToPricelevel` (375); `CRMSynchronizeNow` calls `UpdateOneNow` (390); `ManageCRMCoupling` calls `DefineCoupling` (410); `DeleteCRMCoupling` calls `CM.RemoveCoupling(RecRef)` (430) [E Coupled 418]; `ShowLog` (445) | OnOpenPage 511: 524-528 (`Get('PLHEADER-PRICE')`, `StatusActiveFilterApplied := true`, `'Field20=1(1)'`). OnAfterGetCurrRecord 545: `CRMIntegrationAllowed := Rec.IsCRMIntegrationAllowed(...)` (549; `Pricing\PriceList\PriceListHeader.Table.al:433-438`), Coupled 550-552. |

### A.2 Master data and setup lists

The pattern is the same as A.1, plus selection-based `UpdateMultipleNow`, `MatchBasedCoupling(RecRef)` and `CM.RemoveCoupling(RecRef)`. A "Coupled to Dataverse" FlowField column (`exist("CRM Integration Record" where("Integration ID" = field(SystemId), "Table ID" = const(...)))`, e.g. `Sales\Customer\Customer.Table.al:1811-1818`) is shown with the Visible noted.

| Page | Table / mapping | G (Visible / Enabled) | Actions | Flags / indicators |
|---|---|---|---|---|
| 22 "Customer List" `Sales\Customer\CustomerList.Page.al` | Customer / CUSTOMER | `ActionGroupCRM` "Dataverse" 469-638: V CRM or CDS (472); E Blocked (473) | `CRMGotoAccount` (485); `CRMSynchronizeNow` calls UpdateOneNow/UpdateMultipleNow (502-509); `UpdateStatisticsInCRM` calls `CreateOrUpdateCRMAccountStatistics` (526) [V CRM 520, E Coupled 517]; `ManageCRMCoupling` calls `DefineCoupling` (546); `MatchBasedCoupling` calls `MatchBasedCoupling(RecRef)` (565); `DeleteCRMCoupling` calls `CM.RemoveCoupling(RecRef)` (585) [E Coupled 573]; `CreateInCRM` "Create Account in Dataverse" calls `CreateNewRecordsInCRM(Customer)` (606); `CreateFromCRM` "Create Customer in Business Central" calls `CreateNewCustomerFromCRM()` (620); `ShowLog` (635) | OnOpenPage 1657: 1664-1668 (`Get('CUSTOMER')`, `'Field39=1(0)'`). OnAfterGetCurrRecord 1625: 1631-1632. Column "Coupled to Dataverse" 250 (V CRM or CDS 253). Factbox `"CRM Statistics FactBox"` 264-269 V `CRMIsCoupledToRecord and CRMIntegrationEnabled` (268). |
| 27 "Vendor List" `Purchases\Vendor\VendorList.Page.al` | Vendor / VENDOR | `ActionGroupCDS` "Dataverse" 703-858: V CRM or CDS (707); E Blocked (708) | `CDSGotoAccount` (720); `CDSSynchronizeNow` (737-744); `ManageCDSCoupling` (765); `MatchBasedCoupling` (784); `DeleteCDSCoupling` (804) [E Coupled 792]; `CreateInCRM` "Create Account in Dataverse" calls `CreateNewRecordsInCRM(Vendor)` (825); `CreateFromCRM` calls `CreateNewVendorFromCRM()` (839); `ShowLog` (855) | OnOpenPage 1397: 1405-1409. OnAfterGetCurrRecord 1371: 1382-1384. Column 231 (V CRM or CDS 234). |
| 5052 "Contact List" `CRM\Contact\ContactList.Page.al` | Contact / CONTACT | `ActionGroupCRM` "Dataverse" 299-455: V CRM or CDS (302) | `CRMGotoContact` [E company-contact 307] (315); `CRMSynchronizeNow` [E 323] (333-340); `Coupling` sub-group [E 347]: `ManageCRMCoupling` (362), `MatchBasedCoupling` (381), `DeleteCRMCoupling` [E Coupled 389] (401); `CreateInCRM` "Create Contact in Dataverse" [E 413] calls `CreateNewRecordsInCRM(Contact)` (423); `CreateFromCRM` calls `CreateNewContactFromCRM()` (437); `ShowLog` (452) | OnOpenPage 1184: 1189-1190; OnAfterGetCurrRecord 1153: 1158-1159. Column 152 (V 155). |
| 14 "Salespersons/Purchasers" `CRM\Team\SalespersonsPurchasers.Page.al` | SALESPEOPLE | `ActionGroupCRM` "Dataverse" 224-341: V CDS or CRM (227) | `CRMGotoSystemUser` (239); `CRMSynchronizeNow` (256-263); `ManageCRMCoupling` (284); `MatchBasedCoupling` (303); `DeleteCRMCoupling` (323) [E Coupled 311]; `ShowLog` (338) | OnOpenPage 487: 491-492; OnAfterGetCurrRecord 468: 474. Column 63 (V 66). |
| 5 "Currencies" `Finance\Currency\Currencies.Page.al` | CURRENCY | `ActionGroupCRM` "Dataverse" 326-444: V CRM or CDS (330) | `CRMGotoTransactionCurrency` (342); `CRMSynchronizeNow` (359-366); `ManageCRMCoupling` (387); `MatchBasedCoupling` (406); `DeleteCRMCoupling` (426) [E Coupled 414]; `ShowLog` (441) | OnOpenPage 532: 536-537; OnAfterGetCurrRecord 515-522. Column 210 (V 213). |
| 31 "Item List" `Inventory\Item\ItemList.Page.al` | ITEM-PRODUCT | `ActionGroupCRM` "Dynamics 365 Sales" 1523-1641: V CRM (1526); E Blocked (1527) | `CRMGoToProduct` (1539); `CRMSynchronizeNow` (1556-1563); `ManageCRMCoupling` (1584); `MatchBasedCoupling` (1603); `DeleteCRMCoupling` (1623) [E Coupled 1611]; `ShowLog` (1638) | OnOpenPage 2243: 2250-2253. OnAfterGetCurrRecord 2177: 2184. Column 289 (V CRM 292). |
| 77 "Resource List" `Projects\Resources\Resource\ResourceList.Page.al` | RESOURCE-PRODUCT | `ActionGroupCRM` "Dynamics 365 Sales" 279-397: V CRM (282); E Blocked (283) | `CRMGoToProduct` (295); `CRMSynchronizeNow` (312-319); `ManageCRMCoupling` (340); `MatchBasedCoupling` (359); `DeleteCRMCoupling` (379) [E Coupled 367]; `ShowLog` (394) | OnOpenPage 709: 715-718; OnAfterGetCurrRecord 700-706. Column 130 (V 133). |
| 209 "Units of Measure" `Foundation\UOM\UnitsofMeasure.Page.al` | Unit of Measure / UOM-UOMSCHEDULE (legacy) | `ActionGroupCRM` "Dynamics 365 Sales" 77-195: V CRM (81) | `CRMGotoUnitsOfMeasure` (93); `CRMSynchronizeNow` (110-117); `ManageCRMCoupling` (138); `MatchBasedCoupling` (157); `DeleteCRMCoupling` (177) [E Coupled 165]; `ShowLog` (192) | OnOpenPage 240: `CRMIntegrationEnabled := IsCRMIntegrationEnabled() and not IsUnitGroupMappingEnabled()` (244; M:4099-4106). Column 37 (V 40). |
| 5400 "Item Unit Group List" `Inventory\Item\ItemUnitGroupList.Page.al` | Unit Group | `ActionGroupCRM` 58-157: V CRM (62) | GoTo (74); Sync (91-98); Coupling (119); Delete (139) [E Coupled 127]; Log (154) | OnOpenPage 206: `IsCRMIntegrationEnabled() and IsUnitGroupMappingEnabled()` (210). Column 44 (V 48). |
| 5403 "Resource Unit Group List" `Projects\Resources\Resource\ResourceUnitGroupList.Page.al` | Unit Group | `ActionGroupCRM` 58-157: V CRM (62) | GoTo (74); Sync (91-98); Coupling (119); Delete (139); Log (154) | 176-180 (same as above). Column 44 (V 48). |
| 5404 "Item Units of Measure" `Inventory\Item\ItemUnitsofMeasure.Page.al` | Item Unit of Measure | `ActionGroupCRM` 133-232: V CRM (137) | GoTo "Unit" (149); Sync (166-173); Coupling (194); Delete (214) [E Coupled 202]; Log (229) | OnOpenPage 287: 299 (CRM and UnitGroupMapping). Column 66 (V 69). |
| 210 "Resource Units of Measure" `Projects\Resources\Resource\ResourceUnitsofMeasure.Page.al` | Resource Unit of Measure | `ActionGroupCRM` 90-189: V CRM (94) | GoTo (106); Sync (123-130); Coupling (151); Delete (171) [E Coupled 159]; Log (186) | OnOpenPage 241: 247. Column 45 (V 48). |
| 7 "Customer Price Groups" `Sales\Pricing\CustomerPriceGroups.Page.al` | Customer Price Group | `ActionGroupCRM` 143-231: V `CRMIntegrationEnabled and not ExtendedPriceEnabled` (146) | GoTo "Pricelevel" (158); Sync calls `UpdateOneNow` (173); Coupling (193); Delete (213) [E Coupled 201]; Log (228) | OnOpenPage 294: 296. Column 61 (V CRM 64). |
| 7015 "Sales Price Lists" `Sales\Pricing\SalesPriceLists.Page.al` | PLHEADER-PRICE | `ActionGroupCRM` 126-215: V CRM (130); E `CRMIntegrationAllowed` (129) | GoTo (142); Sync calls `UpdateOneNow` (157); Coupling (177); Delete (197); Log (212) | OnOpenPage 277: 281-285 (`Get('PLHEADER-PRICE')`, `'Field20=1(1)'`); OnAfterGetCurrRecord 266-271. |
| 4 "Payment Terms" `Foundation\PaymentTerms\PaymentTerms.Page.al` (**option mapping**) | Payment Terms / PAYMENT TERMS | `ActionGroupCRM` "Dataverse" 87-185: V `CDSIntegrationEnabled` (91) | `CRMSynchronizeNow` calls `UpdateMultipleNow(RecRef, true)` (108); `ManageCRMCoupling` calls **`DefineOptionMapping`** (128); `MatchBasedCoupling` calls `MatchBasedCoupling(RecRef)` (147); `DeleteCRMCoupling` calls **`RemoveOptionMapping(RecRef)`** (167) [E `CDSIsCoupledToRecord` 155]; `ShowLog` calls **`ShowOptionLog`** (182). No GoTo action. | OnOpenPage 243-248 (CDS only). OnAfterGetRecord 232-241: `CDSIsCoupledToRecord` = a CRM Option Mapping exists for the RecordId. Page field "Coupled to Dataverse" 49 (V CDS 54). |
| 11 "Shipment Methods" `Foundation\Shipping\ShipmentMethods.Page.al` | SHIPMENT METHOD (option) | G 70-168: V CDS (74) | Sync (91); DefineOptionMapping (111); MatchBased (130); RemoveOptionMapping (150) [E 138]; ShowOptionLog (165) | 215-230; field 32 (V 37). |
| 428 "Shipping Agents" `Foundation\Shipping\ShippingAgents.Page.al` | SHIPPING AGENT (option) | G 86-184: V CDS (90) | Sync (107); DefineOptionMapping (127); MatchBased (146); RemoveOptionMapping (166) [E 154]; ShowOptionLog (181) | 226-241; field 43 (V 48). |
| 5123 "Opportunity List" / 5124 "Opportunity Card" `CRM\Opportunity\OpportunityList.Page.al` / `OpportunityCard.Page.al` | Opportunity / OPPORTUNITY | List `ActionGroupCRM` "Dynamics 365 Sales" 240-357 V CRM (243); Card 274-368 V CRM (277) | List: GoTo (255), Sync (272-279), Coupling (300), MatchBased (319), Delete (339) [E 327], Log (354). Card: GoTo (289), Sync (306-313), Coupling (334), Delete (350) [E 342], Log (365) | List OnOpenPage 548: 553; OnAfterGetRecord 526: 537. Card 589/594, 555/560. List column 115 (V CRM 118). |

### A.3 Documents

| Page | Table / mapping | G | Actions | Flags |
|---|---|---|---|---|
| 42 "Sales Order" `Sales\Document\SalesOrder.Page.al` (Document) | Sales Header / SALESORDER-ORDER | `ActionGroupCRM` "Dynamics 365 Sales" 1304-1396: V `CRMIntegrationEnabled` (1307) | `CRMGoToSalesOrder` calls `ShowCRMEntityFromRecordID` [E `CRMIntegrationEnabled and CRMIsCoupledToRecord` 1312] (1320); `CRMSynchronizeNow` calls `UpdateOneNow` [E `IsBidirectionalSyncEnabled and (Rec.Status = Released)` 1330] (1336); `Coupling` group [E same 1344]: `ManageCRMCoupling` calls `DefineCoupling` (1357), `DeleteCRMCoupling` calls `CM.RemoveCoupling(RecRef)` [E Coupled 1365] (1377); `ShowLog` [E 1387] (1393) | OnOpenPage 2575: 2594-2596 (`IsBidirectionalSyncEnabled := CRMConnectionSetup.IsBidirectionalSalesOrderIntEnabled()`). OnAfterGetCurrRecord 2492: 2504-2506. |
| 9305 "Sales Order List" `Sales\Document\SalesOrderList.Page.al` | Sales Header | `ActionGroupCRM` 514-636: V CRM (517) | `CRMGoToSalesOrderListInNAV` "Sales Order List" calls `PAGE.Run("CRM Sales Order List")` [V `CRMIntegrationEnabled and (not BidirectionalSalesOrderIntEnabled)` 525] (531); `CRMGoToSalesOrder` calls `ShowCRMEntityFromRecordID` [V `BidirectionalSalesOrderIntEnabled` 541; E CRM and Coupled 538] (547); `CRMSynchronizeNow` [V Bidirectional 557] filters Released, then UpdateOneNow/UpdateMultipleNow (565-573); `Coupling` group [V Bidirectional 583; E Released 582]: `ManageCRMCoupling` (596), `DeleteCRMCoupling` (616); `ShowLog` [V Bidirectional 626; E Released 627] (633) | OnOpenPage 1210: 1222-1223; OnAfterGetCurrRecord 1185-1194. Column 297 (V `CRMIntegrationEnabled and BidirectionalSalesOrderIntEnabled` 300). |
| 132 "Posted Sales Invoice" `Sales\History\PostedSalesInvoice.Page.al` | Sales Invoice Header / POSTEDSALESINV-INV | `ActionGroupCRM` 821-869: V CRM (824) | `CRMGotoInvoice` [E Coupled 829] (837); `CreateInCRM` "Create Invoice in Dynamics 365 Sales" [E `not CRMIsCoupledToRecord` 844] calls `CreateNewRecordsInCRM(Rec.RecordId)` (852); `ShowLog` (866). No Synchronize and no Coupling actions. | OnOpenPage 1305: 1312; OnAfterGetCurrRecord 1268: 1284. |
| 143 "Posted Sales Invoices" `Sales\History\PostedSalesInvoices.Page.al` | same | 382-432: V CRM (385) | `CRMGotoInvoice` [E 390] (398); `CreateInCRM` [E 405] calls `CreateNewRecordsInCRM(SalesInvoiceHeader)` (415); `ShowLog` (429) | OnOpenPage 786: 796; OnAfterGetCurrRecord 760: 775-777. Column 280 (V CRM 283). |

No other sales document page (quote, invoice, credit memo, posted shipment) has Dataverse actions. A grep for `ShowCRMEntityFromRecordID|UpdateOneNow|DefineCoupling|IsRecordCoupledToCRM` found no other document page.

### A.4 Dataverse-side list pages ("CRM xxx List") used for lookup and "Create in BC"

All of these open with `Rec.SetView(LookupCRMTables.GetIntegrationTableMappingView(<CRM table>))` in FilterGroup 4. That procedure (LT:457-505) ORs together the Integration Table Filters of **all** Dataverse mappings with `"Synch. Codeunit ID" = CRM Integration Table Synch.` for that integration table. The "Coupled" column is computed in OnAfterGetRecord via `CIR.FindRecordIDFromID(<id>, <hard-coded BC table>)`, and "Hide/Show Coupled" toggle `MarkedOnly`. **None of the "Create in Business Central" actions has a Visible or Enabled expression tied to Direction or enablement.** The only exceptions are the CRM Sales Order list and the FS lists (premium experience).

| Page | Source table | Create action (calls) | Other |
|---|---|---|---|
| 5341 "CRM Account List" `Integration\D365Sales\CRMAccountList.Page.al` | CRM Account | `CreateFromCRM` "Create in Business Central" calls `CreateNewRecordsFromSelectedCRMRecords(CRMAccount)` (97); no Visible or Enabled | Coupled: Customer then Vendor (150-177); OnInit `Codeunit.Run(CRM Integration Management)` (182); OnOpenPage view (191). |
| 5342 "CRM Contact List" `…\CRMContactList.Page.al` | CRM Contact | `CreateFromCRM` (117) | view 197 |
| 5343 "CRM Opportunity List" `…\CRMOpportunityList.Page.al` | CRM Opportunity | `CreateFromCRM` (138); `CRMGotoOpportunities` calls `HyperLink(GetCRMEntityUrlFromCRMID(DATABASE::"CRM Opportunity", …))` (118) | view 234 |
| 5353 "CRM Sales Order List" `…\CRMSalesOrderList.Page.al` | CRM Salesorder | `CreateInNAV` [E `BidirectionalSalesOrderIntEnabled or (HasRecords and CRMIntegrationEnabled)` 170]: Bidirectional calls `CreateNewRecordsFromSelectedCRMRecords` (186), otherwise `CRMSalesOrderToSalesOrder.CreateInNAV` (189); `CRMGoToSalesOrder` calls `GetCRMEntityUrlFromCRMID` (158); Show/Hide coupled [V Bidirectional 203, 216] | OnOpenPage 278-301 |
| 5380 "CRM Sales Order" `…\CRMSalesOrder.Page.al` (Document) | CRM Salesorder | `CreateInNAV` [E `CRMIntegrationEnabled and not CRMIsCoupledToRecord` 407] (420-435); `NAVOpenSalesOrderCard` [E Coupled 386, V CRM 389] (396-400); `CRMGoToSalesOrderHyperlink` [V/E CRM 365-368] (374) | OnOpenPage 458-464 (`CRMConnectionSetup.IsEnabled()`); coupling via `CRMIsCoupledToValidRecord` (494-496) |
| 5351 "CRM Sales Quote List" `…\CRMSalesQuoteList.Page.al` | CRM Quote | none; `CRMGoToQuote` (90) | |
| 5349 "CRM Case List" `…\CRMCaseList.Page.al` | CRM Incident | `CRMGoToCase` (70) | |
| 5346 "CRM Pricelevel List", 5348 "CRM Product List", 5345 "CRM TransactionCurrency List", 5362 "CRM UnitGroup List", 5364 "CRM Unit List" | | lookup only (Show/Hide coupled) | views at CRMProductList:146, CRMTransactionCurrencyList:126, CRMUnitGroupList:144, CRMUnitList:142 |
| 7210 "CRM Payment Terms List" `Integration\Dataverse\CRMPaymentTermsList.Page.al`, 7211 "CRM Freight Terms List", 7212 "CRM Shipping Method List" `Integration\D365Sales\…` (temporary option buffers) | | `CreateFromCRM` calls `CreateNewRecordsFromSelectedCRMOptions` (62 in each) | |
| 5340 "CRM Systemuser List" `Integration\D365Sales\CRMSystemuserList.Page.al` | CRM Systemuser | `CreateFromCRM` "Create Salesperson in Business Central" calls `HasUncoupledSelectedUsers`, then `CreateNewRecordsFromSelectedCRMRecords` (121-124); `Couple` [V `ShowCouplingControls` 140] calls local `LinkUsersToSalespersons`, then `CRMIntegrationManagement.CoupleCRMEntity` (382); `DeleteCDSCoupling` "Uncouple" [V 164] calls `CRMIntegrationManagement.RemoveCoupling(SalesPersonRecordID, false)` (181); `AddCoupledUsersToTeam` [V `IsCDSIntegrationEnabled` 195] | Coupled 259-281; `IsCDSIntegrationEnabled := CDSConnectionSetup."Is Enabled"` (300) |
| 7209 "CDS Couple Salespersons" `Integration\Dataverse\CDSCoupleSalespersons.Page.al` | CRM Systemuser | `CreateFromCDS` (114-118); `DeleteCDSCoupling` calls `RemoveCoupling(…, false)` (143); `MatchBasedCoupling` resolves the mapping by `Type = Dataverse`, `"Table ID" = Salesperson/Purchaser`, then calls `MatchBasedCoupling(TableID, false, false, true)` (164-181) | all [E `HasPermissions`] |
| fs: 6610 "FS Bookable Resource List" `fs:Pages\FSBookableResourceList.Page.al` | FS Bookable Resource | `CreateFromFS` (77), no Visible | view 156 |
| fs: 6611 "FS Customer Asset List", 6615 "FS Work Order Types", 6616 "FS Work Orders" | | `CreateFromFS` [V `ShowCreateInBC` = `ApplicationAreaMgmtFacade.IsPremiumExperienceEnabled()`] (FSCustomerAssetList:78/86/173, FSWorkOrderTypes:51/59/119, FSWorkOrders:123/131/210) | |

### A.5 Field Service page extensions (fs app)

All FS actions call **base** `CRM Integration Management` and `CRM Coupling Management`. The FS app has no UI-level management codeunit of its own (`fs:Codeunits\FSIntegrationMgt.Codeunit.al` is only used by the wizard, for `ReturnIntegrationTypeLabel` at `fs:Pages\FSConnectionSetupWizard.Page.al:393`). The flags come from OnOpenPage: `CRMIntegrationEnabled := IsCRMIntegrationEnabled(); if CRMIntegrationEnabled then FSIntegrationEnabled := FSConnectionSetup.IsEnabled()`.

| Pageext → base page | Table / mapping | Group `ActionFS` "Dynamics 365 Field Service" | Actions | Notes |
|---|---|---|---|---|
| 6612 "FS Resource Card" → Resource Card `fs:Page Extensions\FSResourceCard.PageExt.al` | Resource / RESOURCE-BOOKABLERSC | 21-140: V `FSIntegrationEnabled` (24); E Blocked (25) | `GoToProductFS` "Bookable Resource" (38); `SynchronizeNowFS` (55-62); `ManageCouplingFS` (83); `FSMatchBasedCoupling` (102); `DeleteCouplingFS` (122) [E Coupled 110]; `FSShowLog` (137) | OnOpenPage 194-209: mapping by `Type = Dataverse`, `Table ID = Resource`, `Integration Table ID = FS Bookable Resource` (204-208), `'Field38=1(0)'` (209). OnAfterGetCurrRecord 186-191. |
| 6613 "FS Resource List" | same | 21-140: V FS (24); E Blocked (25) | same lines ±0 (38, 55-62, 83, 102, 122, 137) | 191-206 |
| 6619 "FS Service Item Card" `…\FSServiceItemCard.PageExt.al` | Service Item / SVCITEM-CUSTASSET | 17-122: V FS (20); E `'Field40=1(0)'` filter (21) | GoTo "Customer Asset" (34); Sync calls `UpdateOneNow` (49); Coupling (69); MatchBased (88); Delete (104) [E `CRMIsCoupledToRecord` 96]; Log (119) | OnOpenPage 167-184 (mapping by pair, 177-182). **`CRMIsCoupledToRecord` is never assigned** (declared at 163, there is no OnAfterGetCurrRecord), so Delete Coupling is always disabled. |
| 6620 "FS Service Item List" | same | 31-136: V FS (34); E (35) | 48, 63, 83, 102, 118 [E 110, never set], 133 | 181-196. Column "Coupled to FS" 17. |
| 6614 "FS Service Order" → Service Order `…\FSServiceOrder.PageExt.al` | Service Header / work order mapping | 24-142: **no Visible**, E `FSIntegrationEnabled` (27) | GoTo "Work Order" (40); Sync (57-64); Coupling (85); MatchBased (104); Delete (124) [E Coupled 112]; Log (139) | promoted `Category_FS_Synchronize` V FS (149). OnOpenPage 193-200, OnAfterGetCurrRecord 185-190. |
| 6624 "FS Service Orders" | same | 29-147: no Visible, E FS (32) | 45, 62-69, 90, 109, 129, 144 | column "Coupled to FS" 16 |
| 6625 "FS Service Order Types" | Service Order Type | 29-147: no Visible, E FS (32) | 45, 62-69, 90, 109, 129, 144 | column 16 |
| 6610 "FS Job Task Card" `…\FSJobTaskCard.PageExt.al` | Job Task / project task mapping | 16-101: no Visible, E `FSActionGroupEnabled` (19) | GoTo "Project Task in Field Service" (32); Sync (47); Coupling (67); Delete (83) [E 75]; Log (98). No MatchBased. | `FSActionGroupEnabled := FSIntegrationEnabled and (Job Task Type = Posting) and Job."Apply Usage Link"` (165). |
| 6611 "FS Job Task Lines", 6617 "FS Job Task List" | Job Task | 29-114: no Visible, E `FSActionGroupEnabled` (32) | 45, 60, 80, 96, 111 | 167 (Lines). Column "Coupled to FS" 16 (V FS 19). |
| 6623 "FS Location List" | Location / warehouse mapping | 29-114: no Visible, E FS (32) | GoTo "Warehouse in Field Service" (45); Sync calls `UpdateOneNow` (60); Coupling (80); Delete (96); Log (111) | 163-170 |
| 6627 "FS Service Order Subform", 6628 "FS Service Lines" | Service Line | none | | column "Coupled to FS" 16, V FS (20) |
| 6618 "FS Job Journal" `…\FSJobJournal.PageExt.al` | Job Journal Line | none | | FS fields V `FSConnectionSetup.IsEnabled()` (32) |
| FS role centres `…\FSJobProjectManagerRC.PageExt.al`, `…\FSServiceManagerRC.PageExt.al` | | `GroupFS` | navigation to FS lists and "CRM Skipped Records" (34-41) | |

"Coupled to FS" FlowFields are table extensions, for example `fs:Table Extensions\FSJobTask.TableExt.al:14-20` (`exist("CRM Integration Record" where("Integration ID" = field(SystemId), "Table ID" = const(Database::"Job Task")))`).

### A.6 Setup and admin pages

| Page | Actions (calls) [Visible/Enabled] |
|---|---|
| 5330 "CRM Connection Setup" `Integration\D365Sales\CRMConnectionSetup.Page.al` | "Assisted Setup" calls `CRMIntegrationMgt.RegisterAssistedSetup` + `GuidedExperience.Run(... "CRM Connection Setup Wizard")` (307-309); "Test Connection" calls `Rec.PerformTestConnection()` (322); "Use Certificate Authentication" [V SaaS 330, E Is Enabled 331] (343-362); `IntegrationTableMappings` [E Is Enabled 373] calls `Page.Run("Integration Table Mapping List")` (379); "Redeploy Solution" [E `IsCdsIntegrationEnabled and not "Is Enabled"` 387] calls `Rec.DeployCRMSolution(true)` (393); `ResetConfiguration` "Use Default Synchronization Setup" [E 400] calls `CRMSetupDefaults.ResetConfiguration(Rec)` (410); `CoupleUsers` calls `CRMSystemuserList.Initialize(true); Run()` (427-428); `StartInitialSynchAction` "Run Full Synchronization" [E 435] calls `PAGE.Run("CRM Full Synch. Review")` (441); "Reset Web Client URL" (454); `SynchronizeNow` "Synchronize Modified Records" [E 462] calls `Rec.SynchronizeNow(false)` (473); "Synch. Job Queue Entries" (492-496); `SkippedSynchRecords` RunObject "CRM Skipped Records" (505); `RebuildCouplingTable` calls `CDSIntegrationImpl.ScheduleRebuildingOfCouplingTable()` (530); `FieldServiceIntegrationApp` [V SaaS 538] calls `Hyperlink(GetFieldServiceIntegrationAppSourceLink())` (545). Bidirectional flag 748. |
| 7200 "CDS Connection Setup" `Integration\Dataverse\CDSConnectionSetup.Page.al` | "Assisted Setup" [E `(not "Is Enabled") or (not BusinessEventsEnabled)` 354] (362-364); "Test Connection" calls `CDSIntegrationImpl.TestConnection` (378); "Use Certificate Authentication" (404-423); `ResetConfiguration` [E 433] calls `CDSSetupDefaults.ResetConfiguration` (442); `CoupleUsers` [E Person ownership 452] (460-461); `AddUsersToTeam` [E 468] (476); `StartInitialSynchAction` [E 484] calls "CRM Full Synch. Review" (490); `SynchronizeNow` [E 497] (508); `RebuildCouplingTable` (524); "Redeploy Solution" (540-550); "Integration Solutions" / "Integration User Roles" / "Owning Team Roles" (563-592); "Dataverse Integration User" / "Dataverse Owning Team" (605, 618); "Synch. Job Queue Entries" (655-659); `IntegrationTableMappings` [E 666] (672); "Virtual Tables App" / "Virtual Tables Config" / "Available Virtual Tables" / "Virtual Tables AAD app" / "Synthetic Relations" (675-735). |
| fs: 6612 "FS Connection Setup" `fs:Pages\FSConnectionSetup.Page.al` | "Assisted Setup" (225-227); "Test Connection" (240); `IntegrationTableMappings` [E 247] (253); "Redeploy Solution" [E 261] (267); `ResetConfiguration` [E 274] calls `FSSetupDefaults.ResetConfiguration(Rec)` (285); `StartInitialSynchAction` [E 295] calls "CRM Full Synch. Review" (301); "Synch. Job Queue Entries" (319-323); `SkippedSynchRecords` (332). Mapping lookup for Job Journal Line by `Integration Table ID` = FS WO Product\|WO Service (185-189). |
| 1817 "CRM Connection Setup Wizard" `Integration\D365Sales\CRMConnectionSetupWizard.Page.al`; 7201 "CDS Connection Setup Wizard" `Integration\Dataverse\CDSConnectionSetupWizard.Page.al`; fs: 6613 "FS Connection Setup Wizard" | CRM: `ActionFinish` (356-364). CDS: "Couple Salespeople" step calls `CDSCoupleSalespersons.RunModal()` (457-463); recommendations call `CDSFullSynchReview.RunModal()` (501-518); `ActionNext` generates `CRMFullSynchReviewLine.Generate()` (719-731); `ActionFinish` calls `CRMFullSynchReviewLine.Generate(InitialSynchRecommendations); Start()` then runs "CRM Full Synch. Review" (797-806). FS: `ActionFinish` (386-394). |
| 5335 "Integration Table Mapping List" `Integration\SynchEngine\IntegrationTableMappingList.Page.al` (`SourceTableView = where("Delete After Synchronization" = const(false))` 21) | `FieldMapping` (223-224); `ResetConfiguration` calls `CRMIntegrationMgt.ResetIntTableMappingDefaultConfiguration(IntegrationTableMapping)` (245); "View Integration Synch. Job Log" (264-279); `SynchronizeNow` [E `HasRecords and (Rec."Parent Name" = '')` 284] calls `Rec.SynchronizeOptionNow(false,false)` if the UID field is an Option, else `Rec.SynchronizeNow(false)` (296-299); `SynchronizeAll` "Run Full Synchronization" [E 307] (323-325); `UnconditionalSynchronizeAll` [E … **and Direction <> Bidirectional** 333] (349-351); "View Integration Uncouple Job Log" (355-371); "View Integration Coupling Job Log" (372-388); `RemoveCoupling` "Delete Couplings" [V `CRMIntegrationEnabled or CDSIntegrationEnabled` 394, E 393] deletes CRM Option Mapping for option mappings (430-432), else calls `CRMIntegrationManagement.RemoveCoupling(Table ID, Integration Table ID)` (434); `MatchBasedCoupling` [V CRM or CDS 452; E `… and (((Rec.Name = 'SALESORDER-ORDER') and (not BidirectionalSalesOrderIntegrationEnabled)) or (Rec.Name <> 'SALESORDER-ORDER'))` 451] calls `CRMIntegrationManagement.MatchBasedCoupling(IntegrationTableMapping."Table ID")` (473). **By table ID, not by the selected mapping.** `ManualIntTableMapping` (490). Flags OnInit 572-579 (630-642). |
| 5338 "Integration Synch. Job List" `Integration\SynchEngine\IntegrationSynchJobList.Page.al` | No Dataverse actions. Drill-downs: Inserted opens local records by `IntegrationTableMapping.Get(Rec."Integration Table Mapping Name")` (79-89); Skipped opens "CRM Skipped Records" (137-142). The direction caption is computed 249-258. |
| 5339 "Integration Synch. Error List" `Integration\SynchEngine\IntegrationSynchErrorList.Page.al` | `DataIntegrationSynchronizeNow` [V `ShowDataIntegrationActions` 162] calls `Rec.ForceSynchronizeDataIntegration(...)` (180/194), which raises `OnForceSynchronizeDataIntegration` / `OnForceSynchronizeRecords` (`Integration\SynchEngine\IntegrationSynchJobErrors.Table.al:122-131`). Base subscribers M:3645-3682 (`subscribers-crm.md` M9/M10). `ManageCRMCoupling` [V `ShowCDSIntegrationActions` 235] calls `DefineCoupling` (245); `DeleteCRMCoupling` [V 255] calls `IntegrationSynchJobErrors.DeleteCouplings()` (262), which ends in `M.RemoveCoupling(LocalTableId, LocalIdList)` (`IntegrationSynchJobErrors.Table.al:212`). Source/Destination drill-downs raise `OnOpenSourceRecord` / `OnOpenDestinationRecord` (94/110, declared 411/416, `var RecordId; var IsHandled`), else `CRMSynchHelper.ShowPage` (`Integration\D365Sales\CRMSynchHelper.Codeunit.al:1486-1513`). Flags: OnOpenPage 324-333. |
| 5333 "CRM Skipped Records" `Integration\D365Sales\CRMSkippedRecords.Page.al` | `Restore` "Retry" calls `UpdateSkippedNow(CRMIntegrationRecord, CRMOptionMapping)` (95); `RestoreAll` calls `UpdateAllSkippedNow()` (116); `CRMSynchronizeNow` calls `UpdateSkippedNow(…, true)` + `UpdateMultipleNow(CRMIntegrationRecord)` / `UpdateMultipleNow(CRMOptionMapping, true)` (136-141); `ShowLog` calls `ShowLog` / `ShowOptionLog` (163/165); `ManageCRMCoupling` calls `DefineCoupling(RecId)` (187); `ShowUncouplingLog` [V CRM or CDS 197] (205-209); `DeleteCRMCoupling` calls `TempCRMSynchConflictBuffer.DeleteCouplings()` (227), which ends in `M.RemoveCoupling` / `CM.RemoveCouplingWithTracking` (`Integration\D365Sales\CRMSynchConflictBuffer.Table.al:353,366,380-382`); `FindMore` calls `MarkLocalDeletedAsSkipped()` (244); `DeleteCoupledRec` (279). Flags 406-407. |
| 5331 "CRM Full Synch. Review" `Integration\D365Sales\CRMFullSynchReview.Page.al` (Worksheet) | `Start` "Sync All" [E `ActionStartEnabled`] calls `Rec.Start()` (141); `ScheduleFullSynch` (183-187); `ToggleMultiCompany` (202-211). The recommendation drill-down uses `IntegrationTableMapping.Get(Rec.Name)` (93-98). Direction is shown as a column (51) but not used. |
| 7208 "CDS Full Synch. Review" `Integration\Dataverse\CDSFullSynchReview.Page.al` | `ScheduleFullSynch` (178-179). The drill-down resolves the mapping by a **hard-coded `case BCPageId of` → `"Table ID"`** list (98-120). |
| 5363 "Match Based Coupling Criteria" `Integration\SynchEngine\MatchBasedCouplingCriteria.Page.al` | Opened by `MatchBasedCoupling` (M:1196, M:1345). Direction-based control visibility (180/183). |
| 5334 "CRM Option Mapping" `Integration\Dataverse\CRMOptionMapping.Page.al` | Opened from the Integration Table Mapping List field drill-down (`IntegrationTableMappingList.Page.al:123-126`). |
| 5371 "CRM Synch. Job Status Part", 5327 "Int. Table Mapping Errors", cues (`CRM\RoleCenters\SalesRelationshipMgrAct.Page.al:164-166`, `RoleCenters\ITOperationsActivities.Page.al:157-159`, `Invoicing\O365Activities.Page.al:424-426`, `System\User\UserSecurityActivities.Page.al:175-177`) | Indicators only. `IntTableMappingErrors.Page.al:53-71` drills into the Synch Job List / "CRM Skipped Records". |
| Role centres: `CRM\RoleCenters\SalesMarketingManagerRC.Page.al:726-786`, `RoleCenters\AdministratorRoleCenter.Page.al:92-96,154-160`, `RoleCenters\AdministratorMainRoleCenter.Page.al:797-853` | Navigation only (RunObject to the CRM lists, setup, mappings, jobs, errors). |

### A.7 Special pages

| Page | Behaviour |
|---|---|
| 5329 "CRM Redirect" `Integration\Dataverse\CRMRedirect.Page.al` (List on table "CRM Redirect", no controls or actions) | OnOpenPage 47-53: `Error(CRMIntegrationNotEnabledErr)` unless CRM **or** CDS is enabled. FS-only enablement is not checked separately. OnFindRecord 26-45: parse `Filter` with regex `CRMID:{guid};CRMType:name` (`ExtractCRMInfoFromFilters` 64-79, `ExtractPartsFromCRMInfo` 81-102), then call `M.OpenCoupledNavRecordPage(CRMID, CRMEntityTypeName)` (40); if false, `Error(NoCoupledEntityErr)` (43); then close the page. See C.1. |
| 5336 "CRM Coupling Record" (StandardDialog) | See C.3. |
| 5360 "CRM Statistics FactBox" `Integration\D365Sales\CRMStatisticsFactBox.Page.al` (CardPart, Customer) | Fields call `GetNoOfCRMOpportunities/Quotes/Cases` (M:2431-2477); drill-downs call `ShowCustomerCRMOpportunities/Quotes/Cases` (30/43/56; M:2212-2266, each returns early if not CRM enabled, then `DefineCouplingIfNotCoupled`). Hosted by Customer Card 969-974 and Customer List 264-269. |

---

## B. Management procedures called by the actions

Legend: **Takeover** = can a dependent app replace the behaviour completely today? (Y = an OnBefore…IsHandled event exists before any side effect; P = partial, only some step can be influenced; N = no event).

### B.0 Mapping-resolution helpers (used by almost everything)

| Procedure | Access | What it does | Events |
|---|---|---|---|
| `GetIntegrationTableMapping(var ITM; RecId: RecordId)` M:1555-1562 | public | `TableId := RecId.TableNo()`, raises the event, then calls the TableID overload. | `OnBeforeGetIntegrationTableMappingWithRecordId(var IntegrationTableMapping; BCRecordId: RecordId; var TableID: Integer)` (decl M:4242, raised M:1560), not IsHandled. A subscriber **can change TableID** and can set filters, but the overload below overwrites Type/Synch Codeunit/Delete After/Table ID filters. |
| `GetIntegrationTableMapping(var ITM; TableID: Integer)` M:1564-1576 | public | `SetRange(Type, Dataverse)`, `SetRange("Synch. Codeunit ID", CRM Integration Table Synch.)`, `SetRange("Delete After Synchronization", false)`, `SetRange("Integration Table ID", TableID)` if `IsCRMTable(TableID)`, else `SetRange("Table ID", TableID)`; `FindFirst` or `Error(IntegrationTableMappingNotFoundErr)`. | `OnBeforeGetIntegrationTableMapping(var IntegrationTableMapping; TableID: Integer)` (decl M:4177, raised M:1566), not IsHandled; TableID is by value. A subscriber can only **add** filters on other fields (for example `Name` or `"Integration Table ID"`) to break the tie between several mappings. It cannot change the codeunit filter. |
| `GetIntegrationTableMappingFromCRMRecord` M:1578-1605 | local | For CRM Account, uses CustomerTypeCode → Customer/Vendor; otherwise uses the RecId overload. | `OnBeforeGetIntegrationTableMappingFromCRMRecord(var ITM; RecRef)` (M:1584, decl 4182); `OnAfterGetIntegrationTableMappingFromCRMRecordBeforeFindRecord(var ITM; RecRef)` (M:1602, decl 4247). Neither is IsHandled. |
| `GetIntegrationTableMappingFromCRMOption` M:1607-1629 | local | Hard-coded CRM option table → BC table (Payment Terms / Shipment Method / Shipping Agent). | `OnGetTableIdFromCRMOption(RecRef; var TableId)` (M:1624, decl 4207). |
| `GetIntegrationTableMappingFromCRMID` M:3138-3182 | local | For the redirect. CRM table → by Integration Table ID; BC table → Account CustomerTypeCode / Product ProductTypeCode switch. | `OnGetIntegrationTableMappingFromCRMIDOnBeforeFindTableID(var ITM; var TableID; CRMID; var IsHandled)` (M:3151, decl 4237). IsHandled skips only the table-ID switch. |
| `GetIntegrationTableMappingForCoupling` M:1546-1553 / `…ForUncoupling` M:1527-1544 | local | Type Dataverse + `"Coupling Codeunit ID" in (CDS Int. Table Couple, CDS Int. Option Couple)` / `"Uncouple Codeunit ID" = CDS Int. Table Uncouple` + Table ID (+ Integration Table ID in the pair overload) → FindFirst. | none |
| `IsCRMTable(TableID)` M:1640-1655 | public | Hard-coded CRM option tables + TableMetadata.TableType = CRM. | `OnIsCRMTable(TableID; var IsCRMTable; var Handled)` (M:1646, decl 4212), IsHandled. |
| `IsCRMIntegrationEnabled()` M:172-195 | public | Cached state; CRM Connection Setup."Is Enabled" + registers the connection. | `OnAfterCRMIntegrationEnabled()` (M:189), info only. |
| `IsCDSIntegrationEnabled()` M:197-211 | public | `OnIsCDSIntegrationEnabled(var isEnabled)` (M:203, decl M:231); base subscriber `Integration\Dataverse\CDSIntTableSubscriber.Codeunit.al:824-832` only sets true. Then `OnInitCDSConnection`. | A dependent app can force "enabled" but **cannot force disabled** if CDS is enabled. |
| `CM.IsRecordCoupledToCRM(RecordID)` CM:19-24 | public | Calls `CIR.IsRecordCoupled` (CIR:388) and `FindIDFromRecordID` (CIR:492): any coupling row for (SystemId, Table ID). It is not mapping- or integration-table-aware. | none |

### B.1 Per-record actions

| Procedure | Access / signature | What it does | Events raised | Takeover |
|---|---|---|---|---|
| `ShowCRMEntityFromRecordID` M:1860-1868 | public `(RecordID: RecordID)` | `DefineCouplingIfNotCoupled` (M:2111-2123: if not coupled, Confirm, then `DefineCoupling`), then `HyperLink(GetCRMEntityUrlFromRecordID(RecordID))`. `GetCRMEntityUrlFromRecordID` M:1870-1882: `CIR.FindIDFromRecordID` or Error; `GetIntegrationTableMapping(…, RecordID)`; `GetCRMEntityUrlFromCRMID(Table ID, Integration Table ID, CRMId)` M:1895-1914, which builds `CRMEntityUrlTemplateTxt` with the entity name from `GetCRMEntityTypeName` (M:2085-2102 → `SD:2492-2547 GetTableIDCRMEntityNameMapping`). | `OnBeforeGetIntegrationTableMappingWithRecordId`, `OnBeforeGetIntegrationTableMapping` (B.0); `OnGetCDSServerAddress(var CDSServerAddress; var handled)` (M:1902, decl 246; base subscriber in CDS, `subscribers-cds.md` S5); `OnAfterGetCRMEntityUrlFromCRMID(CRMEntityUrlTemplateTxt; NewestUIAppIdParameterTxt; TableId; CRMId; var CRMEntityUrl; CRMTableId)` (M:1912, decl 4232), **can replace the URL**; `SD.OnAddEntityTableMapping(var TempNameValueBuffer)` (SD:2546, decl 2623), `SD.OnBeforeAddEntityTableMapping(var CRMEntityTypeName; var TableID; var TempNameValueBuffer)` (SD:2551, decl 2718). | **P**: URL can be rewritten after the fact. The coupling check and Error happen first, so there is no way to skip them. |
| `UpdateOneNow` M:603-607 | public `(RecordID)` | "Extinct method", calls `UpdateMultipleNow(RecordID)`. | as below | N |
| `UpdateMultipleNow` M:363-366 / M:368-384 | public `(RecVariant)` / `(RecVariant; IsOption: Boolean)` | `GetRecordRef`; dispatch: CRM Integration Record → `UpdateCRMIntRecords` (M:386-485; mapping per table via `GetIntegrationTableMapping(…, RecId)` M:414/430; uses mapping Direction if not Bidirectional M:467-470); IsOption → `UpdateOptions` (M:549-601); else `UpdateRecords` (M:487-547: `GetIntegrationTableMapping(…, RecordId)` M:499; single record not coupled → `DefineCouplingIfNotCoupled` M:506; direction prompt M:504/510; skip logic; `EnqueueSyncJob(ITM, LocalIdList, CRMIdList, SelectedDirection, "Synch. Only Coupled Records")` M:541 → M:1709-1722 → `AddIntegrationTableMapping` (temporary child mapping, M:1756-1775) + `CRMSetupDefaults.CreateJobQueueEntry`). | B.0 mapping events; `OnBeforeSynchronyzeNowQuestion(var AllowedDirection: Integer; var IsHandled)` (M:2504, decl 4192), **multi-record and unidirectional only**, skips the Confirm. | **N** (P for the confirm). The direction prompt honours mapping Direction (0.2). |
| `DefineCoupling` M:2125-2143 | public `(RecordID): Boolean` | `CM.DefineCoupling(RecordID, CRMID, CreateNew, Synchronize, Direction)` (CM:70-95: `AssertTableIsMapped` CM:34-41 = Type Dataverse + Table ID FindFirst (errors if none); run page **CRM Coupling Record** modal; on OK, `CIR.CoupleRecordIdToCRMID` (CIR:582)). Then `CreateNew` → `CreateNewRecordsInCRM(RecordID)`; `Synchronize` → `PerformInitialSynchronization` (M:1057-1070 → `GetIntegrationTableMapping(…, RecordID)` + `EnqueueSyncJob(ITM, RecordID, CRMID, Direction)` M:1694-1707, which **overrides Direction**). | No event in M or CM. Inside the dialog: `LT.OnLookupCRMTables` (C.3), `SD.OnGetCDSTableNo` (SD:2231), `SD.OnBeforeGetDefaultDirection` (SD:2278). | **N** |
| `DefineOptionMapping` M:2156-2174 | public `(RecordID): Boolean` | `CM.DefineOptionMapping` (CM:43-68, same dialog with IsOption=true; `M.CreateOptionMapping` M:1301-1316) → `CreateNewOptionsInCRM` (M:761-788) or `PerformInitialOptionSynchronization` (M:1072-1085 → `EnqueueOptionSyncJob` M:893-904). | `LT.OnLookupCRMOption` (C.3); `CRB.OnFindCRMOptionByName` (CRB:291, decl 426) | N |
| `MatchBasedCoupling(var LocalRecordRef: RecordRef)` M:1216-1221 | public | Calls local `MatchBasedCoupling(RecRef, Background)` M:1331-1355: `IsCRMTable` guard; `GetIntegrationTableMappingForCoupling(…, RecRef.Number())` (**by table ID**); `IntegrationFieldMapping.SetMatchBasedCouplingFilters`; `Page.RunModal("Match Based Coupling Criteria")`; `FindCoupledToCRMField` (M:3914-3957) → `SetRange(false)`; `ScheduleCoupling` (M:1450-1464 → `EnqueueCouplingJob` M:1735-1749 → `CDSSetupDefaults.CreateCoupleJobQueueEntry`) or `PerformCoupling` (M:1466-1480 → `CDSIntTableCouple.PerformScheduledCoupling`). | `OnIsCRMTable`; `OnBeforeFindCoupledToCRMField(TableNo; var IsHandled; var CoupledFieldNo)` (M:3928, decl 4227; FS subscriber FSR:2991). | **N** |
| `MatchBasedCoupling(TableID)` M:1174-1177 / `(TableID; SkipSettingCriteria; IsFullSync; InForeground): Boolean` M:1179-1209 | public | Same flow, keyed by table ID. Used by the Integration Table Mapping List (473), CDS Couple Salespersons (181) and Full Synch Start (`CRMFullSynchReviewLine.Table.al:247`). | `OnIsCRMTable` | N |
| `CM.RemoveCoupling(RecordID)` CM:104-109 → `RemoveSingleCoupling` CM:128-141 | public | `CIR.FindByRecordID` or Error; `M.RemoveCoupling(RecordId)` (M:1391-1394 → internal M:1396-1414): `IsCRMTable` guard; `GetIntegrationTableMappingForUncoupling(…, TableNo)` (**by table**); none → `CIR.RemoveCouplingToRecord` (CIR:602); else `ScheduleUncoupling` (M:1435-1448 → `EnqueueUncoupleJob` M:1724-1733 → `CDSSetupDefaults.CreateUncoupleJobQueueEntry`). | `OnIsCRMTable` only (engine events fire later in the job, see other inventories) | **N** |
| `CM.RemoveCoupling(var RecRef)` CM:97-102 → `M.RemoveCoupling(var LocalRecordRef)` M:1211-1214 → internal M:1247-1264 | public | Same, with a local-record view filter. | same | N |
| `M.RemoveCoupling(RecordID; Schedule)` M:1396 (internal), `(TableID; CRMTableID; CRMID)` M:1416/1421, `(LocalTableID; var LocalIdList)` M:1223/1228, `(LocalTableID; IntegrationTableID; var IntegrationIdList)` M:1242/1357 | public wrappers, internal implementations | Pair overloads use `GetIntegrationTableMappingForUncoupling(…, TableID, CRMTableID)` (M:1527-1535). | none | N |
| `M.RemoveCoupling(TableID; CRMTableID)` M:1160-1172 | public | Whole-mapping uncouple: pair mapping → `ScheduleUncoupling(ITM,'','')`; else `RepairBrokenCouplings()` + `CIR.SetRange("Table ID", TableID); DeleteAll()`. | none | N |
| `RemoveOptionMapping(var RecRef)` M:1266-1278 | public | Deletes the CRM Option Mapping per record. | none | N |
| `ShowLog(RecId)` M:3417-3425 | public | `GetIntegrationTableMapping(…, RecId)`; `CIR.FindByRecordID`; `ITM.ShowLog(CIR.GetLatestJobIDFilter())` (ITM:622-625 → ITM:719-740, runs "Integration Synch. Job List" filtered by mapping Name and job IDs). | B.0 mapping events | N |
| `ShowOptionLog(RecId)` M:3427-3438 | public | Same for options. | B.0 | N |
| `CreateOrUpdateCRMAccountStatistics(Customer)` M:1845-1858 | public | `GetCoupledCRMID` or exit; `CRMAccount.Get(CRMID)`; `CRMStatisticsJob.CreateOrUpdateCRMAccountStatistics` (`Integration\D365Sales\CRMStatisticsJob.Codeunit.al:242-276`) + `UpdateStatusOfPaidInvoices` (349-380); Message. | `OnCreateOrUpdateCRMAccountStatisticsOnBeforeModify(var CRMAccountStatistics; var Customer)` (CRMStatisticsJob:266, decl 470), field tweak only. | **N** |
| `SendResultNotification(RecVariant)` M:3264-3301 | public | Called from Customer Card OnAfterGetCurrRecord (2398); notification from CIR last synch result / job errors. | none | N |

### B.2 Create flows

| Procedure | Access | What it does | Events | Takeover |
|---|---|---|---|---|
| `CreateNewRecordsInCRM(RecVariant)` M:739-759 | public | `GetRecordRef`; `GetIntegrationTableMappingFromCRMRecord` (non-Account → by RecordId/table); builds `Dictionary[MappingName → SystemIds]`; calls `CreateNewRecordsInCRM(Dictionary)` (M:828-833, OnPrem) → `CreateNewRecords` (M:937-1013: per mapping, skip already-coupled valid rows, delete corrupt couplings, `EnqueueCreateNewJob` M:1015-1036 → Direction ToIntegrationTable → `EnqueueSyncJob(…, false)`). | `OnBeforeGetIntegrationTableMappingFromCRMRecord`, `OnAfterGetIntegrationTableMappingFromCRMRecordBeforeFindRecord`, B.0 | **N** |
| `CreateNewRecordsFromSelectedCRMRecords(RecVariant)` M:1051-1055 (OnPrem) → `CreateNewRecordsFromCRM(RecVariant)` M:906-926 | public | Mapping from the CRM record (Account → Customer/Vendor by CustomerTypeCode M:1590-1600), collects CRM IDs (`"Integration Table UID Fld. No."`), → `CreateNewRecords` → Direction FromIntegrationTable. **The mapping Direction is not checked**, so a ToIntegrationTable mapping still enqueues a FromIntegrationTable job. | same | N |
| `CreateNewRecordsFromSelectedCRMOptions(RecVariant)` M:835-864 (Cloud) | public | `GetIntegrationTableMappingFromCRMOption`; `CRMOptionMapping.FindRecordID` skip; `EnqueueOptionSyncJobFromIntegrationTable` (M:866-877). | `OnGetTableIdFromCRMOption` | N |
| `CreateNewContactFromCRM` / `CreateNewCustomerFromCRM` / `CreateNewVendorFromCRM` M:2187-2209 | public | `GetIntegrationTableMapping(…, DATABASE::Contact/Customer/Vendor)` (only to error if missing), then `PAGE.RunModal("CRM Contact List" / "CRM Account List")`. The vendor variant opens the same CRM Account List. | B.0 | N |
| `CRMSalesOrderToSalesOrder.CreateInNAV(CRMSalesorder; var SalesHeader): Boolean` `Integration\D365Sales\CRMSalesOrdertoSalesOrder.Codeunit.al:268-283` | public | Unidirectional sales-order create. | `OnCreateInNAVOnBeforeCheckState(CRMSalesorder; var IsHandled)` (279), skips the state check only. | N |
| `HasUncoupledSelectedUsers` M:3604-3615; `CoupleCRMEntity(RecordID; CRMID; var Synchronize; var Direction)` M:3454-3473 | public | Systemuser helpers; `CoupleCRMEntity` couples via CRB + `CIR.CoupleRecordIdToCRMID` + optional `PerformInitialSynchronization`. | none | N |

### B.3 Skipped-record and maintenance procedures

| Procedure | Access | What | Events |
|---|---|---|---|
| `UpdateSkippedNow` (4 overloads) M:609-654 | public | Clear Skipped on CIR / CRM Option Mapping, then notify. | none |
| `UpdateAllSkippedNow` M:656-670 | public | ModifyAll Skipped=false. | none |
| `MarkLocalDeletedAsSkipped` M:1087-1132 | internal | Mappings Type Dataverse, `Direction <> Bidirectional`, not Sales Header: mark CIR rows whose local record is outside the table filter. | none |
| `RepairBrokenCouplings` M:1134-1158 | public | Fix CIR rows with Table ID 0. | none |
| `ResetIntTableMappingDefaultConfiguration(var ITM)` M:2268-2354 (OnPrem) | public | Hard-coded `case "Table ID"` → CDSSetupDefaults/CRMSetupDefaults Reset* per table; `AddExtraFieldMappings` (M:2356-2412). | `OnBeforeHandleCustomIntegrationTableMapping(var IsHandled; IntegrationTableMappingName; var ITM; EnqueueJobQueEntries)` (M:2340, decl 4187), **only for tables not in the case list**; `OnAfterAddExtraFieldMappings(IntegrationTableMappingName)` (M:2411). |
| `ITM.SynchronizeNow(Reset…; Reset…OnRecords)` ITM:757-791 | public | Used by setup pages and the mapping list; `CRMSetupDefaults.CreateJobQueueEntry(Rec)`. | **`OnSynchronizeNow(var IntegrationTableMapping; ResetLastSynchModifiedOnDateTime; ResetSynchonizationTimestampOnRecords; var IsHandled)`** (ITM:769, decl 1235). **Y**, full takeover. |
| `ITM.SynchronizeOptionNow` ITM:794-813 (OnPrem) | public | Option variant. | none |
| `ITM.IsMappingEnabled(RequestedDirection)` ITM:1105-1137 / `IsFieldMappingEnabled` ITM:1139-1164 | public | Checks mapping Direction compatibility + at least one enabled field mapping in that direction. **Not used by any page**. A natural basis for direction-aware visibility. | `OnBeforeIsMappingEnabled(RequestedDirection; var Result; var IsHandled)` (ITM:1250), `OnBeforeIsFieldMappingEnabled` (ITM:1255). |

---

## C. Other non-engine entry points

### C.1 `OpenCoupledNavRecordPage` (used by CRM Redirect)

`M:1916-1953`, public `OpenCoupledNavRecordPage(CRMID: Guid; CRMEntityTypeName: Text): Boolean`.
1. `OnBeforeOpenCoupledNavRecordPage(CRMID; CRMEntityTypeName; var Result; var IsHandled)` (M:1926, decl 4222). **IsHandled → exit(Result). Full takeover.** The FS subscriber FSR:2921-2932 handles `msdyn_workorder` when only the archive exists (`subscribers-fs.md` #31).
2. `SD.GetTableIDCRMEntityNameMapping` (SD:2492-2547): a hard-coded entity-name ↔ table list + `OnAddEntityTableMapping`. Base CDS adds `'account'`→Vendor (`subscribers-cds.md`); FS adds its entities and **deletes** `'product'`→Resource (`subscribers-fs.md` D2).
3. `FindRecordFromNameValueBuffer` (M:1955-1970) uses `CIR.FindRecordIDFromID(CRMID, TableId)`. If the record is not found, `GetIntegrationTableMappingFromCRMID` (M:3138-3182) runs. **Direction check:** only when `Direction in [Bidirectional, FromIntegrationTable]` and not `"Synch. Only Coupled Records"` does it run a synchronous pull `SynchFromIntegrationTable` (M:1972-1992: temporary child mapping, `Codeunit.Run("Synch. Codeunit ID")`) (M:1941-1945). Otherwise it returns false.
4. `OpenRecordCardPage` (M:1994-2072): `OnBeforeOpenRecordCardPage(RecordID; var IsHandled)` (M:2011, decl 266), **IsHandled, full takeover of which page opens** (FS subscriber FSR:2934 for Service Header). Otherwise there is a hard-coded `case TableNo` (Contact, Currency, Customer, Vendor, Item, Sales Invoice Header, Resource, Salesperson, Unit of Measure, Customer Price Group), else Error.

### C.2 The CRM Redirect page

See A.7. The enablement check in OnOpenPage (`CRMRedirect.Page.al:47-53`) has no event. A dependent app can only influence it through `OnIsCDSIntegrationEnabled` (force true).

### C.3 Coupling dialog: page 5336 "CRM Coupling Record" + "Coupling Record Buffer" + "CRM Coupling Fields"

* `CRP:139-152 SetSourceRecordID(RecordID; IsOption)`: `Rec.Initialize` (CRB:191-227). For Sales Header with bidirectional SO integration, `"Create New" := IsNullGuid("CRM ID")`. `EnableCreateNew := (Sync Action = To Integration Table) or bidirectional`.
* `CRB:191-227 Initialize`: `Validate("NAV Table ID")` → **CRB:61-72** sets `"CRM Table Name"` = the first mapping with `Type = Dataverse`, `Table ID` (no codeunit or integration-table filter). `"CRM Table ID" := SD.GetCRMTableNo(NAV Table ID)` (SD:2226-2271; `OnGetCDSTableNo(BCTableNo; var CDSTableNo; var handled)` decl SD:2618, IsHandled; CDS and FS subscribe). Default Sync Action from `SD.GetDefaultDirection` (SD:2273-2307; `OnBeforeGetDefaultDirection(NAVTableId; var DefaultDirection; var IsHandled)` decl SD:2708) for records, or from the mapping via `ITM.FindMappingForTable` (ITM:426-431) + `GetDirection` (ITM:453-459) for options. If already coupled: "Do Not Synchronize".
* Page fields: `CRMName` OnValidate/OnLookup (CRP:54-90) call `Rec.LookUpCRMName()` (CRB:317-332) → `LT.Lookup` / `LT.LookupOptions`. On validate, the integration-filter check uses a mapping with **`"Synch. Codeunit ID" = CRM Integration Table Synch.`, Table ID and Integration Table ID** (CRP:74-86). `SyncActionControl` (CRP:42-48) offers both directions regardless of mapping Direction. `CreateNewControl` (CRP:94-100). Part "CRM Coupling Fields" (`Integration\Dataverse\CRMCouplingFields.Page.al:60-103`) lists the enabled field mappings of `"CRM Table Name"`.
* **LT (Lookup CRM Tables), the "table-relation lookup" to Dataverse:**
  * `LT:18-53 Lookup(CRMTableID; NAVTableId; SavedCRMId; var CRMId): Boolean` raises **`OnLookupCRMTables(CRMTableID; NAVTableId; SavedCRMId; var CRMId; IntTableFilter; var Handled)`** (LT:25, decl 509). **IsHandled, full takeover of the lookup.** The FS subscriber `fs:Codeunits\FSLookupFSTables.Codeunit.al:11` handles its tables. Otherwise there is a hard-coded `case` with 11 CRM tables (LT:29-51).
  * `LT:55-74 LookupOptions` raises **`OnLookupCRMOption(…; var Handled)`** (LT:62, decl 514).
  * `LT:443-455 GetIntegrationTableFilter`: mapping by codeunit + pair.
  * `LT:457-505 GetIntegrationTableMappingView`: used by all CRM/FS list pages.
  * No BC master table has a `TableRelation` to a Dataverse proxy table. The only ones are setup fields: `CRMConnectionSetup.Table.al:264`, `CDSConnectionSetup.Table.al:160,257`, `fs:Tables\FSConnectionSetup.Table.al:170` (BaseCurrencyId → CRM Transactioncurrency).
* There is no OnBefore event on the dialog itself, in CM.DefineCoupling, or in M.DefineCoupling.

### C.4 Match-based coupling

Entry points:
* list pages (`MatchBasedCoupling(RecRef)`)
* Integration Table Mapping List (`MatchBasedCoupling(TableID)`, `IntegrationTableMappingList.Page.al:473`)
* CDS Couple Salespersons (`CDSCoupleSalespersons.Page.al:164-181`)
* Full Synch Start (`CRMFullSynchReviewLine.Table.al:247`)
* CDS/CRM Full Synch Review drill-downs (open the criteria page only)

Implementation in B.1. The criteria page (`MatchBasedCouplingCriteria.Page.al:145-188`) saves to the mapping. The coupling job then runs `CDS Int. Table Couple` / `CDS Int. Option Couple`; those engine events are covered in `subscribers-cds.md`. **No IsHandled before the criteria page or before scheduling.** Mapping selection is always by BC table ID (M:1546-1553).

### C.5 "Create in Dataverse" / "Create from Dataverse"

See B.2. Entry points:
* Create in Dataverse: Customer List 606, Vendor List 825, Contact List 423, Posted Sales Invoice 852, Posted Sales Invoices 415; the coupling dialog with "Create New" (M:2134-2135); `DefineOptionMapping` → `CreateNewOptionsInCRM` (M:2165-2166).
* Create from Dataverse: the CRM/FS list pages in A.4; CRM Sales Order (5380) 420-435.

None checks mapping Direction. There is no IsHandled.

### C.6 CRM statistics

* Manual: `CreateOrUpdateCRMAccountStatistics` (B.1) from Customer Card 1214 / Customer List 526 [V `CRMIntegrationEnabled`, E Coupled].
* Job: codeunit "CRM Statistics Job" `Integration\D365Sales\CRMStatisticsJob.Codeunit.al`. OnRun (19-22) calls `UpdateStatisticsAndInvoices` (41-60: Error unless CRM "Is Enabled", own named connection) → `UpdateAccountStatistics` (62-150) / `UpdateInvoices` (198-211). Events: `OnAfterAddCustomersWithLinesActivity(StartDateTime; var CustomerNumbers)` (195, decl 465) and `OnCreateOrUpdateCRMAccountStatisticsOnBeforeModify` (266, decl 470). It has its own subscribers (not in the other inventories): `OnFindingIfJobNeedsToBeRun` on Job Queue Entry (421-435), and `DeleteAccountStatisticsOnAfterUncoupleRecord` on `Int. Rec. Uncouple Invoke.OnAfterUncoupleRecord` (438-452).
* Factbox: A.7. **No takeover**; the statistics are tied to CRM Account + "CRM Account Statistics".

### C.7 Full synchronization

* Pages 5331 / 7208 (A.6), started from setup pages (CRM 441, CDS 490, FS 301) and the CDS wizard (797-806).
* Table "CRM Full Synch. Review Line" `Integration\Dataverse\CRMFullSynchReviewLine.Table.al`:
  * `Generate` (137-166) → `GenerateCRMSynchReviewLines` (168-209): mappings with `Type = Dataverse`, `"Synch. Codeunit ID" = CRM Integration Table Synch.`, not temporary, plus **hard-coded name filters** (186-199; e.g. `'CUSTOMER|VENDOR|CONTACT|CURRENCY|PAYMENT TERMS|SHIPPING AGENT|SHIPMENT METHOD|SALESPEOPLE'` when CRM is not enabled). Uses `CRMSynchHelper.OnGetCDSOwnershipModel` (180).
  * `Start` (233-259): "Full Synchronization" → `M.EnqueueFullSyncJob(Name)` (M:1676-1692, by mapping name); "Couple Records" → `M.MatchBasedCoupling(ITM."Table ID", true, true, false)` (by table ID).
  * `GetInitialSynchRecommendation` (262-...).
  * No IntegrationEvent is declared in the table.
* `ITM.SynchronizeNow` has the takeover event `OnSynchronizeNow` (ITM:769), used by "Synchronize Modified Records" / "Run Full Synchronization" on the setup pages and the mapping list. `EnqueueFullSyncJob` has none.

### C.8 Option mapping (Payment Terms, Shipment Method, Shipping Agent)

Pages A.2 (CDS-only visibility). Procedures:
* `DefineOptionMapping` M:2156
* `RemoveOptionMapping` M:1266
* `ShowOptionLog` M:3427
* `UpdateMultipleNow(…, true)` → `UpdateOptions` M:549-601. Direction: the prompt `GetSelectedMultipleSyncDirection` uses the mapping Direction. For a Bidirectional mapping it shows the 2-choice StrMenu `UpdateNowUniDirectionQst` 'Send…,Get…' (M:65, M:2492), which returns To (1) or From (2). Only the From/To branches exist in M:570-598.
* `CreateNewRecordsFromSelectedCRMOptions` M:835-864
* `CreateOptionMapping` M:1301-1316
* `GetMappedCRMOptionId` M:1318-1329

Events: `OnGetTableIdFromCRMOption`, `CRB.OnFindCRMOptionByName`, `LT.OnLookupCRMOption`. Page "CRM Option Mapping" 5334 is opened from the mapping list (`IntegrationTableMappingList.Page.al:123-126`).

### C.9 Integration Table Mapping List actions

See A.6. Takeover:
* `SynchronizeNow` and `SynchronizeAll` / `UnconditionalSynchronizeAll` (non-option mappings) go through `ITM.SynchronizeNow` → `OnSynchronizeNow` IsHandled (**Y**).
* Option mappings go through `SynchronizeOptionNow` (**N**).
* `RemoveCoupling` → `M.RemoveCoupling(TableID, CRMTableID)` (**N**).
* `MatchBasedCoupling` → by table ID (**N**).
* `ResetConfiguration` → `OnBeforeHandleCustomIntegrationTableMapping`, only for unknown tables (**P**).

### C.10 Connection setup page actions

See A.6. They are mostly setup-specific (`CDSIntegrationImpl`, codeunit 7201 SingleInstance, `Integration\Dataverse\CDSIntegrationImpl.Codeunit.al`):
* `ScheduleRebuildingOfCouplingTable` 4979-4985 (Confirm + Hyperlink only)
* `AddCoupledUsersToDefaultOwningTeam` 1879-1945
* `TestConnection` 4528-4534
* `ShowIntegrationUser` / `ShowOwningTeam` 4891-4908
* `ImportAndConfigureIntegrationSolution` 3292-3319
* `RegisterAssistedSetup` 2715-2736

`SetupDefaults.ResetConfiguration`: FS has `OnBeforeResetConfiguration(var FSConnectionSetup; var IsHandled)` (`fs:Codeunits\FSSetupDefaults.Codeunit.al:1360`) plus per-mapping `OnBeforeReset…Mapping` IsHandled (1365-1410), as listed in `subscribers-fs.md`.

### C.11 Error-list and skipped-record entry points

* "Integration Synch. Error List" Synchronize → `OnForceSynchronizeDataIntegration(LocalRecordID; var SynchronizeHandled)` / `OnForceSynchronizeRecords(var LocalRecordIdList; var SynchronizeHandled)` (`IntegrationSynchJobErrors.Table.al:242,247`). This is a **takeover point if the dependent app's subscriber runs first**. The base subscriber M:3645-3656 exits only if SynchronizeHandled is already true, and AL subscriber order is not guaranteed, so it is not deterministic.
* Source/Destination drill-downs: `OnOpenSourceRecord` / `OnOpenDestinationRecord` (IsHandled, **Y**).
* Coupling actions there and on "CRM Skipped Records": **N**.

---

## D. Takeover points (events that let a dependent app replace the behaviour completely)

| Entry point | Event (publisher, file:line) | Notes |
|---|---|---|
| CRM Redirect → open coupled record | `OnBeforeOpenCoupledNavRecordPage(CRMID; CRMEntityTypeName; var Result; var IsHandled)` M:4222 (raised M:1926) | Full. The FS subscriber FSR:2921 respects IsHandled/Result. |
| Which card page the redirect opens | `OnBeforeOpenRecordCardPage(RecordID; var IsHandled)` M:266 (raised M:2011) | Full. The FS subscriber FSR:2934 does **not** check IsHandled on entry. |
| Dataverse record lookup in the coupling dialog | `OnLookupCRMTables(...; var CRMId; IntTableFilter; var Handled)` LT:509 (LT:25) | Full for the lookup only. |
| Option lookup in the coupling dialog | `OnLookupCRMOption(...; var Handled)` LT:514 (LT:62) | Full for the lookup only. |
| "Synchronize Modified Records" / "Run Full Synchronization" (setup pages, mapping list; non-option) | `OnSynchronizeNow(var IntegrationTableMapping; ...; var IsHandled)` ITM:1235 (ITM:769) | Full. |
| Error list → Synchronize | `OnForceSynchronizeDataIntegration` / `OnForceSynchronizeRecords` `IntegrationSynchJobErrors.Table.al:242/247` | Shared Handled flag; subscriber order is not deterministic against M:3645/3658. |
| Error list → open source/destination | `OnOpenSourceRecord` / `OnOpenDestinationRecord` `IntegrationSynchErrorList.Page.al:411/416` | Full. |
| Is-CRM-table classification | `OnIsCRMTable(TableID; var IsCRMTable; var Handled)` M:4212 | Full, but only a classification. |
| "Coupled to" field used by match-based coupling | `OnBeforeFindCoupledToCRMField(TableNo; var IsHandled; var CoupledFieldNo)` M:4227 | Full for field selection. |
| BC table → Dataverse table / default direction / entity name | `SD.OnGetCDSTableNo` SD:2618, `SD.OnBeforeGetDefaultDirection` SD:2708 (IsHandled), `SD.OnAddEntityTableMapping` SD:2623 / `OnBeforeAddEntityTableMapping` SD:2718 | Registry-level. These drive the coupling dialog defaults and URLs. |
| Entity URL ("open in Dataverse") | `OnAfterGetCRMEntityUrlFromCRMID(...; var CRMEntityUrl; ...)` M:4232; `OnGetCDSServerAddress(var CDSServerAddress; var handled)` M:246 | The URL can be replaced, but the coupling check and `DefineCouplingIfNotCoupled` prompt run before it (M:1864). |
| Direction-aware visibility helper | `ITM.IsMappingEnabled` ITM:1105 + `OnBeforeIsMappingEnabled` ITM:1250 | Not used by any page today. Available to a redesign. |
| Mapping tie-break (several mappings per BC table) | `OnBeforeGetIntegrationTableMappingWithRecordId(var ITM; RecId; var TableID)` M:4242, `OnBeforeGetIntegrationTableMapping(var ITM; TableID)` M:4177 | Not IsHandled. They can only add filters (e.g. on Name) before `FindFirst`. The Type/Synch codeunit/Table ID filters are re-applied (M:1567-1573). |
| Default mapping reset for custom tables | `OnBeforeHandleCustomIntegrationTableMapping(var IsHandled; ...)` M:4187 | Only for tables not in the hard-coded case list (M:2289-2338). |
| FS default configuration | `OnBeforeResetConfiguration(var FSConnectionSetup; var IsHandled)` `fs:Codeunits\FSSetupDefaults.Codeunit.al:1360` | Full. |

## E. Entry points with NO takeover point

For these, the redesign must hide the standard action (pageextension `modify(<action>) { Visible = false; }`; note the base groups' Visible is a page variable that cannot be overridden) and add its own.

1. **Open in Dataverse**: `ShowCRMEntityFromRecordID` (M:1860). Only the URL is overridable (see D). Every `CRMGoto*`/`CDSGoto*`/`GoToProductFS` action in A.1-A.5.
2. **Synchronize**: `UpdateOneNow` / `UpdateMultipleNow` (M:363-607). Only the confirm can be skipped (`OnBeforeSynchronyzeNowQuestion` M:4192, multi/unidirectional). All `CRMSynchronizeNow`/`CDSSynchronizeNow`/`SynchronizeNowFS` actions, plus Skipped Records `CRMSynchronizeNow`.
3. **Set Up Coupling**: `DefineCoupling` (M:2125 / CM:70) and the coupling dialog (CRP/CRB). The dialog does not honour Direction (0.3).
4. **Set Up Coupling for options**: `DefineOptionMapping` (M:2156 / CM:43).
5. **Delete Coupling**: `CRMCouplingManagement.RemoveCoupling` (CM:97-126) and all `M.RemoveCoupling` overloads (M:1160-1433); `RemoveOptionMapping` (M:1266); `DeleteCouplings` on the Skipped Records and Error List buffers.
6. **Match-Based Coupling**: `MatchBasedCoupling` (M:1174-1221, 1331-1355). Always by table ID.
7. **Synchronization Log**: `ShowLog` / `ShowOptionLog` (M:3417-3438).
8. **Create in Dataverse**: `CreateNewRecordsInCRM` (M:739/828), `CreateNewOptionsInCRM` (M:761/790).
9. **Create in Business Central**: `CreateNewRecordsFromSelectedCRMRecords` / `CreateNewRecordsFromCRM` (M:906-1055), `CreateNewRecordsFromSelectedCRMOptions` (M:835), `CreateNewContact/Customer/VendorFromCRM` (M:2187-2209), `CRMSalesOrderToSalesOrder.CreateInNAV` (only the state check is skippable).
10. **Update Account Statistics** and the statistics factbox drill-downs: `CreateOrUpdateCRMAccountStatistics` (M:1845), `ShowCustomerCRMOpportunities/Quotes/Cases` (M:2212-2266).
11. **Integration Table Mapping List**: Delete Couplings (`M.RemoveCoupling(TableID, CRMTableID)`), Match-Based Coupling, option "Synchronize" (`SynchronizeOptionNow`).
12. **Full Synch Review "Sync All"** (`CRMFullSynchReviewLine.Start` 233-259, plus `EnqueueFullSyncJob` M:1676). Only the non-option per-mapping path via `ITM.SynchronizeNow` is hookable, and Start does not use it.
13. **Skipped Records**: Retry / Retry All / Find for Deleted (`UpdateSkippedNow`, `UpdateAllSkippedNow`, `MarkLocalDeletedAsSkipped`).
14. **CRM Redirect enablement guard** (`CRMRedirect.Page.al:47-53`). It can only be forced open through `OnIsCDSIntegrationEnabled`.
15. **Page visibility itself**: no page raises an event to compute `CRMIntegrationEnabled`/`CDSIntegrationEnabled`/`CRMIsCoupledToRecord`/`BlockedFilterApplied`. The hard-coded mapping names (`'CUSTOMER'`, `'VENDOR'`, `'ITEM-PRODUCT'`, `'RESOURCE-PRODUCT'`, `'PLHEADER-PRICE'`, `'SALESORDER-ORDER'`) and filter literals (`'Field39=1(0)'`, `'Field54=1(0)'`, `'Field38=1(0)'`, `'Field40=1(0)'`, `'Field20=1(1)'`) cannot be changed.
