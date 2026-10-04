# FEAT-DVI-006 - Field Service — Unit Test Plan

## TEST-01 — Switching picks the handler of each Field Service pair
- **Given** mappings for resources, service items, locations, service order types, project tasks, journal lines (product
  and service), service orders, service item lines and service lines (product and booking)
- **When** each is switched
- **Then** each gets its handler and the Field Service module

**Automation:** `DVI Field Service Tests.SwitchingPicksTheHandlerOfEachFieldServicePair`

## TEST-02 — The resource type follows the resource
**Automation:** `DVI Field Service Tests.ResourceTypeFollowsTheResource`

## TEST-03 — Crews and pools are not synchronized
**Automation:** `DVI Field Service Tests.CrewsAndPoolsAreNotSynchronized`

## TEST-04 — Only tasks of open projects with usage link go to Field Service
**Automation:** `DVI Field Service Tests.OnlyTasksOfOpenProjectsWithUsageLinkGoToFieldService`

## TEST-05 — Durations are converted between minutes and hours
**Automation:** `DVI Field Service Tests.DurationsAreConvertedBetweenMinutesAndHours`

## TEST-06 — The work order status maps to the service order status
**Automation:** `DVI Field Service Tests.WorkOrderStatusMapsToServiceOrderStatus`

## TEST-07 — The status field gets the Field Service converter
**Automation:** `DVI Field Service Tests.WorkOrderStatusFieldGetsTheFieldServiceConverter`

## TEST-08 — Service lines ship the larger of quantity and quantity to bill
**Automation:** `DVI Field Service Tests.ServiceOrderQuantitiesUseTheLargerOfQuantityAndQuantityToBill`

## TEST-09 — Default directions of the Field Service mappings
**Automation:** `DVI Field Service Tests.ProjectJournalLinesAreFromFieldServiceAndOthersBidirectional`

## TEST-10 — Service orders with changed lines are found
**Automation:** `DVI Field Service Tests.ServiceOrdersWithChangedLinesAreFound`

**Status:** compiled; run with `tools\test.ps1` against bc29loc.
