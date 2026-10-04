# FEAT-DVI-005b - CRM Sales Documents — Unit Test Plan

## TEST-01 — Switching picks the handler of each sales document pair
- **Given** mappings Sales Header ↔ Order, Sales Line ↔ Order Product, Posted Sales Invoice ↔ Invoice,
  Posted Sales Invoice Line ↔ Invoice Product
- **When** each is switched to the redesigned synchronization
- **Then** each gets its handler and the Sales module

**Automation:** `DVI Sales Document Tests.SwitchingPicksTheHandlerOfEachSalesDocumentPair`

## TEST-02 — The line's product field gets the write-in converter
**Automation:** `DVI Sales Document Tests.LineProductFieldGetsTheWriteInConverter`

## TEST-03 — The write-in product is sent without product
**Automation:** `DVI Sales Document Tests.WriteInProductIsSentWithoutProduct`

## TEST-04 — A Dataverse line without product gets the write-in product
**Automation:** `DVI Sales Document Tests.DataverseLineWithoutProductGetsTheWriteInProduct`

## TEST-05 — An order is fully invoiced only when nothing is outstanding
**Automation:** `DVI Sales Document Tests.OrderIsFullyInvoicedOnlyWhenNothingIsOutstanding`

## TEST-06 — The rounding difference is what the Dataverse line misses
**Automation:** `DVI Sales Document Tests.RoundingDifferenceIsWhatTheDataverseLineMisses`

## TEST-07 — Lines of an uncoupled invoice wait for their invoice
**Automation:** `DVI Sales Document Tests.LinesOfAnUncoupledInvoiceWaitForTheirInvoice`

## TEST-08 — A completion is queued once per record, after the record's follow-ups
**Automation:** `DVI Sales Document Tests.CompletionIsQueuedOncePerRecord`

## TEST-09 — A completion is dropped when its record fails
**Automation:** `DVI Sales Document Tests.CompletionIsDroppedWhenItsRecordFails`

**Status:** compiled; run with `tools\test.ps1` against bc29loc.
