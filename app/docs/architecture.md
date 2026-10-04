# Architecture

How this app redesigns Business Central's Dataverse integration layer, and why. The evidence for every statement
about Microsoft's code is in [`analysis/`](analysis/), with file:line citations against the BC 29.0.54011.55616
sources.

## 1. What Microsoft ships today

Three modules share one synchronization engine:

| Module | Code | Subscriber codeunit | Subscribers on the engine |
|---|---|---|---|
| CDS (Dataverse) | Base Application | 7205 `CDS Int. Table. Subscriber` | 28 (12 row/field-level, 16 service/config) |
| Dynamics 365 Sales (CRM) | Base Application | 5341 `CRM Int. Table. Subscriber`, plus 5330 `CRM Integration Management` | 23 + 11 |
| Dynamics 365 Field Service | Field Service Integration app | 6610 `FS Int. Table Subscriber`, plus 6611 `FS Setup Defaults` | 33 + 4 |

The engine (`Integration Table Synch.`, `Integration Rec. Synch. Invoke`, `Integration Record Synch.`) raises
events at each step of a record synch: transfer fields, transfer one field value, before/after insert, before/after
modify, unchanged, conflicts, find uncoupled destination, couple, uncouple. Each module subscribes to those events and
does its work inline.

### 1.1 What is wrong with it

1. **Dispatch by table-name strings, not by mapping.** Every module builds
   `'<SourceTable.Name()>-<DestinationTable.Name()>'` and switches on literals such as
   `'Sales Header-CRM Salesorder'`. The `Integration Table Mapping` the engine passes in is ignored, and the two most
   used events (`OnBefore/AfterTransferRecordFields`) do not even pass it. A second mapping between the same two
   tables (a custom mapping, a multi-company mapping) silently runs the same hard-coded logic.
2. **All modules see all records.** Each subscriber fires for every synch of every module. Guards are inconsistent:
   most CRM record-level subscribers check no enablement flag at all; the CDS option subscribers check the CRM flag;
   Field Service checks only `FS Connection Setup.IsEnabled()`.
3. **Field values are resolved by "first subscriber wins".** `OnTransferFieldData` has CDS, CRM and Field Service
   subscribers with duplicated but different logic (OwnerId, coupled primary keys, currencies, unit groups). Which one
   sets `IsValueFound` first depends on subscriber order, which the platform does not guarantee. CDS and CRM coordinate
   only through a hard-coded exclusion list.
4. **Almost nothing is extensible.** Across ~9,000 lines of subscriber code there are about a dozen
   integration events, mostly `IsHandled` switches that replace a whole branch. Invoice totals and VAT rounding, price
   levels, discounts, freight lines, unit-group creation, auto-reserve, CompanyId stamping, owner assignment, Field
   Service consumption posting, the service-order cascade, status mapping: none of it has an extension point.
5. **Side effects inside engine events.** Subscribers `Commit()` mid-transaction, call `Sleep(5000)` retries, post
   project journals, and re-enter the engine (`SynchRecordsToIntegrationTable` from inside an engine event).
6. **The UI has the same shape.** About 68 pages carry Dataverse actions (*Account*/*Contact*/… to open the
   coupled record, *Synchronize*, *Set Up Coupling*, *Delete Coupling*, *Synchronization Log*, *Create in
   Dataverse*, statistics). Their visibility depends only on whether CRM, CDS or Field Service is enabled, never on
   the mapping's direction; pages find their mapping by hard-coded names (`'CUSTOMER'`, `'ITEM-PRODUCT'`, …) and
   detect filters by raw strings (`'Field39=1(0)'`); every action calls one fixed procedure of
   `CRM Integration Management` with no `IsHandled` event. Mappings are picked by table ID and `FindFirst`, and the
   coupling table `CRM Integration Record` does not store which mapping a coupling belongs to, so Resource
   (`RESOURCE-PRODUCT` and `RESOURCE-BOOKABLERSC`) always resolves to the Field Service mapping, even from the
   Dynamics 365 Sales actions. Details in `analysis/ui-and-entry-points.md`.
7. **Defects the structure hides.** Examples found during the analysis (details in `analysis/subscribers-fs.md`):
   an inverted `if FSConnectionSetup.IsEnabled() then exit;` that makes two Field Service filters run only when
   Field Service is *disabled*; branches that read local records which were never loaded; an empty `SetFilter` that
   re-synchronizes every booking; a reset that raises the event of a different mapping; on the Field Service
   *Service Item Card* and list, `CRMIsCoupledToRecord` is never assigned, so *Delete Coupling* is always disabled;
   the uncoupling job deletes orphan couplings with the primary key fields in the wrong order, so it never finds
   them; option synchronization checks for changes against a coupling table that option mappings do not use.

## 2. Design goals

- **Per-mapping behaviour.** What happens to a record depends on the `Integration Table Mapping` it is synchronized
  through, chosen explicitly, never inferred from table names.
- **Every step replaceable.** Each step of the pipeline is an interface method. A partner replaces or wraps one step
  for one mapping without touching anything else.
- **No new publishers.** Extension is by implementing interfaces (extensible enum values), not by subscribing. The only
  events this app subscribes to are Microsoft's, and each subscriber body is a one-line delegation.
- **Reuse Microsoft's entities.** `CDS Connection Setup`, `CRM Connection Setup`, `FS Connection Setup`,
  `Integration Table Mapping`, `Integration Field Mapping`, `CRM Integration Record`, `Integration Synch. Job`,
  `Integration Synch. Job Errors` and the Dataverse proxy tables stay as they are. This app adds fields through table
  extensions only.
- **Opt-in and reversible per mapping.** A mapping not switched to this app behaves exactly as Microsoft ships it.
- **Testable without Dataverse.** Every step works on records passed as `var` parameters, so tests run on temporary
  records with fake implementations injected.

**Scope: every entry point, not only the runners.** The runners (§3) are the entry point of scheduled
synchronization and must be covered, but the redesign covers every place in the CDS, CRM and Field Service objects
where behaviour is hard-wired: the page actions (§4.6), the *CRM Redirect* page, the coupling dialog and lookups,
the create flows, statistics, full synchronization and the setup-page actions.

## 3. How the app takes over a mapping

The job queue never calls the engine directly. It runs the codeunit a mapping names, and all three of those runners
raise an `OnBeforeRun(IntegrationTableMapping, var Handled)` event before doing anything:

| Mapping field | Microsoft runner | Publisher |
|---|---|---|
| `Synch. Codeunit ID` | 5340 `CRM Integration Table Synch.` | `OnBeforeRun(IntegrationTableMapping, var IsHandled)` |
| `Coupling Codeunit ID` | 5360 `CDS Int. Table Couple` | `OnBeforeRun(IntegrationTableMapping, var Handled)` |
| `Uncouple Codeunit ID` | 5337 `CDS Int. Table Uncouple` | `OnBeforeRun(IntegrationTableMapping, var Handled)` |

This app subscribes to those three events. When the mapping is switched to this app, the subscriber runs this app's
pipeline and sets `Handled`; otherwise it returns and Microsoft's code runs.

Why not replace `Synch. Codeunit ID` on the mapping instead: Microsoft's own lookups
(`CRM Integration Management.GetIntegrationTableMapping` and three private variants) filter mappings on
`Synch. Codeunit ID = CRM Integration Table Synch.`. A mapping pointing at another codeunit disappears from
*Synchronize now*, *Couple* and the other card-page actions. Leaving the mapping record untouched keeps all of them
working.

**This app's pipeline raises none of Microsoft's engine events.** That is the point: on a switched mapping, the CDS,
CRM and Field Service subscribers never see the record, and the behaviour they implemented comes from this app's
implementation of each step instead. Microsoft's subscribers to *non-engine* events (posting, table deletes, setup
defaults, Copy Company) are not affected; they remain Microsoft's.

```
Job Queue ─► Integration Synch. Job Runner ─► Codeunit.Run(mapping."Synch. Codeunit ID" = 5340)
                                                 │
                                                 ▼ OnBeforeRun(mapping, Handled)
                                   DVI Synch. Runner Events  (proxy, one line)
                                                 │ mapping."DVI Handler" <> Microsoft?
                                    no ◄─────────┴─────────► yes
              Microsoft engine + CDS/CRM/FS subscribers       DVI Table Synch. ─► DVI pipeline steps
                                                                                  resolved per mapping
```

## 4. The model

### 4.1 Per-mapping handler: an assignment kept by mapping name

Microsoft's *Use Default Synchronization Setup* deletes and re-creates mappings, so a field on the mapping record
would be lost on every reset. The choice therefore lives in this app's own table, keyed by mapping name; the mapping
record shows it through FlowFields:

```al
table 80003 "DVI Mapping Assignment"
{
    fields
    {
        field(1; "Mapping Name"; Code[20]) { }               // the integration table mapping
        field(2; Handler; Enum "DVI Sync Handler") { }       // Microsoft (default) = not switched
        field(3; Module; Enum "DVI Integration Module") { }  // Dataverse, Dynamics 365 Sales, Field Service
    }
}

enum 80000 "DVI Sync Handler" implements "DVI IRecordSync", "DVI IRecordCoupling", "DVI IRecordFilter",
    "DVI IConflictPolicy", "DVI IOptionSource", "DVI IHandlerScope"
{
    Extensible = true;
    value(0; DVIMicrosoft) { }   // not switched: Microsoft's engine runs
    value(1; DVIGeneric) { }     // field mappings only, no table-pair logic
    // one value per table pair that has behaviour of its own, added by the module features
}
```

- The handler is chosen **per mapping**, so two mappings on the same tables can behave differently. A temporary
  copy made by *Synchronize now* uses its parent's assignment.
- *Use Redesigned Synchronization* picks the default handler by iterating the enum's values and asking each
  `DVI IHandlerScope.Serves` whether it implements the mapping's table pair; *Generic* is the fallback. A partner's
  `enumextension` value takes part in that choice without any registration code.
- A partner's implementation may hold this app's implementation and call it first (decorator), so it extends rather
  than copies.
- `DVI Module` selects the connection guard (§4.4), replacing the inconsistent enablement checks.

### 4.2 The pipeline steps: segregated interfaces

Each interface is one concern, so a partner implements only what it changes.

| Interface | Methods (all receive the `DVI Sync Context`) | Replaces Microsoft's |
|---|---|---|
| `DVI IRecordSync` | `BeforeTransferFields`, `AfterTransferFields`, `BeforeInsert`, `AfterInsert`, `BeforeModify`, `AfterModify`, `Unchanged` | `OnBefore/AfterTransferRecordFields`, `OnBefore/AfterInsertRecord`, `OnBefore/AfterModifyRecord`, `OnAfterUnchangedRecordHandled` |
| `DVI IRecordCoupling` | `FindUncoupledDestination`, `AfterCouple`, `BeforeUncouple`, `AfterUncouple`, `SetMatchingFilter`, `CreateNewOnNoMatch` | `OnFindUncoupledDestinationRecord`, `OnAfterCoupleRecord`, `OnBefore/AfterUncoupleRecord`, `OnBeforeSetMatchingFilter`, and the mapping names hard-coded in `ShouldCreateNewRecordsInCaseOfNoMatch` |
| `DVI IRecordFilter` | `IgnoreRecord` | `OnQueryPostFilterIgnoreRecord` (which passes only the source record) |
| `DVI IConflictPolicy` | `ResolveUpdateConflict`, `ResolveDeletionConflict` | `OnUpdateConflictDetected`, `OnDeletionConflictDetected` and its variants |
| `DVI IValueConverter` | `Convert` | `OnTransferFieldData` (see §4.3) |
| `DVI IOptionSource` | `GetOptionSetField`, `LoadOptions` | `LoadCRMOption` / `OnPrepareNewDestination`, a `case` over three internal option tables |
| `DVI IHandlerScope` | `Serves`, `DefaultModule` | Nothing: Microsoft decides by table-name strings at run time |
| `DVI IConnection` | `IsEnabled`, `Open`, `Close` | `IsCRMIntegrationEnabled` / `IsCDSIntegrationEnabled` / `FS Connection Setup.IsEnabled` scattered per subscriber |

`DVI Sync Context` is a codeunit passed by `var` to every step. It carries what Microsoft's events leave out: the
mapping, the synch job ID, the direction, whether the destination is being inserted, and a **follow-up queue**.

### 4.3 Field values: a converter chosen per field mapping

`OnTransferFieldData` is replaced by an explicit choice per field mapping, stored in this app's table
`DVI Field Converter` (mapping name + both field numbers, so it survives Microsoft re-creating field mappings) and
shown on the field mapping list:

```al
enum 80004 "DVI Value Converter" implements "DVI IValueConverter"   // AppliesTo, Convert
{
    Extensible = true;
    value(0; DVIDirect) { }            value(10; DVIOwner) { }       value(20; DVIPrimaryContact) { }
    value(30; DVICurrency) { }         value(40; DVIUnitOfMeasure) { }
    value(50; DVIOptionValue) { }      value(60; DVICoupledRecordKey) { }
}
```

The value of a field is computed by exactly one converter. There is no ordering between modules and no "first
subscriber wins". When a mapping is switched, each field mapping gets the first converter whose `AppliesTo` accepts
the field pair (specific converters have lower ordinals than *Coupled record key*); a partner adds a converter as an
enum value and it takes part in that choice. Details in `FEAT-DVI-003-ValueConverters/`.

### 4.4 Rules the implementations follow

- **No `Commit()` inside a step.** The pipeline owns the transaction boundaries, one per record, as the engine does.
- **No re-entering the engine from a step.** A step that needs a dependent record synchronized (price list lines
  after a price list, invoice lines after an invoice, service lines after a work order) adds it to the context's
  follow-up queue; the pipeline processes the queue after the record's own transaction. A **prerequisite**
  (`AddPrerequisite`) is a follow-up that survives the failure of the record that queued it. A **completion step**
  (`AddCompletion`, `DVI IRecordCompletion`) runs for the record itself after all its follow-ups, for work that needs
  them done, such as a document's totals after its lines; the coupling is re-stamped afterwards, so these changes are
  not seen as edits in the next run.
- **Indirect changes.** A handler can add records that changed only through related records to the outbound run
  (`DVI IChangeDetection`), such as service orders whose lines changed.
- **No posting inside a step.** Field Service consumption that Microsoft posts from an engine event becomes a
  follow-up action, with its own implementation that a partner can replace.
- **Guards in one place.** The pipeline asks `DVI IConnection.IsEnabled` once per run; steps never check enablement.
- **Errors go to `Integration Synch. Job Errors`**, as Microsoft's engine records them, so the standard error pages
  keep working.

### 4.5 Subscribers and the service locator

The app's subscribers follow the pure-proxy rule: dedicated `SingleInstance` codeunits, one-line bodies delegating
to an implementation resolved through `DVI Service Locator`.

| Proxy codeunit | Subscribes to | Delegates to |
|---|---|---|
| `DVI Synch. Runner Events` | `OnBeforeRun` of 5340, 5360, 5337 | `DVI IRunnerDispatch`: switched mapping → this app's pipeline |
| `DVI Mapping Events` | `Integration Table Mapping` / `CRM Setup Defaults` reset events | Keep `DVI Handler` on reset of default mappings |

The service locator also holds the pipeline itself (`DVI ISyncPipeline`), so the whole engine can be replaced for
tests or by a dependent app (`Implement…` setter, and the `OnResolve…` publisher where no early call site exists).

### 4.6 The UI: one interface per concern, resolved per mapping

Every page that Microsoft gives Dataverse actions (cards, lists, documents, the Dataverse-side lists, the Field
Service pages) gets a page extension with this app's own action group. The behaviour behind it is not one `IView`
interface but several, because the concerns are independent: a partner who changes how the coupled record is opened
should not have to re-implement synchronization or coupling, and a mapping that cannot open a Dataverse record still
synchronizes.

| Interface | Actions it backs | Default availability |
|---|---|---|
| `DVI IIntegrationRecordView` | Open the coupled Dataverse record (*Account*, *Contact*, *Product*, *Work Order*, …) | Record coupled, and mapping direction **Bidirectional** or **To Integration Table** |
| `DVI ISynchronizeAction` | *Synchronize* for the current record or the selection | Mapping enabled; offers only the directions the mapping allows |
| `DVI ICouplingAction` | *Set Up Coupling*, *Delete Coupling*, *Match-Based Coupling* | Set up: always; delete: record coupled |
| `DVI ICreateAction` | *Create in Dataverse* (direction To/Bidirectional), *Create in Business Central* (From/Bidirectional) | By direction |
| `DVI ISynchLogView` | *Synchronization Log*, synch errors, skipped records | Always |
| `DVI IStatisticsAction` (FEAT-DVI-005) | *Update Account Statistics* and the statistics factbox | Customer ↔ Account in the Dynamics 365 Sales module |
| `DVI IRedirectTarget` | The *CRM Redirect* page: a link from Dataverse opens the coupled Business Central record | See below |
| `DVI ILocalRecordView` (FEAT-DVI-006) | The record a *CRM Redirect* link opens, per handler | The coupled record's card; work orders open the service order or its archive |
| `DVI IIntegrationLookup` (when a handler needs it) | Lookups to Dataverse records in the coupling dialog | Always; until then Microsoft's lookup applies |

- **Availability is part of each interface** (`IsAvailable(Context)`), computed from the mapping, its direction and
  the coupling, never from module flags alone. The defaults above are this app's implementation; a partner changes
  them per mapping by its own enum value.
- **The same enum value selects them.** `DVI Sync Handler` implements the UI interfaces as well, so one choice on
  the mapping decides both how a record synchronizes and what the user can do with it.
- **Pages stay thin.** A page extension calls one facade (`DVI Record Actions`) in `OnAfterGetCurrRecord`, binds
  `Visible`/`Enabled` of its actions to the result, and each `OnAction` is a one-line delegation. No mapping names, no
  filter strings, no `case` on table numbers in a page.
- **Visibility is decided per action, by its interface.** There is no group-level switch: on a
  `From Integration Table` mapping, `DVI IIntegrationRecordView` and the *Create in Dataverse* side of
  `DVI ICreateAction` report themselves unavailable and their actions disappear, while *Synchronize* (pull),
  *Coupling* and the log stay as long as their own interfaces say so. The group is hidden only when none of its
  actions is available.
- **One UI everywhere.** This app's action group replaces Microsoft's on every covered page, for switched and
  unswitched mappings alike; Microsoft's actions are hidden action by action with `modify(...) { Visible = false; }`.
  A page extension cannot change an existing trigger and none of Microsoft's actions has an `IsHandled` event, so
  hiding and replacing is the only way to take them over. On a mapping left on `Microsoft`, the `Microsoft` enum
  value's UI implementations call Microsoft's own procedures (`ShowCRMEntityFromRecordID`, `UpdateOneNow`,
  `DefineCoupling`, …), so the behaviour is Microsoft's while the visibility already follows the mapping.
- **CRM Redirect** keeps Microsoft's page (Dataverse links point to page 5329) and takes over
  `OnBeforeOpenCoupledNavRecordPage`, which is a full `IsHandled` takeover. `DVI IRedirectTarget` resolves the
  Dataverse entity to a mapping, the mapping to the coupled record and the record to its page. When the record is not
  coupled, it can offer to couple or create it: the case Microsoft left as a `TODO` in the page.
- **Where Microsoft does offer a full takeover event**, this app uses it rather than hiding the action:
  `OnBeforeOpenCoupledNavRecordPage`, `OnBeforeOpenRecordCardPage`, `OnLookupCRMTables`, `OnLookupCRMOption`,
  `Integration Table Mapping.OnSynchronizeNow` (setup pages and the mapping list), `OnOpenSourceRecord` /
  `OnOpenDestinationRecord` (error list). The full list is in `analysis/ui-and-entry-points.md` §D.

### 4.7 Entity improvement: couplings know their mapping

`CRM Integration Record` stores the Business Central record and the Dataverse ID, but not the mapping that created
the coupling. That is why a table with two mappings (Resource ↔ Product and Resource ↔ Bookable Resource) resolves
to whichever mapping `FindFirst` returns. This app adds the mapping name to the coupling:

```al
tableextension 80002 "DVI CRM Integration Record" extends "CRM Integration Record"
{
    fields
    {
        field(80000; "DVI Mapping Name"; Code[20]) { TableRelation = "Integration Table Mapping".Name; }
    }
}
```

The pipeline sets it when it couples a record; an upgrade step fills it for existing couplings where the table pair
has exactly one mapping. The UI and the redirect resolve the mapping from the coupling first, and ask the user only
when a record is not coupled and its table has several mappings.

## 5. Scope and limits

- **Synchronization: switched mappings only.** On a mapping left on `Microsoft`, records synchronize exactly as
  Microsoft ships it. **UI: every covered page**, with Microsoft's behaviour behind the actions of unswitched
  mappings (§4.6).
- **Microsoft's non-engine subscribers stay active.** Posting, deletion and setup subscribers in the CDS, CRM and
  Field Service code still run; an extension cannot unbind another app's static subscribers. Where one of them
  interferes with a switched mapping, this app documents it and, when possible, makes it a no-op through an
  existing `IsHandled` event.
- **Direct calls into 5340 bypass `OnRun`.** Microsoft code that calls `CRM Integration Table Synch.` procedures
  such as `SynchRecordsToIntegrationTable` directly (only from within Microsoft's own subscribers, per the analysis)
  is not intercepted. On a switched mapping those subscribers do not run, so these calls should not happen; FEAT-DVI-001
  verifies this for *Synchronize now*, *Couple* and *Create in Dataverse* on the card pages.
- **Upgrade risk is confined to three publishers.** The app depends on the three `OnBeforeRun` events and on the
  shape of Microsoft's tables, not on the internals of the engine.

## 6. Delivery plan

Each feature is a `FEAT-DVI-<n>` folder under `app/docs/` and ships as its own pull request.

| Feature | Content | Object IDs |
|---|---|---|
| FEAT-DVI-001 Core pipeline | Takeover proxies, `DVI Sync Handler` and `DVI Integration Module` enums, interfaces, `DVI Sync Context`, the pipeline (find/couple, direction, transfer through field mappings, insert/modify, conflicts, job log), generic handler, **option mappings** (Payment Terms, Shipment Method, Shipping Agent), `DVI Mapping Name` on couplings, switch action on *Integration Table Mappings*, this app's own *Use Default Synchronization Setup* that resets mappings to this app's handlers | 80000–80199 |
| FEAT-DVI-002 UI framework | The UI interfaces, `DVI Record Actions` facade, record-to-mapping resolution by coupling, *CRM Redirect* takeover (couple or create when not coupled), pilot on Customer Card and Customer List | 80000–80199, 80200–80201 |
| FEAT-DVI-003 Value converters | Owner, primary contact, currency, unit of measure, option value, coupled record key (with clear-on-failure), stored per field mapping and assigned on switch; replaces `OnTransferFieldData` | 80000–80199 |
| FEAT-DVI-004 CDS | Handlers for Customer/Vendor ↔ Account, Contact ↔ Contact, Currency ↔ Transaction Currency, Salesperson ↔ User; page extensions for their cards and lists (Product → Item moves to FEAT-DVI-005 with the item handler) | 80200–80399 |
| FEAT-DVI-005a CRM products and prices | Handlers for products, unit groups and units, price lists and prices, opportunities, the option sets of sales documents; prerequisites on `DVI Sync Context`; `DVI IStatisticsAction`; page extensions for items, resources, price groups, price lists and opportunities | 80400–80799 |
| FEAT-DVI-005b CRM sales documents | Handlers for sales orders and invoices (totals, VAT rounding, lines as follow-ups); page extensions for documents and the Dataverse-side lists | 80400–80799 |
| FEAT-DVI-006 Field Service | Handlers for bookable resources, customer assets, warehouses, work order types, project tasks, project journal lines (posting as a completion step), service orders with incidents and lines; `DVI FS Value Converter`; `DVI IChangeDetection`, `DVI ILocalRecordView`; this app's Field Service reset; page extensions for the resource, service item, location, service order type, project task and service order pages | 80800–81199 |
| FEAT-DVI-007 Microsoft defects | Each defect in `analysis/` gets a test, or a case of an integration test plan, proving the redesigned implementation does not have it (`DVI Microsoft Defect Tests`, 84022) | per module |

## 7. Decisions

Taken by the owner on 2026-10-04:

1. **Action visibility** is decided per action by its interface's availability, not by hiding the whole group (§4.6).
2. **One UI everywhere**: this app's action group replaces Microsoft's on every covered page, also for mappings left
   on `Microsoft`, whose actions then call Microsoft's procedures (§4.6).
3. **Option mappings** (`Int. Option Synch. Invoke`, reached through the same `OnBeforeRun`) are part of FEAT-DVI-001.
4. **Resetting mappings is owned by this app**: its *Use Default Synchronization Setup* re-creates the default
   mappings with this app's handlers, including the Field Service ones; it does not rely on `FS Setup Defaults`.
5. **Multi-company synch** (`Multi Company Synch. Enabled`) follows after FEAT-DVI-004 (CDS).
