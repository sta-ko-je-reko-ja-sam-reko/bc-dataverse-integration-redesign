# FEAT-DVI-001 - Core Pipeline

> **Source/legacy reference:** N/A (greenfield).
> **Affected objects:** Integration Table Mapping, CRM Integration Record, Application Area Setup (extended); the standard runners 5340, 5360 and 5337 (subscribed); new setup, assignment, engine and option objects listed below.
> **Namespaces:** `DataverseIntegration.Core`; tests `DataverseIntegration.Test`.

## Business Process

1. An administrator turns on **Dataverse Integration Redesign Setup → Enabled**. The session restarts and the
   redesigned pages and actions appear. While it is off, every mapping synchronizes exactly as Microsoft ships it.
2. On **Integration Table Mappings**, the administrator selects mappings and chooses **Use Redesigned
   Synchronization** (or **Switch All Mappings** on **Redesigned Integration Mappings**). Each selected mapping gets
   an assignment: the first handler value that serves its table pair (only *Generic* in this feature) and its module
   (Field Service when the Dataverse table belongs to the Field Service app, otherwise Dataverse).
3. The job queue starts the mapping's standard runner as before. Its `OnBeforeRun` event reaches
   `DVI Runner Events`, which delegates to `DVI Runner Dispatch`. If the feature is enabled, no other subscriber
   handled the run and the mapping (or the parent of a *Synchronize now* copy) is switched, the dispatch runs the
   redesigned engine and marks the run handled; the standard runner does nothing.
4. The engine opens the module's connection, then per allowed direction: starts an `Integration Synch. Job`, loads
   the candidate records (records whose last synchronization failed, then records changed after the mapping's
   watermark; on the Dataverse side excluding changes by the integration user on bidirectional mappings), and runs
   each one through the record pipeline inside `Codeunit.Run`, so one failing record is logged and the job goes on.
5. The record pipeline: find the coupled record (or ask the handler for an uncoupled match); a coupling to a deleted
   record goes to the conflict policy (restore, remove coupling, skip or fail); decide insert, modify or unchanged;
   handler `BeforeTransferFields`, transformation rules, field transfer, handler `AfterTransferFields`; a change on
   both sides of a bidirectional field goes to the conflict policy; insert (with the configuration template) or
   modify, handler before/after steps, coupling stamped with the mapping name, timestamps updated.
6. Follow-ups a step queued (dependent records) are synchronized after the record's own transaction, one job per
   mapping and direction.
7. Option mappings (Payment Terms, Shipment Method, Shipping Agent) run through the same takeover: option values are
   read from the Dataverse option-set metadata, created or renamed there through the metadata API, and coupled in
   `CRM Option Mapping`.
8. Coupling and uncoupling jobs (match-based coupling, uncouple) are taken over the same way and use the handler's
   coupling steps. Unmatched records are created in Dataverse only when the handler says so; coupled records are
   synchronized afterwards when the mapping asks for it.
9. Watermarks (`Synch. Modified On Filter`, `Synch. Int. Tbl. Mod. On Fltr.`) move forward, capped at the job's
   start, exactly as the standard runner does.

## Data Model

### New Tables

**80000 DVI Setup** (single record)

| # | Field | Type | Notes |
|---|---|---|---|
| 1 | Primary Key | Code[10] | Blank |
| 10 | DVI Enabled | Boolean | Switches the redesigned integration and its application area; changing it restarts the session |

**80003 DVI Mapping Assignment**

| # | Field | Type | Notes |
|---|---|---|---|
| 1 | Mapping Name | Code[20] | Primary key; the integration table mapping. Kept by name, so it survives Microsoft re-creating the mapping |
| 2 | Handler | Enum DVI Sync Handler | `Microsoft` = not redesigned; validated through `DVI IMappingLogic` |
| 3 | Module | Enum DVI Integration Module | Selects the connection guard |

**80001 DVI Follow-up Buffer** (temporary): Entry No., Mapping Name, Source System Id, To Integration Table.
**80002 DVI Option Value** (temporary): Option Id, Code; one Dataverse option value.

### New Fields on Existing Tables

| Object | Field | Type | Notes |
|---|---|---|---|
| Integration Table Mapping | 80000 DVI Handler | FlowField, Enum | Lookup of the assignment, for the mapping list |
| Integration Table Mapping | 80001 DVI Module | FlowField, Enum | Lookup of the assignment |
| CRM Integration Record | 80000 DVI Mapping Name | Code[20] | The mapping that created the coupling |
| Application Area Setup | 80000 DVI Redesign | Boolean | Application area `DVIRedesign`, on while Enabled |

## Objects

| Type | ID | Name | Purpose |
|---|---|---|---|
| Table | 80000 | DVI Setup | Enabled toggle |
| Table | 80001 | DVI Follow-up Buffer | Dependent records queued by a step |
| Table | 80002 | DVI Option Value | Option values read from Dataverse |
| Table | 80003 | DVI Mapping Assignment | Handler and module per mapping |
| Table extension | 80000 | DVI Application Area Setup | Application area |
| Table extension | 80001 | DVI Integration Table Mapping | Handler and module FlowFields |
| Table extension | 80002 | DVI CRM Integration Record | Mapping name on couplings |
| Enum | 80000 | DVI Sync Handler | Per-mapping implementation; implements the pipeline interfaces |
| Enum | 80001 | DVI Integration Module | Dataverse, Dynamics 365 Sales, Field Service; implements `DVI IConnection` |
| Enum | 80002 | DVI Synch Action | Actions and job counters |
| Enum | 80003 | DVI Deletion Outcome | Result of a deletion conflict |
| Interface | – | DVI IRecordSync | Transfer, insert, modify, unchanged steps |
| Interface | – | DVI IRecordCoupling | Uncoupled match, couple, uncouple, match filter, create on no match |
| Interface | – | DVI IRecordFilter | Leave a candidate record out |
| Interface | – | DVI IConflictPolicy | Update and deletion conflicts |
| Interface | – | DVI IOptionSource | Option set field and values of an option mapping |
| Interface | – | DVI IHandlerScope | Which table pair a handler serves; default module |
| Interface | – | DVI IConnection | Module guard and connection |
| Interface | – | DVI ITableSynch | The engine (replaceable) |
| Interface | – | DVI ICouplingRunner | Coupling and uncoupling jobs (replaceable) |
| Interface | – | DVI IRunnerDispatch | Reaction to the standard runners starting |
| Interface | – | DVI IMappingLogic | Validation of an assignment |
| Codeunit | 80000 | DVI Service Locator | Resolves dispatch, engine and coupling runner |
| Codeunit | 80001 | DVI Feature Mgt. | Enabled flag, experience change |
| Codeunit | 80002 | DVI App Area Subscriber | Sets the application area from Enabled |
| Codeunit | 80003 | DVI Sync Context | Mapping, job, direction, follow-ups passed to every step |
| Codeunit | 80004 | DVI Runner Events | Subscriber proxy on the three `OnBeforeRun` events |
| Codeunit | 80005 | DVI Runner Dispatch | Default dispatch: guard, switched check, takeover |
| Codeunit | 80006 | DVI Table Synch. | Default engine: both directions of a mapping |
| Codeunit | 80007 | DVI Record Synch. | Record pipeline |
| Codeunit | 80008 | DVI Field Transfer | Field mapping transfer without `OnTransferFieldData` |
| Codeunit | 80009 | DVI Synch. Job Log | Jobs, counters, errors in the standard log tables |
| Codeunit | 80010 | DVI Generic Handler | Default implementation of the handler interfaces |
| Codeunit | 80011 | DVI Mapping Conflict Policy | Conflicts by the mapping's resolution settings |
| Codeunit | 80012 | DVI Dataverse Connection | Connection and guard for Dataverse |
| Codeunit | 80013 | DVI Mapping Logic | Assignment validation |
| Codeunit | 80014 | DVI Option Synch. | Option mapping runner |
| Codeunit | 80015 | DVI Coupling Runner | Coupling and uncoupling jobs |
| Codeunit | 80016 | DVI Coupling Action | Couples or uncouples one pair |
| Codeunit | 80017 | DVI Default Assignment | Switch to redesigned or standard; default handler by enum iteration |
| Codeunit | 80018 | DVI Sales Connection | Guard for Dynamics 365 Sales |
| Codeunit | 80019 | DVI Field Service Connection | Guard for Field Service |
| Codeunit | 80020 | DVI Mapping Resolver | Assignment of a mapping or its parent |
| Codeunit | 80021 | DVI Coupling Store | Couplings and timestamps through `Integration Record Management` |
| Codeunit | 80022 | DVI Config. Template Applier | Configuration templates for new records |
| Codeunit | 80023 | DVI Integration Record Reader | Candidate Dataverse records |
| Codeunit | 80024 | DVI Follow-up Processor | Runs queued follow-ups |
| Codeunit | 80025 | DVI Standard Option Source | Option values from Dataverse metadata |
| Codeunit | 80026 | DVI Option Record Synch. | One option value or option record |
| Codeunit | 80027 | DVI Option Coupling Store | Option couplings |
| Page | 80000 | DVI Setup | Setup card (application area All) |
| Page | 80001 | DVI Mapping Assignments | Assignments list |
| Page extension | 80000 | DVI Int. Table Mapping List | Handler and module columns, switch actions |
| Permission set | 80000 | DVI Full | All objects |

## Files

```
app/src/Core/
├── codeunits/      28 codeunits listed above
├── enums/          SyncHandler, IntegrationModule, SynchAction, DeletionOutcome
├── interfaces/     11 interfaces
├── pageextensions/ IntTableMappingList.PageExt.al
├── pages/          Setup.Page.al, MappingAssignments.Page.al
├── permissionsets/ Full.PermissionSet.al
├── tableextensions/ApplicationAreaSetup, IntegrationTableMapping, CRMIntegrationRecord
└── tables/         Setup, FollowUpBuffer, OptionValue, MappingAssignment
test/src/Core/codeunits/  TestLibrary, FakeTableSynch, 5 test codeunits
```

## Integration Points

| Point | Procedure / Event | Usage |
|---|---|---|
| CRM Integration Table Synch. (5340) | `OnBeforeRun(IntegrationTableMapping, var IsHandled)` | Takeover of synchronization and option synchronization |
| CDS Int. Table Couple (5360) | `OnBeforeRun(IntegrationTableMapping, var Handled)` | Takeover of match-based coupling |
| CDS Int. Table Uncouple (5337) | `OnBeforeRun(IntegrationTableMapping, var Handled)` | Takeover of uncoupling |
| Application Area Mgmt. Facade | `OnGetEssentialExperienceAppAreas` | Application area from Enabled |
| CRM Integration Management | `OnInitCDSConnection`, `OnTestCDSConnection`, `OnCloseCDSConnection`, `OnGetCDSIntegrationUserId` (raised, as the standard runner does) | Connection |
| Integration Record Management | `UpdateIntegrationTableCoupling`, `UpdateIntegrationTableTimestamp`, `IsModifiedAfter…`, `MarkLastSynchAsFailure`, `IsIntegrationRecordSkipped` | Couplings; no module subscribes to its events |
| CDS Transformation Rule Mgt. | `ApplyTransformations` | Field transformation rules |
| CDS Integration Mgt. | `GetOptionSetMetadata`, `InsertOptionSetMetadata`, `UpdateOptionSetMetadata` | Option values |
| CRM Integration Management | `CreateNewRecordsInCRM`, `EnqueueSyncJob` | Unmatched records and post-coupling synchronization; both come back through the takeover |

Extension points for dependent apps: an `enumextension` of **DVI Sync Handler** with its own implementations
(serving a table pair through `DVI IHandlerScope`), of **DVI Integration Module**, and the `Implement…` setters of
**DVI Service Locator**. No events are published.

## Dependencies

| Dependency | App | Usage |
|---|---|---|
| Base Application 29.0 | Microsoft | Integration engine tables and public procedures, CDS and CRM setup |
| Field Service Integration 29.0 | Microsoft | FS Connection Setup for the Field Service guard |

## Known Limitations

- **Do not switch production mappings yet.** This feature ships only the *Generic* handler: it transfers the field
  mappings but has none of the table-pair behaviour that Microsoft's CDS, CRM and Field Service subscribers add
  (company ID and owner on Dataverse records, primary contacts, sales document lines, Field Service consumption…).
  Those handlers come with FEAT-DVI-004 to 006.
- Field values are transferred directly; Microsoft's value conversions in `OnTransferFieldData` (owner, coupled
  primary keys, currency, unit groups) come back as value converters in FEAT-DVI-003.
- Microsoft's *Use Default Synchronization Setup* still re-creates the mapping definitions; the assignments survive
  it because they are kept by mapping name. The app-owned re-creation of the Field Service mappings is part of
  FEAT-DVI-006.
- Records of option mappings whose last synchronization to Dataverse failed are retried only when they change
  again.
- Multi-company synchronization follows after FEAT-DVI-004.
- Microsoft's non-engine subscribers (posting, deletes, setup) keep running; an extension cannot unbind them.
- Verified by compilation and unit tests only; the integration test plan is run manually against a Dataverse
  environment.

### Microsoft behaviour corrected while porting

- `Int. Option Synch. Invoke` decides whether a Business Central option record changed by looking at
  `CRM Integration Record`, which option couplings never use; the port compares with the option coupling's own
  *Last Synch. Modified On*.
- `CDS Int. Table Uncouple` deletes orphan couplings with `Get("Integration ID", "CRM ID")`, but the primary key is
  `("CRM ID", "Integration ID")`, so the orphan is never found; the port uses the key order.
- `CDS Int. Table Uncouple`, with no filters, uncouples every coupling of the Business Central table, also those of
  another mapping on the same table; the port uncouples only couplings of the mapping (or without a mapping name).
- Microsoft hard-codes per mapping name (`SALESPEOPLE`, `SALESORDER-ORDER`) whether match-based coupling creates
  unmatched records; the port asks the handler (`CreateNewOnNoMatch`).
