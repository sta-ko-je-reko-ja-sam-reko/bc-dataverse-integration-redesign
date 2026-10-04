# FEAT-DVI-002 - UI Framework — Unit Test Plan

## TEST-01 — Open is offered only for coupled records sent to Dataverse
- **Given** a coupled record on a From Integration Table mapping, then on a bidirectional mapping
- **When** availability is computed
- **Then** opening the Dataverse record is hidden for the first and shown for the second

**Automation:** `DVI Record Actions Tests.OpenIsOfferedOnlyForCoupledRecordsSentToDataverse`

## TEST-02 — An uncoupled record cannot be opened but can be created in Dataverse
**Automation:** `DVI Record Actions Tests.UncoupledRecordIsNotOpenedInDataverse`

## TEST-03 — Create actions follow the mapping direction
**Automation:** `DVI Record Actions Tests.CreateActionsFollowTheMappingDirection`

## TEST-04 — A record without a mapping offers nothing
**Automation:** `DVI Record Actions Tests.RecordWithoutMappingOffersNothing`

## TEST-05 — The coupling's mapping wins over the table's mappings
- **Given** two mappings on Customer and a customer coupled through the second
- **When** its actions are resolved
- **Then** the second mapping, the coupling and the Dataverse ID are used

**Automation:** `DVI Record Actions Tests.CouplingMappingWinsOverTableMappings`

## TEST-06 — Disabled feature shows only standard actions
**Automation:** `DVI Record Actions Tests.DisabledFeatureShowsOnlyStandardActions`

## TEST-07 — Enabled feature replaces standard actions, also for unswitched mappings
**Automation:** `DVI Record Actions Tests.EnabledFeatureReplacesStandardActions`

## TEST-08 — Disabled feature leaves the redirect to Microsoft
**Automation:** `DVI Redirect Tests.DisabledFeatureLeavesRedirectToMicrosoft`

## TEST-09 — Links of unswitched mappings stay with Microsoft
**Automation:** `DVI Redirect Tests.UnswitchedMappingLeavesRedirectToMicrosoft`

## TEST-10 — A link handled by another app is left alone
**Automation:** `DVI Redirect Tests.LinkHandledByAnotherAppIsLeftAlone`

**Status:** compiled; run with `tools\test.ps1` against bc29loc.
