# FEAT-DVI-002 - UI Framework

> **Source/legacy reference:** N/A (greenfield).
> **Affected objects:** Customer Card and Customer List (pilot page extensions); CRM Integration Management `OnBeforeOpenCoupledNavRecordPage` (subscribed); new UI interfaces, facade and redirect listed below.
> **Namespaces:** `DataverseIntegration.Core` (framework), `DataverseIntegration.CDS` (pilot pages); tests `DataverseIntegration.Test`.

## Business Process

1. A page that shows a Business Central record with a Dataverse mapping refreshes the record's actions in
   `OnAfterGetCurrRecord` through one facade, **DVI Record Actions**.
2. The facade resolves the record's mapping (**DVI Record Mapping Resolver**):
   1. the mapping stamped on the record's coupling (`DVI Mapping Name`), when it is coupled;
   2. otherwise the only Dataverse mapping of the table that the standard runner runs;
   3. with several, the first switched mapping whose connection is enabled;
   4. otherwise the first one.
3. It takes the mapping's handler (Microsoft or a redesigned one) and asks each UI interface whether its action is
   available. Visibility is decided per action, never for the whole group:

   | Action | Interface | Default availability |
   |---|---|---|
   | Open the coupled Dataverse record | `DVI IIntegrationRecordView` | Coupled, and the mapping sends to Dataverse (To Integration Table or Bidirectional) |
   | Synchronize | `DVI ISynchronizeAction` | The table has a mapping; only the directions the mapping allows are offered |
   | Set Up Coupling / Match-Based Coupling | `DVI ICouplingAction` | The table has a mapping |
   | Delete Coupling | `DVI ICouplingAction` | The record is coupled |
   | Create in Dataverse | `DVI ICreateAction` | Not coupled, and the mapping sends to Dataverse |
   | Create in Business Central | `DVI ICreateAction` | The mapping gets data from Dataverse |
   | Synchronization Log | `DVI ISynchLogView` | The table has a mapping |

   The group is shown when at least one action is available.
4. While the redesigned integration is enabled, the page hides Microsoft's actions one by one and shows this app's
   group, for switched and unswitched mappings alike (one UI everywhere). The default implementation
   (**DVI Standard Record Actions**) calls Microsoft's mapping-aware procedures, so on an unswitched mapping the
   behaviour is Microsoft's while visibility already follows the mapping; on a switched mapping the jobs these
   procedures queue come back through the runner takeover of FEAT-DVI-001.
5. A link from Dataverse opens page 5329 *CRM Redirect*, which calls `OpenCoupledNavRecordPage`. **DVI UI Events**
   takes it over through `OnBeforeOpenCoupledNavRecordPage` and **DVI Redirect** resolves it: the switched mapping
   whose Dataverse table has the link's entity name, the coupled record, its page. When the Dataverse record is not
   coupled, the user can create it in Business Central (when the mapping gets data from Dataverse) or couple it to an
   existing record picked from the table's lookup page, the case Microsoft's redirect leaves as a `TODO`. Links of
   unswitched mappings stay with Microsoft's redirect.

## Data Model

No new tables or fields.

## Objects

| Type | ID | Name | Purpose |
|---|---|---|---|
| Interface | – | DVI IIntegrationRecordView | Open the coupled Dataverse record |
| Interface | – | DVI ISynchronizeAction | Synchronize now |
| Interface | – | DVI ICouplingAction | Set up, delete and match-based coupling |
| Interface | – | DVI ICreateAction | Create in Dataverse / in Business Central |
| Interface | – | DVI ISynchLogView | Synchronization log |
| Interface | – | DVI IRedirectTarget | Dataverse links into Business Central |
| Codeunit | 80030 | DVI Record Action Context | Record, mapping and coupling passed to the UI interfaces |
| Codeunit | 80031 | DVI Record Mapping Resolver | Record → mapping and coupling |
| Codeunit | 80032 | DVI Standard Record Actions | Default implementation of the five action interfaces |
| Codeunit | 80033 | DVI Record Actions | Facade for page extensions |
| Codeunit | 80034 | DVI UI Events | Subscriber proxy for the redirect |
| Codeunit | 80035 | DVI Redirect | Default redirect target |
| Codeunit | 80036 | DVI Record Lookup | Picks a record of any table through its lookup page |
| Page extension | 80200 | DVI Customer Card | Pilot: redesigned Dataverse group |
| Page extension | 80201 | DVI Customer List | Pilot: redesigned Dataverse group with selection actions |

`DVI Sync Handler` implements the five action interfaces (default: DVI Standard Record Actions);
`DVI Service Locator` gains `RedirectTarget()` / `ImplementRedirectTarget()`; `DVI Table Synch.` gains
`SynchronizeIntegrationRecord` for the redirect's *create in Business Central*.

## Files

```
app/src/Core/interfaces/   IIntegrationRecordView, ISynchronizeAction, ICouplingAction, ICreateAction, ISynchLogView, IRedirectTarget
app/src/Core/codeunits/    RecordActionContext, RecordMappingResolver, StandardRecordActions, RecordActions, UIEvents, Redirect, RecordLookup
app/src/CDS/pageextensions/ CustomerCard.PageExt.al, CustomerList.PageExt.al
test/src/Core/codeunits/   RecordActionsTests, RedirectTests
```

## Integration Points

| Point | Procedure / Event | Usage |
|---|---|---|
| CRM Integration Management | `OnBeforeOpenCoupledNavRecordPage(CRMID, CRMEntityTypeName, var Result, var IsHandled)` | Redirect takeover |
| CRM Integration Management | `GetCRMEntityUrlFromCRMID(TableId, CRMTableId, CRMId)`, `EnqueueSyncJob(Mapping, SystemIds, CRMIds, Direction, true)`, `DefineCoupling`, `MatchBasedCoupling`, `CreateNewRecordsInCRM` | Standard action behaviour, mapping-aware where Microsoft offers it |
| CRM Coupling Management | `RemoveCoupling(var RecordRef)` | Delete coupling |
| Integration Table Mapping | `ShowLog(JobIDFilter)` | Log of the resolved mapping |
| Page Management | `PageRun(RecordId)` | Redirect target page |
| Customer Card / Customer List | `modify(<action>) { Visible = not DVIActive; }` | Hide Microsoft's actions while enabled |

How a page adopts the framework (each further page follows the pilot): add the group with one action per
interface, bind `Visible` to booleans filled from the facade in `OnAfterGetCurrRecord`, hide Microsoft's actions with
`modify`, and delegate each `OnAction` in one line.

## Dependencies

| Dependency | App | Usage |
|---|---|---|
| FEAT-DVI-001 | this app | Assignments, resolver, coupling store, takeover |

## Known Limitations

- Only Customer Card and Customer List adopt the framework here, as the pilot. The other pages from
  `analysis/ui-and-entry-points.md` §A are adopted by the module features that own their table pairs
  (FEAT-DVI-004 CDS, FEAT-DVI-005 CRM, FEAT-DVI-006 Field Service).
- *Update Account Statistics* stays Microsoft's until FEAT-DVI-005 adds its interface.
- *Set Up Coupling*, *Match-Based Coupling*, *Delete Coupling* and *Create in Dataverse* still call Microsoft's
  procedures, which resolve the mapping by table; on a table with several mappings they may pick another mapping
  than the one the page shows. Mapping-aware replacements come with the module features that need them.
- The coupling dialog lookups (`OnLookupCRMTables`), setup-page *Synchronize Now* (`OnSynchronizeNow`) and the
  error-list navigation keep Microsoft's behaviour: they already route through the takeover or need no change.
- Picking a record through a `RecordRef` passed to `Page.RunModal` compiles; it is verified on the container as part
  of the integration test plan.
- Verified by compilation and unit tests only.
