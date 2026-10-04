# FEAT-DVI-007 - Microsoft Defects — Unit Test Plan

Each test states the Microsoft defect in its `[GIVEN]` comment.

| Test | Automation |
|---|---|
| TEST-01 — Uncoupling leaves couplings of other mappings alone | `DVI Microsoft Defect Tests.UncouplingLeavesCouplingsOfOtherMappingsAlone` |
| TEST-02 — An orphan coupling is deleted by its primary key | `DVI Microsoft Defect Tests.OrphanCouplingIsDeletedByItsPrimaryKey` |
| TEST-03 — An option change is detected on the option coupling | `DVI Microsoft Defect Tests.OptionChangeIsDetectedOnTheOptionCoupling` |
| TEST-04 — A resource resolves to the mapping of the requested table | `DVI Microsoft Defect Tests.ResourceResolvesToTheMappingOfTheRequestedTable` |
| TEST-05 — A coupled service item can be uncoupled | `DVI Microsoft Defect Tests.CoupledServiceItemCanBeUncoupled` |
| TEST-06 — The related mapping prefers the switched mapping | `DVI Microsoft Defect Tests.RelatedMappingPrefersTheSwitchedMapping` |
| TEST-07 — Service lines without a service item line are rejected | `DVI Microsoft Defect Tests.ServiceLinesWithoutServiceItemLineAreRejected` |
| TEST-08 — An uncoupled sell-to customer is named in the error | `DVI Microsoft Defect Tests.UncoupledSellToCustomerIsNamedInTheError` |
| TEST-09 — Match-based coupling honours the mapping setting for salespeople | `DVI Microsoft Defect Tests.MatchBasedCouplingHonoursTheMappingSettingForSalespeople` |

Defects 7 and 11 are proven by tests of FEAT-DVI-006 and FEAT-DVI-005b (see the technical documentation).

**Status:** compiled; run with `tools\test.ps1` against bc29loc.
