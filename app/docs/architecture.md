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
6. **Defects the structure hides.** Examples found during the analysis (details in `analysis/subscribers-fs.md`):
   an inverted `if FSConnectionSetup.IsEnabled() then exit;` that makes two Field Service filters run only when
   Field Service is *disabled*; branches that read local records which were never loaded; an empty `SetFilter` that
   re-synchronizes every booking; a reset that raises the event of a different mapping.

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

### 4.1 Per-mapping handler: an extensible enum on `Integration Table Mapping`

```al
tableextension 80000 "DVI Integration Table Mapping" extends "Integration Table Mapping"
{
    fields
    {
        field(80000; "DVI Handler"; Enum "DVI Sync Handler")      // Microsoft (default) = not switched
        field(80001; "DVI Module"; Enum "DVI Integration Module")  // CDS, CRM, Field Service
    }
}

enum 80000 "DVI Sync Handler" implements "DVI IRecordSync", "DVI IRecordCoupling", "DVI IRecordFilter", "DVI IConflictPolicy"
{
    Extensible = true;
    DefaultImplementation = "DVI IRecordSync" = "DVI Generic Record Sync", ...;

    value(0; Microsoft) { }                    // not switched: Microsoft's engine runs
    value(1; Generic) { }                      // field mappings only, no table-pair logic
    value(10; "Customer - Account") { Implementation = "DVI IRecordSync" = "DVI Customer Account Sync", ...; }
    value(11; "Account - Customer") { ... }
    // ... one value per table pair and direction that has behaviour of its own
}
```

- The handler is chosen **per mapping**, so two mappings on the same tables can behave differently.
- A partner adds an `enumextension` value bound to its own implementations and selects it on the mapping. Its
  implementation may hold this app's implementation and call it first (decorator), so it extends rather than copies.
- `DVI Module` selects the connection guard (§4.4), replacing the inconsistent enablement checks.

### 4.2 The pipeline steps: segregated interfaces

Each interface is one concern, so a partner implements only what it changes.

| Interface | Methods (all receive the `DVI Sync Context`) | Replaces Microsoft's |
|---|---|---|
| `DVI IRecordSync` | `BeforeTransferFields`, `AfterTransferFields`, `BeforeInsert`, `AfterInsert`, `BeforeModify`, `AfterModify`, `Unchanged` | `OnBefore/AfterTransferRecordFields`, `OnBefore/AfterInsertRecord`, `OnBefore/AfterModifyRecord`, `OnAfterUnchangedRecordHandled` |
| `DVI IRecordCoupling` | `FindUncoupledDestination`, `AfterCouple`, `BeforeUncouple`, `AfterUncouple` | `OnFindUncoupledDestinationRecord`, `OnAfterCoupleRecord`, `OnBefore/AfterUncoupleRecord` |
| `DVI IRecordFilter` | `IgnoreRecord` | `OnQueryPostFilterIgnoreRecord` (which passes only the source record) |
| `DVI IConflictPolicy` | `ResolveUpdateConflict`, `ResolveDeletionConflict` | `OnUpdateConflictDetected`, `OnDeletionConflictDetected` and its variants |
| `DVI IValueConverter` | `Convert` | `OnTransferFieldData` (see §4.3) |
| `DVI IConnection` | `IsEnabled`, `Open`, `Close` | `IsCRMIntegrationEnabled` / `IsCDSIntegrationEnabled` / `FS Connection Setup.IsEnabled` scattered per subscriber |

`DVI Sync Context` is a codeunit passed by `var` to every step. It carries what Microsoft's events leave out: the
mapping, the synch job ID, the direction, whether the destination is being inserted, and a **follow-up queue**.

### 4.3 Field values: a converter chosen per field mapping

`OnTransferFieldData` is replaced by an explicit choice on each field mapping:

```al
tableextension 80001 "DVI Integration Field Mapping" extends "Integration Field Mapping"
{
    fields
    {
        field(80000; "DVI Value Converter"; Enum "DVI Value Converter")   // Direct (default), Owner Id,
    }                                                                      // Coupled Primary Key, Option Value,
}                                                                          // Currency Code, Unit Group, ...
```

The value of a field is computed by exactly one converter, the one set on its field mapping. There is no ordering
between modules and no "first subscriber wins". A partner adds a converter as an enum value.

### 4.4 Rules the implementations follow

- **No `Commit()` inside a step.** The pipeline owns the transaction boundaries, one per record, as the engine does.
- **No re-entering the engine from a step.** A step that needs a dependent record synchronized (price list lines
  after a price list, invoice lines after an invoice, service lines after a work order) adds it to the context's
  follow-up queue; the pipeline processes the queue after the record's own transaction.
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

## 5. Scope and limits

- **Switched mappings only.** On a mapping left on `Microsoft`, nothing changes.
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
| FEAT-DVI-001 Core pipeline | Takeover proxies, `DVI Sync Handler` and `DVI Integration Module` enums, interfaces, `DVI Sync Context`, the pipeline (find/couple, direction, transfer through field mappings, insert/modify, conflicts, job log), generic handler, switch action on *Integration Table Mappings* | 80000–80199 |
| FEAT-DVI-002 Value converters | Owner Id, coupled primary key, option values, currency, unit group, clear-on-failure; replaces `OnTransferFieldData` | 80000–80199 |
| FEAT-DVI-003 CDS handlers | Customer/Vendor ↔ Account, Contact ↔ Contact, Currency, Systemuser → Salesperson, Product → Item, option mappings | 80200–80399 |
| FEAT-DVI-004 CRM handlers | Sales orders and invoices (totals, VAT rounding, lines as follow-ups), price lists, products and units, opportunities, statistics | 80400–80799 |
| FEAT-DVI-005 Field Service handlers | Project tasks, work order products/services, customer assets, bookable resources, service orders; consumption posting as a follow-up | 80800–81199 |
| FEAT-DVI-006 Microsoft defects | Each defect in `analysis/` gets a test proving the redesigned handler does not have it | per module |

## 7. Decisions still open

1. **Field Service base app compatibility**: whether a switched Field Service mapping must also keep Microsoft's
   `FS Setup Defaults` reset behaviour, or this app owns resetting its handlers.
2. **Option mappings** (`Int. Option Synch. Invoke`) run through the same `OnBeforeRun`; whether FEAT-DVI-001 covers
   them or they follow in FEAT-DVI-002.
3. **Multi-company synch** (`Multi Company Synch. Enabled`) is in scope only after FEAT-DVI-003.
