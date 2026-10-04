# FEAT-DVI-005a - CRM Products, Units, Prices and Statistics — Unit Test Plan

## TEST-01 — Switching picks the handler of each Sales table pair
- **Given** mappings Item ↔ Product, Resource ↔ Product, Unit Group ↔ Unit Group, Item Unit of Measure ↔ Unit,
  Customer Price Group ↔ Price List, Price List Header ↔ Price List, Price List Line ↔ Price List Item,
  Opportunity ↔ Opportunity
- **When** each is switched to the redesigned synchronization
- **Then** each gets its handler and the Sales module

**Automation:** `DVI CRM Handler Tests.SwitchingPicksTheHandlerOfEachSalesTablePair`

## TEST-02 — A payment terms option mapping gets the Sales option handler
**Automation:** `DVI CRM Handler Tests.PaymentTermsOptionMappingGetsTheSalesOptionHandler`

## TEST-03 — A payment terms mapping keyed by a GUID is not an option mapping
**Automation:** `DVI CRM Handler Tests.PaymentTermsTableMappingIsNotAnOptionMapping`

## TEST-04 — The write-in product is not sent to Dataverse
**Automation:** `DVI CRM Handler Tests.WriteInProductIsNotSentToDataverse`

## TEST-05 — A retired product blocks its item
**Automation:** `DVI CRM Handler Tests.RetiredProductBlocksItsItem`

## TEST-06 — An active product leaves its resource alone
**Automation:** `DVI CRM Handler Tests.ActiveProductLeavesItsResourceAlone`

## TEST-07 — Account statistics are offered only for coupled customers
**Automation:** `DVI CRM Handler Tests.AccountStatisticsAreOfferedOnlyForCoupledCustomers`

## TEST-08 — Statistics are not offered by default
**Automation:** `DVI CRM Handler Tests.StatisticsAreNotOfferedByDefault`

## TEST-09 — Prerequisites survive a failed record
- **Given** a follow-up and a prerequisite queued by one record
- **When** the record fails
- **Then** only the prerequisite is left

**Automation:** `DVI Sync Context Tests.PrerequisitesSurviveAFailedRecord`

**Status:** compiled; run with `tools\test.ps1` against bc29loc.
