# CDS (Dataverse) module: event-subscriber inventory against the integration synch engine

Source: BC 29 Base Application, `src/base`. All paths are relative to `src/base/Integration/`.
Abbreviations:

- **CDSSub** = `Dataverse/CDSIntTableSubscriber.Codeunit.al` (codeunit 7205 "CDS Int. Table. Subscriber", `SingleInstance = true` at :30)
- **CRMSub** = `D365Sales/CRMIntTableSubscriber.Codeunit.al` (codeunit 5341 "CRM Int. Table. Subscriber", `SingleInstance = true` at :39)
- **Invoke** = `SynchEngine/IntegrationRecSynchInvoke.Codeunit.al` ("Integration Rec. Synch. Invoke")
- **RecSynch** = `SynchEngine/IntegrationRecordSynch.Codeunit.al` ("Integration Record Synch.")
- **OptInvoke** = `SynchEngine/IntOptionSynchInvoke.Codeunit.al` ("Int. Option Synch. Invoke")
- **Uncouple** = `SynchEngine/IntRecUncoupleInvoke.Codeunit.al` ("Int. Rec. Uncouple Invoke")
- **TblSynch** = `SynchEngine/IntegrationTableSynch.Codeunit.al` ("Integration Table Synch.")
- **CRMTblSynch** = `Dataverse/CRMIntegrationTableSynch.Codeunit.al` ("CRM Integration Table Synch.")
- **CRMMgt** = `Dataverse/CRMIntegrationManagement.Codeunit.al` ("CRM Integration Management", `SingleInstance` at :40)
- **Helper** = `D365Sales/CRMSynchHelper.Codeunit.al` ("CRM Synch. Helper")
- **Impl** = `Dataverse/CDSIntegrationImpl.Codeunit.al` ("CDS Integration Impl.", `SingleInstance` at :29)
- **Mgt** = `Dataverse/CDSIntegrationMgt.Codeunit.al` ("CDS Integration Mgt.", `SingleInstance` at :17). Its procedures are thin facades over Impl (for example SetCompanyId Mgt:188-191, SetOwningTeam Mgt:198-201, SetOwningUser Mgt:209-224, ResetCompanyId Mgt:178-181, option-set metadata Mgt:276-316).

How pairs are dispatched: CDSSub does **not** use the `Integration Table Mapping` passed by the engine to choose a branch. It builds a string `'<SourceTableName>-<DestTableName>'` from `RecordRef.Name()` (`GetSourceDestCode`, CDSSub:1554-1559) and switches on it with `case`. CRMSub uses the same scheme (CRMSub:1172-1177). So a branch is keyed on the **table-name pair and direction**, not on the mapping. A second mapping on the same pair, such as a custom or multi-company mapping, runs the same code.

## Where the engine raises the events (order inside one record synch)

| Step | Raised at | Notes |
|---|---|---|
| `OnTransferFieldData` (per field) | RecSynch:489 (publisher RecSynch:601) | Called from `TransferFieldData`. The first subscriber that sets `IsValueFound` wins, because every subscriber checks `if IsValueFound then exit`. |
| `OnUpdateConflictDetected` | Invoke:165 (publisher :733) | Only when both sides were modified and a bidirectional field changed. |
| `OnAfterUnchangedRecordHandled` | Invoke:210 (publisher :788) | After `UpdateIntegrationRecordCoupling` and before `UpdateIntegrationRecordTimestamp`. |
| `OnBeforeInsertRecord` | Invoke:234 (publisher :778) | Runs **before** `Insert` (:237) and before `ApplyConfigTemplate` (:238). |
| `OnAfterInsertRecord` | Invoke:244 (publisher :783) | Runs **after** coupling and `Commit()` (:243). The local record is re-fetched afterwards (:245-247). |
| `OnBeforeModifyRecord` / `OnAfterModifyRecord` | Invoke:259 / :264 (publishers :763 / :768) | `Modify(true)` happens between them. The local record is re-fetched after the After event. |
| `OnDeletionConflictDetected` | Invoke:355 (publisher :738), OptInvoke:260 (publisher :379) | |
| `OnAfterInsertOption` / `OnAfterModifyOption` | OptInvoke:160 / :199 (publishers :419 / :399) | |
| `OnBeforeUncoupleRecord` / `OnAfterUncoupleRecord` | Uncouple:100 / :132 (publishers :205 / :210) | |
| `OnAfterInitSynchJob` | TblSynch:71, :93 (publisher :679) | |
| `OnQueryPostFilterIgnoreRecord` | CRMTblSynch (publisher :936). It is raised in `SyncNAVRecordToCRM` and `SynchCRMTableToNAV`. | It is a CRM-codeunit event, not a generic engine event. |

---

## 1. Subscriber inventory: CDSSub (28 subscribers)

"Guard" means the condition checked before any logic runs. `(true,true)` marks attribute flags SkipOnMissingLicense and SkipOnMissingPermission set to true. Every other subscriber uses `(false,false)`.

### 1a. Synch-engine row and field events (the core of the redesign)

| # | Subscriber (CDSSub line) | Publisher.Event (exact) | Parameters used | Guard | Branches (BC table and Dataverse table) and logic |
|---|---|---|---|---|---|
| S6 | `HandleOnAfterInsertRecord` :131-167 | Codeunit "Integration Rec. Synch. Invoke".`OnAfterInsertRecord` | `var SourceRecordRef`, `var DestinationRecordRef` (IntegrationTableMapping is not taken) | **None at the subscriber level.** Some helpers have their own guard (see below). | `'CRM Account-Customer'`, `'CRM Account-Vendor'` (:138-143), meaning CRM Account to Customer or Vendor: (a) `SetCompanyIdOnCRMAccount` :236-259 stamps CompanyId on the source CRM Account and calls `RecRef.Modify()` against Dataverse; (b) `UpdateChildContactsParentCompany` :1161-1210 finds CRM Contacts under this account that are already coupled and runs `FixPrimaryContactNo` and `UpdateContactParentCompany` on each matching BC Contact. `'CRM Contact-Contact'` (:144-148), CRM Contact to Contact: `FixPrimaryContactNo` :1095-1159 sets Customer or Vendor "Primary Contact No." when it is blank, then `SetCompanyIdOnCRMContact` :211-234. `'Contact-CRM Contact'` (:149-150): `FixPrimaryContactIdInCDS` :1306-1356 sets CRM Account.PrimaryContactId when it is blank. `'CRM Systemuser-Salesperson/Purchaser'` (:151-152): `AddCoupledUserToDefaultOwningTeam` :183-209, a TryFunction, so its errors are swallowed. `'Customer-CRM Account'` (:153-165): moves the Contact to CRM Contact Dataverse mapping's "Synch. Int. Tbl. Mod. On Fltr." back to Customer.SystemCreatedAt so that child contacts are picked up. |
| S8 | `OnTransferFieldData` :261-450 | Codeunit "Integration Record Synch.".`OnTransferFieldData` | `SourceFieldRef`, `DestinationFieldRef`, `var NewValue`, `var IsValueFound`, `var NeedsConversion` | `if IsValueFound then exit` (:287), `CDSIntegrationImpl.IsIntegrationEnabled()` (:290), and a skip when the source and destination are the same field (:293-295) | **Not keyed by table pair.** It is keyed by field name or field relation, in this order: (1) destination field `OwnerId` (:297-317) under the **Ownership Model**: Team keeps the current destination value, Person uses `Helper.GetCoupledCDSUserId` (Helper:1628-1664 handles only Customer, Vendor, Contact and Sales Header). (2) Source field `OwnerId` (:319-343): Team keeps the destination value, Person uses `GetCoupledSalespersonPurchaserCode` :1517-1552 (only CRM Account and CRM Contact). (3) Destination `'Primary Contact No.'` with a blank or null-GUID source (:345-360): keeps the old value unless the old contact is coupled. (4) Source `Currency Code` to destination `TransactionCurrencyId` with a blank source and LCY different from the Dataverse base currency (:362-376): uses the LCY CRM Transactioncurrency. (5) The reverse, TransactionCurrencyId to `Currency Code` (:378-392): returns `''` when it is the LCY. (6) `Helper.FindNewValueForSpecialMapping(Src,Dst,..)` (:394-398, Helper:1995-2008: Opportunity."Contact Company No." to CRM Opportunity.ParentAccountId). (7) When `CRMMgt.IsUnitGroupMappingEnabled()` (:400-420): Item or Resource "Base Unit of Measure" and Price List Line "Unit of Measure Code" go to a UoM Id; CRM Product.DefaultUoMId goes to a base UoM; Unit Group codes get a prefix. **The Unit Group branch has no `exit`** (:415-419), so it falls through to (8). (8) `ConvertTableToOption`, then `ConvertOptionToTable`, then `AreFieldsRelatedToMappedTables`, which calls `FindNewValueForCoupledRecordPK` :1257-1304 and handles "Clear Value on Failed Sync" (:422-449). |
| S9 | `HandleOnBeforeInsertRecord` :452-506 | Codeunit "Integration Rec. Synch. Invoke".`OnBeforeInsertRecord` | `SourceRecordRef`, `DestinationRecordRef` **by value**. The publisher declares `var DestinationRecordRef` (Invoke:778). Writes still reach the engine because RecordRef has reference semantics. IntegrationTableMapping and InsertWithSystemId are not taken. | `CDSIntegrationImpl.IsIntegrationEnabled()` (:464) | `'Contact-CRM Contact'` (:469-470): `UpdateCRMContactParentCustomerId` :1038-1054 sets CRM Contact.ParentCustomerId from the BC company contact's Customer or Vendor coupling. If the source is CRM Account or CRM Product (:472-478), it **re-queries** the mapping (`Type::Dataverse`, `Table ID`, `Integration Table ID`, `FindFirst`) and takes `FindTableConfigTemplate` (Invoke:674-701). `'Customer-CRM Account'`, `'Contact-CRM Contact'`, `'Vendor-CRM Account'` (:481-487): `SetCompanyId` :1487-1494 and `SetOwnerId` :1496-1515 (Team calls `SetOwningTeam`; Person calls `SetOwningUser` for the coupled user and falls back to the team). `'Currency-CRM Transactioncurrency'` (:488-489): `SetDefaultSymbolOnCRMTransactioncurrencyIfEmpty` :1380-1388 copies ISO code to symbol. `'CRM Account-Customer'` (:490-493): `CustomerTemplMgt.FillCustomerKeyFromInitSeries`. `'CRM Account-Vendor'` (:494-497): `VendorTemplMgt.FillVendorKeyFromInitSeries`. `'CRM Product-Item'` (:498-501): `ItemTemplMgt.FillItemKeyFromInitSeries`. Destination Salesperson/Purchaser (:504-505), any source: `UpdateSalesPersOnBeforeInsertRecord` :1390-1416 generates the code `'SP NO. 0000n'`. |
| S10 | `HandleOnBeforeModifyRecord` :508-529 | Codeunit "Integration Rec. Synch. Invoke".`OnBeforeModifyRecord` | `IntegrationTableMapping` (not used), `SourceRecordRef`, `DestinationRecordRef` **by value** (the publisher's is `var`, Invoke:763) | `IsIntegrationEnabled()` (:513) | `'Contact-CRM Contact'` (:518-519): `UpdateCRMContactParentCustomerId`. `'Customer-CRM Account'`, `'Contact-CRM Contact'`, `'Vendor-CRM Account'` (:522-525): `SetCompanyId` only. OwnerId is **not** re-set on modify. `'Currency-CRM Transactioncurrency'` (:526-527): default symbol. |
| S11 | `HandleOnAfterModifyRecord` :531-539 | Codeunit "Integration Rec. Synch. Invoke".`OnAfterModifyRecord` | IntegrationTableMapping, Source, Dest | `IsIntegrationEnabled()` (:534) | Destination **Vendor**, any source in practice CRM Account (:537-538): `Helper.UpdateContactOnModifyVendor` (Helper:1148-1157), which calls `VendCont-Update.OnModify`. |
| S26 | `OnAfterUnchangedRecordHandled` :981-1004 | Codeunit "Integration Rec. Synch. Invoke".`OnAfterUnchangedRecordHandled` | IntegrationTableMapping, Source, Dest | `CDSConnectionSetup.Get()` and `"Is Enabled"` read directly (:988-992), not `IsIntegrationEnabled()` | `'Contact-CRM Contact'` (:995-1002): if CRM Contact.ParentCustomerId is empty, runs `UpdateCRMContactParentCustomerId` and then **`DestinationRecordRef.Modify()`** inside the subscriber (:1000). |
| S27 | `OnQueryPostFilterIgnoreRecord` :1006-1014 (**public** procedure) | Codeunit "CRM Integration Table Synch.".`OnQueryPostFilterIgnoreRecord` | `SourceRecordRef`, `var IgnoreRecord` | `if IgnoreRecord then exit`. The helper also checks `IsIntegrationEnabled()` (:1023). | Source **Contact**, used in the Contact to CRM Contact direction (:1012-1013): `HandleContactQueryPostFilterIgnoreRecord` :1016-1036 ignores the contact unless `IsContactBusinessRelationOptional` is true or its company has a Customer or Vendor business relation. |
| S15 | `HandleOnBeforeUncoupleRecord` :735-748 | Codeunit "Int. Rec. Uncouple Invoke".`OnBeforeUncoupleRecord` | IntegrationTableMapping, `var LocalRecordRef`, `var IntegrationRecordRef` | **None.** Only the event `OnHasCompanyIdField(IntegrationRecordRef.Number)` (:740) and `IsEmpty` (:744). | Any integration table whose CompanyId is declared through S14: `Mgt.ResetCompanyId` blanks CompanyId when it equals this company (Impl:3808-3815, 3818-3844; CRM Salesorder has special state-code handling at Impl:3847-3873). |
| S16 | `HandleOnAfterUncoupleRecord` :750-754 | Codeunit "Int. Rec. Uncouple Invoke".`OnAfterUncoupleRecord` | same | **None** | Customer or Vendor with **CRM Account** (`GetCoupledChildContacts` :765-822): collects coupled person Contacts under the company contact whose CRM Contact.ParentCustomerId is this account, then `CRMMgt.RemoveCoupling(Database::Contact, list, false)` (:756-763). |
| S12 | `HandleOnAfterModifyOption` :541-569 | Codeunit "Int. Option Synch. Invoke".`OnAfterModifyOption` | IntegrationTableMapping, Source, Dest | **`CRMMgt.IsCRMIntegrationEnabled()`** (:550). This is the Sales guard, not the CDS guard. | Option mappings (Payment Terms, Shipment Method, Shipping Agent to CRM option sets). It reads the option label and pushes it to the **salesorder, quote and invoice** option-set metadata through `UpdateOrInsertDocumentOptionSet` :571-586, using `Mgt.GetOptionSetMetadata`, `InsertOptionSetMetadataWithOptionValue` and `UpdateOptionSetMetadata`. |
| S13 | `HandleOnAfterInsertOption` :588-616 | Codeunit "Int. Option Synch. Invoke".`OnAfterInsertOption` | same | `IsCRMIntegrationEnabled()` (:597) | Identical to S12. The body is copy-pasted (:600-615 = :553-568). |
| S28 | `LogTelemetryOnAfterInitSynchJob` :1423-1473 `(true,true)` | Codeunit "Integration Table Synch.".`OnAfterInitSynchJob` | `ConnectionType`, `IntegrationTableID` | `ConnectionType = TableConnectionType::CRM` (:1432) | Telemetry only. Logs multi-company uptake (:1436-1451). Base entities are CRM Account, CRM Contact, CRM Transactioncurrency and CRM Systemuser (:1458-1468). Table IDs > 50000 count as custom entities (:1469-1472). |

### 1b. Dataverse service and configuration events (not row-level, but part of the same plug-in surface)

| # | Subscriber (CDSSub line) | Publisher.Event (exact) | Parameters | Guard | Logic |
|---|---|---|---|---|---|
| S1 | `HandleOnInitCDSConnection` :55-71 `(true,true)` | Codeunit "CRM Integration Management".`OnInitCDSConnection` (CRMMgt:236) | `var ConnectionName`, `var handled` | `handled`, `Impl.IsIntegrationEnabled()` | `Impl.RegisterConnection()` then `ActivateConnection()`. Sets `handled` and the default connection name. Raised from `CRMMgt.IsCDSIntegrationEnabled()` (CRMMgt:197-211), so **every IsCDSIntegrationEnabled() call can register or activate the connection**. |
| S2 | `HandleOnCloseCDSConnection` :73-84 `(true,true)` | CRM Integration Management.`OnCloseCDSConnection` (CRMMgt:256) | `ConnectionName`, `var handled` | `handled`, IsIntegrationEnabled | `Impl.UnregisterConnection` |
| S3 | `HandleOnTestCDSConnection` :86-97 `(true,true)` | CRM Integration Management.`OnTestCDSConnection` (CRMMgt:251) | `var handled` | same | `Impl.TestSystemUsersAvailability()` |
| S4 | `HandleOnGetCDSIntegrationUserId` :99-113 `(true,true)` | CRM Integration Management.`OnGetCDSIntegrationUserId` (CRMMgt:241) | `var IntegrationUserId`, `var handled` | same | `FindIntegrationUserId` :1577-1595 matches CRM Systemuser on email or domain name according to the auth type. Errors or notifies through `ShowError` :1561-1570. |
| S5 | `HandleOnGetCDSServerAddress` :115-129 `(true,true)` | CRM Integration Management.`OnGetCDSServerAddress` (CRMMgt:246) | `var CDSServerAddress`, `var handled` | same | Reads CDS Connection Setup."Server Address". |
| S17 | `HandleOnIsCDSIntegrationEnabled` :824-832 | CRM Integration Management.`OnIsCDSIntegrationEnabled` (CRMMgt:231) | `var isEnabled` | `if isEnabled then exit` | `Mgt.IsIntegrationEnabled()` |
| S18 | `HandleOnGetCDSBaseCurrencyId` :834-850 | Codeunit "CRM Synch. Helper".`OnGetCDSBaseCurrencyId` (Helper:2108) | `var BaseCurrencyId`, `var handled` | `handled`, Setup.Get, `"Is Enabled"` | Setup.BaseCurrencyId |
| S19 | `HandleOnGetCDSBaseCurrencySymbol` :852-868 | CRM Synch. Helper.`OnGetCDSBaseCurrencySymbol` (Helper:2118) | `var BaseCurrencySymbol: Text[5]`, `var handled` | same | Setup.BaseCurrencySymbol |
| S20 | `HandleOnGetCDSBaseCurrencyPrecision` :870-886 | CRM Synch. Helper.`OnGetCDSBaseCurrencyPrecision` (Helper:2123) | `var BaseCurrencyPrecision`, `var handled` | same | Setup.BaseCurrencyPrecision |
| S21 | `HandleOnGetCDSCurrencyDecimalPrecision` :888-904 | CRM Synch. Helper.`OnGetCDSCurrencyDecimalPrecision` (Helper:2128) | `var CurrencyDecimalPrecision`, `var handled` | same | Setup.CurrencyDecimalPrecision |
| S22 | `HandleOnGetCDSOwnershipModel` :906-922 | CRM Synch. Helper.`OnGetCDSOwnershipModel` (Helper:2113) | `var OwnershipModel: Option`, `var handled` | same | Setup."Ownership Model" |
| S23 | `HandleOnGetVendorSyncEnabled` :924-934 | CRM Synch. Helper.`OnGetVendorSyncEnabled` (Helper:2133) | `var Enabled` | `if Enabled then exit`, IsIntegrationEnabled | Sets `Enabled := true`. This is how Vendor to CRM Account becomes "on" for CDS. |
| S14 | `HandleOnHasCompanyIdField` :719-733 | Codeunit "CDS Integration Mgt.".`OnHasCompanyIdField` (Mgt:446) | `TableId`, `var HasField` | **None** | `HasField := true` for CRM Account, CRM Contact, CRM Invoice, CRM Quote, CRM Salesorder, CRM Opportunity, CRM Product and CRM Productpricelevel. Note: `Impl.FindCompanyIdField` (Impl:4069-4091) does **not** use this event. It looks up a GUID field named `CompanyId` in the `Field` table and caches the result. The event is consulted only by `Impl.HasCompanyIdField` (Impl:3739-3745) and S15. |
| S7 | `DeleteCouplingOnAfterDeleteSalesperson` :169-181 | Table "Salesperson/Purchaser".`OnAfterDeleteEvent` | `var Rec`, `RunTrigger` | Only `IsTemporary`. **No enablement guard.** | Deletes the CRM Integration Record for Rec.SystemId. |
| S24 | `HandleOnAfterCreatedNewCompanyByCopyCompany` :936-949 | Report "Copy Company".`OnAfterCreatedNewCompanyByCopyCompany` | `NewCompanyName` | None | DeleteAll on CDS Connection Setup, CRM Connection Setup and CRM Integration Record in the new company. |
| S25 | `DeleteCouplingOnBeforeDeleteCompany` :951-979 | Table Company.`OnBeforeDeleteEvent` | `var Rec`, `RunTrigger` | `IsTemporary`, then the deleted company's CDS setup `"Is Enabled"` | Asks for confirmation when couplings exist. Exits silently when there is no GUI and the license is suspended, deleted or locked out. |

### 1c. Other Dataverse-folder codeunits with subscribers to the synch engine or CRM synch

| Codeunit, file:line | Subscriber | Publisher.Event | Guard | Pair or logic |
|---|---|---|---|---|
| CRMMgt:2645-2678 | `HandleOnUpdateConflictDetected` | Integration Rec. Synch. Invoke.`OnUpdateConflictDetected` | `UpdateConflictHandled`, `IsCDSIntegrationEnabled() or IsCRMIntegrationEnabled()` | Generic, with no pair branching. Applies the mapping's "Update-Conflict Resolution" (Get from integration or Send to integration) and sets `SkipRecord`. |
| CRMMgt:2680-2720 | `HandleOnDeletionConflictDetected` | Integration Rec. Synch. Invoke.`OnDeletionConflictDetected` | same | Generic. "Remove Coupling" or "Restore Records". Special case: when `Table ID = Sales Line` and bidirectional Sales Orders is on, it also deletes the source (:2701-2703). |
| CRMMgt:4157-4172 | `HandleOnOptionDeletionConflictDetected` | Int. Option Synch. Invoke.`OnDeletionConflictDetected` | same | Generic. Removes the option mapping. |
| CRMMgt:3617-3624, Impl:5335-5340 | `IsDataIntegrationEnabled` (two subscribers) | Table "Integration Synch. Job Errors".`OnIsDataIntegrationEnabled` | `if not IsIntegrationEnabled` | CRM and CDS each OR in their own enabled flag. |
| CRMMgt:3626-3643 | `DisableConnectionOnAfterLongSynchError` | Integration Synch. Job Errors.`OnAfterLogSynchError` | none | Disables the CRM connection on a "CrmCreate"/"prvCreate" privilege error. |
| CRMMgt:3645-3656, :3658-3680 | `ForceSynchronizeDataIntegration`, `ForceSynchronizeRecords` | Integration Synch. Job Errors.`OnForceSynchronizeDataIntegration` / `OnForceSynchronizeRecords` | handled flag, CDS or CRM enabled | Runs `UpdateOneNow` or `UpdateMultipleNow`. |
| CRMTblSynch:980-996 | `IgnoreCompanyContactOnQueryPostFilterIgnoreRecord` | CRM Integration Table Synch.`OnQueryPostFilterIgnoreRecord` | `IgnoreRecord`, `Helper.IsContactTypeCheckIgnored()` | Contact: ignores Type = Company. |
| CRMTblSynch:1009-1024 | `OnSynchJobEntryCanBeRemoved` | Table "Integration Synch. Job".`OnCanBeRemoved` | `AllowRemoval` | Keeps job entries that still have skipped CRM Integration Records referring to them. |
| Impl:4946-4975 | `HandleOnRegisterServiceConnection` | Table "Service Connection".`OnRegisterServiceConnection` | none | Registers the CDS service connection status. |
| CDSSetupDefaults:1067-1101 | `ReturnProxyTableNoOnGetCDSTableNo` | Codeunit "CRM Setup Defaults".`OnGetCDSTableNo` | `handled`, Setup `"Is Enabled"` | **This is the BC-table to Dataverse-table pair registry:** Contact to CRM Contact, Currency to CRM Transactioncurrency, Customer and Vendor to CRM Account, Salesperson/Purchaser to CRM Systemuser, Payment Terms to CRM Payment Terms, Shipment Method to CRM Freight Terms, Shipping Agent to CRM Shipping Method. |
| CDSSetupDefaults:1103-1115 | `AddProxyTablesOnAddEntityTableMapping` | CRM Setup Defaults.`OnAddEntityTableMapping` | Setup `"Is Enabled"` | Adds `'account'` to Vendor. |
| CDSSetupDefaults:1362-… | `HandleOnEnableIntegration` | CDS Integration Mgt.`OnEnableIntegration` | none | Under the Person ownership model, recreates the SALESPEOPLE job and sets the Customer and Vendor mapping "Dependency Filter". |
| CDSTransformationRuleMgt:15-23 | `OnDeleteTransformationRule` | Table "Transformation Rule".`OnBeforeDeleteEvent` | IsTemporary | Blocks deletion when the rule is used in an Integration Field Mapping. |

---

## 2. Helper calls per branch and whether they are extensible

Legend: **EXT** means an IntegrationEvent with IsHandled or an equivalent override exists. **after-only** means an event lets you add behaviour but not replace it. **NONE** means there is no event at all.

| Branch (CDSSub) | Helper(s) called | Events raised by the helper (exact) | Extensible? |
|---|---|---|---|
| S6 CRM Account to Customer or Vendor | `SetCompanyIdOnCRMAccount` :236-259, which calls `Impl.CheckCompanyIdNoTelemetry` (Impl:3760-3773) and `SetCompanyId` (CDSSub:1487, then Mgt:188, then Impl:3754 `TrySetAndCheckCompany` :3776-3805) | none | NONE |
| | `UpdateChildContactsParentCompany` :1161-1210, which calls `Impl.TryGetCompanyId` (Impl:2847), `FixPrimaryContactNo`, `UpdateContactParentCompany` :1212-1255 and `Helper.SetContactParentCompany` (Helper:672-696) | `Helper.SetContactParentCompany` raises `OnFailedFindContactByAccountId` (Helper:686), only on failure | NONE (except the failure hook) |
| S6 CRM Contact to Contact | `FixPrimaryContactNo` :1095-1159 | `OnAfterFixPrimaryContactNo(SourceRecordRef, DestinationRecordRef, var Result)` (raised :1158, declared :1597-1600). Raised **only when neither the Customer branch nor the Vendor branch fixed anything**. No IsHandled. | after-only, partial |
| | `SetCompanyIdOnCRMContact` :211-234 | none | NONE |
| S6 Contact to CRM Contact | `FixPrimaryContactIdInCDS` :1306-1356, which uses `Invoke.WasModifiedAfterLastSynch` (Invoke:70-85) | none | NONE |
| S6 CRM Systemuser to Salesperson/Purchaser | `AddCoupledUserToDefaultOwningTeam` :183-209, which calls `Impl.SignInCDSAdminUser` (Impl:3324-3358) and `Impl.AddUsersToDefaultOwningTeam` (Impl:1909-1989) | none | NONE |
| S6 Customer to CRM Account | inline (:154-164) | none | NONE |
| S8 OwnerId, both directions | `Helper.GetCoupledCDSUserId` (Helper:1628-1664), `GetCoupledSalespersonPurchaserCode` :1517-1552 | none | NONE. The only override is another `OnTransferFieldData` subscriber, and the order between subscribers is undefined. |
| S8 Primary Contact No. or LCY currency | inline | none | NONE |
| S8 special mapping | `Helper.FindNewValueForSpecialMapping(Src,Dst,..)` (Helper:1995-2008) | none | NONE |
| S8 unit group | `Helper.ConvertBaseUnitOfMeasureToUomId` (Helper:1666-1724), `ConvertUomIdToBaseUnitOfMeasure` (:1778-1865), `PrefixUnitGroupCode` (:1867-1873) | none | NONE |
| S8 option conversions | `Helper.ConvertTableToOption` (Helper:1917-1935), `Helper.ConvertOptionToTable` (Helper:1937-1984) | `ConvertOptionToTable` raises `OnConvertOptionToTableOnBeforeSetRangeForIntegrationFieldID(CRMOptionMapping, SourceFieldRef, IsHandled)` (Helper:1956) | partial (filter only) |
| S8 coupled-record primary key | `Helper.AreFieldsRelatedToMappedTables` (Helper:1596-1626), then `FindNewValueForCoupledRecordPK` :1257-1304, which calls `Helper.FindNewValueForSpecialMapping(Src,..)` (Helper:1515-1536), `FindRecordIDByPK` (:1552), `FindPKByRecordID` (:1538) and `IsClearValueOnFailedSync` (:1581) | **`OnBeforeFindNewValueForCoupledRecordPK(IntegrationTableMapping, SourceFieldRef, DestinationFieldRef, var NewValueVariant, var IsValueFound, var IsHandled)`** (raised :1265, declared :1607-1610) | **EXT**. This is the only full override in S8. The clear-value-on-failed-sync post-processing at :434-447 still runs. |
| S9 and S10 Contact to CRM Contact | `UpdateCRMContactParentCustomerId` :1038-1054, which calls `FindParentCRMAccountForContact` :1056-1093 and `Helper.IsContactBusinessRelationOptional` (Helper:2037-2045) | **`OnBeforeFindParentCRMAccountForContact(SourceRecordRef, Silent, var AccountId, var Result, var IsHandled)`** (raised :1066, declared :1602-1605). `OnGetIsContactBusinessRelationOptional` (Helper:2041). | **EXT** for resolving the parent account. Writing ParentCustomerId is not extensible. |
| S9 Customer, Contact or Vendor to CRM Account or CRM Contact | `SetCompanyId` :1487-1494; `SetOwnerId` :1496-1515, which calls `Mgt.SetOwningTeam` / `SetOwningUser` (Impl:3912-3933 and `TrySetAndCheckOwner` Impl:3941) | none | NONE |
| S9 and S10 Currency to CRM Transactioncurrency | `SetDefaultSymbolOnCRMTransactioncurrencyIfEmpty` :1380-1388 | none | NONE |
| S9 CRM Account or CRM Product to Customer, Vendor or Item | `Invoke.FindTableConfigTemplate` (Invoke:674-701); `CustomerTemplMgt.FillCustomerKeyFromInitSeries` (Sales/Customer/CustomerTemplMgt:811), `VendorTemplMgt.FillVendorKeyFromInitSeries` (Purchases/Vendor/VendorTemplMgt:586), `ItemTemplMgt.FillItemKeyFromInitSeries` (Inventory/Item/ItemTemplMgt:704) | none in those procedures. Note: the engine's own `OnBeforeDetermineConfigTemplateCode` and `OnBeforeApplyRecordTemplate` are **bypassed**, because CDSSub calls `FindTableConfigTemplate` directly. | NONE |
| S9 any source to Salesperson/Purchaser | `UpdateSalesPersOnBeforeInsertRecord` :1390-1416 | **`OnBeforeSetSalespersonPurchaserCode(var DestinationRecordRef, var IsHandled)`** (raised :1402, declared :1418-1421) | **EXT** |
| S11 to Vendor | `Helper.UpdateContactOnModifyVendor` (Helper:1148-1157), then `VendCont-Update.OnModify` | `OnBeforeOnModify(Vend, ContBusRel, var IsHandled)` (CRM/BusinessRelation/VendContUpdate:53) and `OnAfterOnModify` (:90). These belong to the generic contact-update logic, not to the integration. | Downstream only |
| S26 Contact to CRM Contact | `UpdateCRMContactParentCustomerId`, then `Modify` | `OnBeforeFindParentCRMAccountForContact` | partial |
| S27 Contact post-filter | `Helper.IsContactBusinessRelationOptional`, `FindContactRelatedCustomer` (Helper:1168), `FindContactRelatedVendor` (Helper:1192-1208) | `OnGetIsContactBusinessRelationOptional` (Helper:2041). CRMSub's version of the same filter raises `OnAfterHandlePostFilterIgnoreRecord` (CRMSub:936), but that event belongs to CRMSub. | partial (global switch only) |
| S15 uncouple CompanyId | `Mgt.ResetCompanyId` (Impl:3808-3873) | none | NONE |
| S16 uncouple child contacts | `GetCoupledChildContacts` :765-822, `CRMMgt.RemoveCoupling` (CRMMgt:1160-1433, several overloads) | none | NONE |
| S12 and S13 option-set metadata | `UpdateOrInsertDocumentOptionSet` :571-586, `CRMOptionMapping.GetDocumentMetadataInfo`, `Mgt.GetOptionSetMetadata` / `InsertOptionSetMetadataWithOptionValue` / `UpdateOptionSetMetadata` (Mgt:276-316) | none | NONE |
| The enablement check itself | `Impl.IsIntegrationEnabled` (Impl:570-594) | `Mgt.OnGetDetailedLoggingEnabled` (:575) and `OnAfterIntegrationEnabled()` (:592). Neither can veto. | n/a |

Integration events declared in CDSSub (all `local`, `[IntegrationEvent(false,false)]`):

- `OnBeforeSetSalespersonPurchaserCode` :1418
- `OnAfterFixPrimaryContactNo` :1597
- `OnBeforeFindParentCRMAccountForContact` :1602
- `OnBeforeFindNewValueForCoupledRecordPK` :1607

CDSSub raises no other events.

---

## 3. Overlaps with the CRM (D365 Sales) module

The CDS and CRM subscribers both subscribe to the same engine events. AL defines **no ordering between subscribers to one event**, so each overlap below is handled in one of three ways: (a) mutual exclusion via `IsCDSIntegrationEnabled()`, (b) first-wins via `IsValueFound`/`IgnoreRecord`/`handled`, or (c) disjoint table pairs. Important consequence: **part of the "CDS" behaviour for the base pairs actually lives in CRMSub**.

| Event | Pair | CDSSub | CRMSub | How duplication or ordering is handled |
|---|---|---|---|---|
| `OnTransferFieldData` | **Customer, Vendor, Currency, Contact, Salesperson/Purchaser** (either side) | S8 :261-450 | :272-438 | CRMSub **exits** when CDS is enabled and either record is one of these 5 tables (CRMSub:299-302). Mutual exclusion: CDS handles the base pairs. |
| `OnTransferFieldData` | **All other pairs** (Item and Resource to CRM Product, Sales Header to CRM Salesorder, Sales Line, Opportunity, Price List, Unit Group, UoM, Payment Terms, and so on) | S8 runs whenever CDS is enabled | CRMSub runs too | **Both run, in undefined order. First to set `IsValueFound` wins** (CDS :287, CRM :289). The logic is duplicated with divergences. LCY currency appears in both (CDS :362-392, CRM :312-342). Unit group appears in both (CDS :400-420, CRM :402-422). Option conversions appear in both. Coupled primary key is in both, with **different** hooks: CDS `OnBeforeFindNewValueForCoupledRecordPK` with IsHandled (CDSSub:1265) versus CRM `OnFindNewValueForCoupledRecordPK` (CRMSub:3154/3280). Only CDS has clear-value-on-failed-sync and the Primary Contact No. rule. OwnerId: CDS handles **any** destination field named `OwnerId` (:297), for example CRM Opportunity or CRM Salesorder. Under the Person model that calls `GetCoupledCDSUserId`, which returns an empty GUID for tables other than Customer, Vendor, Contact and Sales Header (Helper:1641-1651). CRM handles OwnerId only for CRM Salesorder under bidirectional sync (CRMSub:352-373) and through `ShouldKeepOldValue` (CRMSub:389, 431-443). Only CRM has the write-in product logic (CRMSub:304-310, 344-349) and runs ShouldKeepOldValue *before* special mapping, while CDS runs special mapping first. **Result: the outcome depends on subscriber order.** |
| `OnBeforeInsertRecord` | Contact to CRM Contact | S9: `UpdateCRMContactParentCustomerId` (CDS-guarded) | CRMSub:509-510, which goes to CRMSub:1328-1343 | The CRM version **exits if CDS is enabled** (CRMSub:1335-1336). Mutual exclusion. |
| `OnBeforeInsertRecord` | **CRM Contact to Contact** | — | CRMSub:507-508 `UpdateContactParentCompany` (CRMSub:1200-1218) | **Only CRMSub**, and it has no CDS or CRM guard. CDS relies on CRMSub to link the BC contact to its company on insert. |
| `OnBeforeInsertRecord` | Currency to CRM Transactioncurrency | S9: default symbol | CRMSub:511-512: `UpdateCRMTransactionCurrencyBeforeInsertRecord` (CurrencyPrecision, CRMSub:2105-2112) | Complementary (different fields). Both always run. |
| `OnBeforeInsertRecord` | any source to Salesperson/Purchaser | S9: `UpdateSalesPersOnBeforeInsertRecord` :1390 (has IsHandled) | CRMSub:547-549, which goes to CRMSub:1304-1326 | The CRM version **exits when CDS is enabled** (CRMSub:1313-1314). The CDS version runs only when CDS is enabled (S9 guard :464). Mutual exclusion. The code is duplicated. |
| `OnBeforeInsertRecord` | Sales Header to CRM Salesorder | — | CRMSub:529-536 calls **`CDSIntTableSubscriber.SetOwnerId`** (CRMSub:535) and its own `SetCompanyId` | CRM calls into CDSSub's public procedure. The CDS owner logic is reused through a direct call, not through an event. |
| `OnBeforeModifyRecord` | Contact to CRM Contact | S10 | CRMSub:806-807 | Mutual exclusion, same as on insert. |
| `OnBeforeModifyRecord` | CRM Contact to Contact | — | CRMSub:804-805 | **Only CRMSub**, as on insert. |
| `OnBeforeModifyRecord` | Customer, Vendor or Contact to CRM, and Item/Resource/Opportunity/Invoice/Salesorder to CRM | S10 `SetCompanyId` for the base 3 | CRMSub:812-824 `SetCompanyId` for the sales entities (CRMSub:1161-1170, CDS-guarded) | Disjoint pairs. The two codeunits each have a **separate** SetCompanyId wrapper (CDSSub:1487, CRMSub:1161). |
| `OnAfterTransferRecordFields` | **CRM Account to Customer** | — | CRMSub:456-458 `UpdateCustomerBlocked` (Inactive sets Blocked = All) | **Only CRMSub**, with no CDS or CRM guard. It applies to the CDS base pair. |
| `OnAfterTransferRecordFields` | Currency to CRM Transactioncurrency | — | CRMSub:465-467 exchange rate | Only CRMSub. |
| `OnAfterModifyRecord` | CRM Account to Customer / CRM Account to Vendor | S11: Vendor, which calls `UpdateContactOnModifyVendor` | CRMSub:857-858: Customer, which calls `UpdateContactOnModifyCustomer` | Complementary by destination table. The Customer half of this "CDS" behaviour lives in CRMSub. |
| `OnAfterUnchangedRecordHandled` | Contact to CRM Contact | S26 | CRMSub:861-884 (sales pairs only) | Disjoint. |
| `OnFindUncoupledDestinationRecord` | Currency to CRM Transactioncurrency | — | CRMSub:1010-1012 (guard: CRM **or** CDS enabled) | Only CRMSub. It matches the CDS base pair. |
| `OnQueryPostFilterIgnoreRecord` | Contact (Contact to CRM Contact) | S27: needs a Customer **or Vendor** relation (CDS-guarded) | CRMSub:918-919, which goes to CRMSub:1220-1238: needs a Customer relation, **or** a Vendor relation when CDS is enabled; there is no IsIntegrationEnabled guard. CRMTblSynch:980-996 ignores Type = Company. | **Three subscribers**, all short-circuiting on `IgnoreRecord`. The results agree, but the logic is triplicated. CRMSub raises `OnAfterHandlePostFilterIgnoreRecord` (CRMSub:936). CDSSub raises nothing. |
| `OnAfterUncoupleRecord` | Customer or Vendor with CRM Account | S16: child Contacts | CRMSub:1082-1086: child Sales Lines (Sales Header with CRM Salesorder) | Disjoint. Both always run, neither has a guard. |
| `OnAfterInitSynchJob` | telemetry | S28: base entities and custom entities > 50000 | CRMSub:1043-1074: sales entities | Disjoint table lists. |
| `OnAfterInsertRecord` | CRM Product to Item / Resource | — | CRMSub:593-596 | Only CRMSub. Note that CDSSub S9 fills the Item key for `'CRM Product-Item'`, so the Item pair is split across both codeunits. |
| Connection, currency and ownership getters (S1-S5, S18-S22) | n/a | CDSSub | — (the CRM side publishes them) | `handled` pattern. CDS is the only base-app subscriber. |

---

## 4. Not extensible today (hard-coded, with no IntegrationEvent before or after and no IsHandled)

1. **Dispatch by table-name string.** `GetSourceDestCode` CDSSub:1554-1559 and every `case` that uses it (:137, :480, :521, :994). Branches cannot be added or replaced per mapping. Custom or extension tables cannot join an existing branch.
2. **Mapping re-query in OnBeforeInsertRecord.** CDSSub:472-478 ignores the engine's `IntegrationTableMapping` and takes `FindFirst` on (Dataverse, Table ID, Integration Table ID). With several mappings on one pair, the template it picks is arbitrary.
3. **Number-series key from template.** CDSSub:490-501 for CRM Account to Customer or Vendor and CRM Product to Item. It bypasses the engine's `OnBeforeDetermineConfigTemplateCode`/`OnBeforeApplyRecordTemplate` (Invoke:299-305) and calls `Fill*KeyFromInitSeries` directly, which raises no events.
4. **CompanyId stamping on insert and modify.** CDSSub:481-487 and :522-525, then `SetCompanyId` :1487-1494, then Impl:3754/3776-3805. Impl `FindCompanyIdField` (:4069-4091) finds the field by the name `CompanyId` and does not consult `OnHasCompanyIdField`.
5. **Owner assignment on insert.** `SetOwnerId` CDSSub:1496-1515, covering the Team/Person choice and the fallback to the team when there is no coupled user. Owner is never re-applied on modify (:521-528).
6. **OwnerId field transfer.** CDSSub:297-343. It applies to every destination or source field named `OwnerId` in any mapping. Person-model resolution is hard-coded to Customer, Vendor, Contact and Sales Header (Helper:1641-1651) and to CRM Account and CRM Contact (CDSSub:1526-1543).
7. **Primary Contact No. blank-value rule.** CDSSub:345-360.
8. **LCY versus Dataverse base-currency substitution.** CDSSub:362-392 (duplicated in CRMSub:312-342).
9. **Unit-group conversions.** CDSSub:400-420, including the missing `exit` at :415-419.
10. **Clear Value on Failed Sync post-processing.** CDSSub:432-449. It runs even when `OnBeforeFindNewValueForCoupledRecordPK` handled the value.
11. **Post-insert CRM Account handling.** `SetCompanyIdOnCRMAccount` :236-259 writes back to Dataverse after the engine's `Commit` (Invoke:243). `UpdateChildContactsParentCompany` :1161-1210 and `UpdateContactParentCompany` :1212-1255 modify the BC Contact and patch `CRM Integration Record."Last Synch. Modified On"`.
12. **Post-insert CRM Contact handling.** `FixPrimaryContactNo` :1095-1159: the Customer and Vendor branches are hard-coded, and the after-event fires only when neither applied (:1157-1158). `SetCompanyIdOnCRMContact` :211-234.
13. **Post-insert Contact to CRM Contact.** `FixPrimaryContactIdInCDS` :1306-1356 modifies CRM Account and patches `"Last Synch. CRM Modified On"`.
14. **Post-insert CRM Systemuser to Salesperson.** `AddCoupledUserToDefaultOwningTeam` :183-209 is a TryFunction, so failures are silent. Office365 auth only.
15. **Post-insert Customer to CRM Account.** Rewinds the Contact mapping's `"Synch. Int. Tbl. Mod. On Fltr."` (CDSSub:153-165). The mapping is found by `FindFirst`.
16. **Writing ParentCustomerId** in `UpdateCRMContactParentCustomerId` :1038-1054. Only the lookup part is extensible. The unchanged-record re-fix with `Modify()` at CDSSub:994-1003 is also hard-coded.
17. **Currency symbol default.** CDSSub:1380-1388.
18. **Vendor contact update after modify.** CDSSub:537-538. Only the downstream `VendCont-Update` events exist.
19. **Contact post-filter rule.** CDSSub:1016-1036. Only the global `OnGetIsContactBusinessRelationOptional` switch is available.
20. **Uncouple: CompanyId reset** at CDSSub:735-748 (no enablement guard) and **child-contact uncoupling** at CDSSub:750-822.
21. **Option-set metadata push** to salesorder, quote and invoice. CDSSub:541-616 (S12 and S13 duplicated) and `UpdateOrInsertDocumentOptionSet` :571-586. The public `SyncDocumentOptionSets` :618-717 hard-codes the entity and field names `'salesorder'`, `'quote'`, `'invoice'`, `'paymenttermscode'`, `'freighttermscode'` and `'shippingmethodcode'` (:638-643).
22. **Coupling deletion on Salesperson delete** (CDSSub:169-181), **Copy Company cleanup** (:936-949) and **company-delete confirmation** (:951-979).
23. **Telemetry classification.** CDSSub:1423-1485. Base-entity list at :1458-1462; the custom threshold of 50000 at :1482-1485.
24. **Integration user lookup.** `FindIntegrationUserId` CDSSub:1577-1595.
25. **Generic conflict resolution** in CRMMgt:2645-2720 (`OnUpdateConflictDetected`/`OnDeletionConflictDetected`). These use the handled flag, so an earlier subscriber can pre-empt them, but subscriber order is undefined. Sales Line deletion is hard-coded at CRMMgt:2702-2704.

Enablement-guard inconsistencies, relevant if each pair gets its own implementation:

- S6 (:131-167) has no top-level guard. Within it, `FixPrimaryContactNo`, `FixPrimaryContactIdInCDS`, `UpdateChildContactsParentCompany` and the `'Customer-CRM Account'` branch are unguarded.
- S7, S14, S15 and S16 have no guard.
- S12 and S13 are guarded by the **CRM** flag (CDSSub:550, :597).
- S18-S22 and S26 read `CDS Connection Setup."Is Enabled"` directly, which skips the permission check and the `OnAfterIntegrationEnabled` event in `Impl.IsIntegrationEnabled` (Impl:570-594).
- CRMSub's `UpdateContactParentCompany` and `UpdateCustomerBlocked` run for CDS pairs with no guard.

---

## 5. Global state, SingleInstance and BindSubscription

| Object | file:line | State |
|---|---|---|
| CDSSub | :30 `SingleInstance = true` | Globals :37-39: `CDSIntegrationMgt`, `CDSIntegrationImpl`, `CRMSynchHelper` (codeunit instances); otherwise labels only (:40-53). **No mutable data globals.** External callers that hold a local variable of this type (CRMSub:504, `D365Sales/CRMSalesOrdertoSalesOrder.Codeunit.al:329`, `D365Sales/CRMConnectionSetup.Table.al:97`) get the same session instance when they call `SetOwnerId` (CRMSub:535), `SetCompanyId` (CRMSalesOrdertoSalesOrder:336) and `SyncDocumentOptionSets` (CRMConnectionSetup.Table:111). |
| Impl | :29 `SingleInstance = true` | Session caches :34-44: `CachedCompanyIdFieldNo`, `CachedOwnerIdFieldNo`, `CachedOwnerTypeFieldNo` (Dictionary), `CachedOwningTeamCheck*`/`CachedOwningUserCheck*` (4 dictionaries), `CachedCompanyId`, `CachedDefaultOwningTeamId`, `CachedOwningBusinessUnitId`, `AreCompanyValuesCached`, filled by `InitializeCompanyCache` (Impl:4209+). CompanyId and owner checks used by S6, S8, S9 and S10 depend on these caches. |
| Mgt | :17 `SingleInstance = true` | Facade. |
| CRMMgt | :40 `SingleInstance = true` | `CDSIntegrationEnabledState` (:98), set in `IsCDSIntegrationEnabled` (:197-211). That procedure raises `OnIsCDSIntegrationEnabled`, which goes to S17, and then `OnInitCDSConnection`, which goes to S1 and registers or activates the connection as a side effect. |
| CRMSub | :39 `SingleInstance = true` | Globals :45-50 (codeunit instances: `CRMSynchHelper`, `CRMProductName`, `CDSIntegrationImpl`, `CRMIntegrationManagement`, `PrepaymentMgt`). |
| BindSubscription | CRMTblSynch:558/579 (`SynchNAVTableToCRM`), :616/641 (`SynchCRMTableToNAV`) | Binds codeunit 5368 "Int. Table Manual Subscribers" (`SynchEngine/IntTableManualSubscribers.Codeunit.al`, `EventSubscriberInstance = Manual` :11). Its only subscriber is Item.`OnValidateBaseUnitOfMeasure`, which forces validation (:13-17). **There is no other BindSubscription in the Dataverse folder.** All CDS subscribers are static (always bound), so they fire for every Dataverse-type mapping and for any other engine consumer whose table names match. |

### Implications for a per-table-pair interface design (factual summary)

- The table pairs touched by CDSSub are: CRM Account to Customer, CRM Account to Vendor, Customer to CRM Account, Vendor to CRM Account, CRM Contact to Contact, Contact to CRM Contact, Currency to CRM Transactioncurrency, CRM Systemuser to Salesperson/Purchaser, CRM Product to Item, and the option mappings (Payment Terms, Shipment Method, Shipping Agent). `OnTransferFieldData` S8 is pair-agnostic and also affects sales pairs.
- The pair registry for CDS is `CDSSetupDefaults.ReturnProxyTableNoOnGetCDSTableNo` (CDSSetupDefaults:1067-1101).
- Behaviour for CDS base pairs that lives in CRMSub, not CDSSub:
  - CRM Contact to Contact parent company (insert and modify)
  - CRM Account to Customer Blocked
  - Customer contact update after modify
  - Currency precision and exchange rate
  - Currency uncoupled-match
- Both codeunits key on table names and run in undefined relative order on `OnTransferFieldData`.
