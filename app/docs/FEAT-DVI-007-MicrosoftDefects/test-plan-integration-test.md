# FEAT-DVI-007 - Microsoft Defects — Integration Test Plan

The defects that need a Dataverse environment are covered by cases of the feature test plans:

| Defect | Case |
|---|---|
| 12 — every booking re-synchronized when all are skipped | FEAT-DVI-006 TEST-07: run the service order mapping twice; the second run reports every booking unchanged and does not touch bookings of other work orders |
| 13 — consumption write-back left buffered | FEAT-DVI-006 TEST-04: the work order product shows the consumed quantity right after the synchronization |
| 14 — company ID written before a failed insert | FEAT-DVI-006 TEST-02: make the resource insert fail (for example a missing hour unit of measure); the bookable resource keeps no company ID |
| 16 — location field mapping missing after a reset | FEAT-DVI-006 TEST-01 |

**Automation:** manual.
