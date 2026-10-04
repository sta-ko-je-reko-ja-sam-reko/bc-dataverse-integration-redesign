# FEAT-DVI-004 - CDS — Unit Test Plan

## TEST-01 — Switching picks the handler of each CDS table pair
- **Given** mappings Customer ↔ Account, Vendor ↔ Account, Contact ↔ Contact, Currency ↔ Transaction Currency, Salesperson ↔ User
- **When** each is switched to the redesigned synchronization
- **Then** each gets its CDS handler and the Dataverse module

**Automation:** `DVI CDS Handler Tests.SwitchingPicksTheHandlerOfEachCDSTablePair`

## TEST-02 — An inactive account blocks its customer
**Automation:** `DVI CDS Handler Tests.InactiveAccountBlocksItsCustomer`

## TEST-03 — An active account leaves its customer alone
**Automation:** `DVI CDS Handler Tests.ActiveAccountLeavesItsCustomerAlone`

## TEST-04 — A transaction currency without a symbol gets its ISO code
**Automation:** `DVI CDS Handler Tests.TransactionCurrencyWithoutSymbolGetsItsCode`

## TEST-05 — A salesperson created from a user gets the next code
**Automation:** `DVI CDS Handler Tests.NewSalespersonFromUserGetsTheNextCode`

## TEST-06 — A contact without customer or vendor is not sent to Dataverse
**Automation:** `DVI CDS Handler Tests.ContactWithoutCustomerOrVendorIsNotSentToDataverse`

**Status:** compiled; run with `tools\test.ps1` against bc29loc.
