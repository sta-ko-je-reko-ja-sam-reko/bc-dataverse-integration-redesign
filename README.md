# Dataverse Integration Redesign for Business Central

Business Central ships three integrations with Dataverse:

| Module | Where it lives | Setup table |
|---|---|---|
| Common Data Service (CDS, Dataverse) | Base Application, `CDS *` objects | `CDS Connection Setup` |
| Dynamics 365 Sales (CRM) | Base Application, `CRM *` objects | `CRM Connection Setup` |
| Dynamics 365 Field Service | Field Service Integration app | `FS Connection Setup` |

All three run on the same synchronization engine (`Integration Table Synch.`, `Integration Rec. Synch. Invoke`)
and the same mapping tables (`Integration Table Mapping`, `Integration Field Mapping`). Each module adds its
own behaviour through **event subscribers** on that engine: one large subscriber codeunit per module, each
branching on table numbers and carrying the module's business logic inline. Some steps of those flows have no
publisher at all, so a partner cannot extend them.

This repository redesigns that layer with the **polymorphic pattern**:

- Every step of the sync flow is a method on an **interface**.
- The implementation is resolved **per integration table mapping** (an extensible enum), so a dependent app adds
  or replaces the handling of one table pair without touching anyone else's.
- Event subscribers are thin proxies that forward one line to the resolved implementation. No business logic
  sits in a subscriber or a table trigger.
- No new event publishers. A dependent app extends by implementing an interface, not by subscribing.

Microsoft's entities are kept as they are: the setup tables, `Integration Table Mapping`,
`Integration Field Mapping`, `CRM Integration Record` and the Dataverse proxy tables.

## Status

Project scaffold. The architecture document and the first redesigned flows follow; see `app/docs/`.

## Target

- Business Central **29.0** (runtime 18.0), W1
- Depends on Microsoft **Field Service Integration** 29.0 (CDS and CRM are part of the Base Application)
- Affix `DVI`, object IDs 80000..83999, tests 84000..84999

## Repository layout

```
app/    the extension (src/, docs/, img/, Translations/)
test/   the test app
tools/  build.ps1 - compiles app and test with all four code analyzers
```

## License

MIT, see [LICENSE](LICENSE).
