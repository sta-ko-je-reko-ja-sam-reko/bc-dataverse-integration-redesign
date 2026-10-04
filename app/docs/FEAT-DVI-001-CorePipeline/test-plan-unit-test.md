# FEAT-DVI-001 - Core Pipeline — Unit Test Plan

Isolated logic on in-memory or rolled-back records; no Dataverse connection. Given / When / Then.

## TEST-01 — Update conflict, get from Dataverse, Dataverse source
- **Given** a mapping resolving update conflicts by getting the Dataverse value
- **When** a Dataverse record conflicts with its coupled customer
- **Then** the conflict is resolved and the record is not skipped

**Automation:** `DVI Conflict Policy Tests.UpdateConflictGetFromIntegrationOverwritesFromDataverse`

## TEST-02 — Update conflict, get from Dataverse, Business Central source
- **Given** the same mapping
- **When** a customer conflicts with its coupled account
- **Then** the conflict is resolved by skipping the customer

**Automation:** `DVI Conflict Policy Tests.UpdateConflictGetFromIntegrationSkipsBusinessCentralSource`

## TEST-03 — Update conflict without a resolution
- **Given** a mapping without an update-conflict resolution
- **When** a conflict is detected
- **Then** it stays unresolved, so the record fails

**Automation:** `DVI Conflict Policy Tests.UpdateConflictWithoutResolutionIsNotResolved`

## TEST-04 — Deletion conflict follows the mapping
- **Given** each deletion-conflict resolution
- **When** a record is coupled to a deleted record
- **Then** restore, remove coupling or fail is returned accordingly

**Automation:** `DVI Conflict Policy Tests.DeletionConflictFollowsMappingSetting`

## TEST-05 — Follow-ups are queued, copied and cleared
- **Given** two follow-ups on the context
- **When** they are taken and the context is cleared
- **Then** the copy keeps both in order, and the context is empty

**Automation:** `DVI Sync Context Tests.FollowUpsAreQueuedCopiedAndCleared`

## TEST-06 — Context flags
- **Given** a job, a direction and an insert flag set on the context
- **When** a step reads them
- **Then** it gets the same values

**Automation:** `DVI Sync Context Tests.DirectionAndInsertFlagsAreKept`

## TEST-07 — Switching assigns the default handler and module
- **Given** a Dataverse mapping run by the standard runner
- **When** it is switched to the redesigned synchronization
- **Then** it gets the Generic handler and the Dataverse module

**Automation:** `DVI Mapping Switch Tests.SwitchingAssignsGenericHandlerAndDataverseModule`

## TEST-08 — Switching back keeps the assignment
- **Given** a switched mapping
- **When** it is switched back
- **Then** the assignment stays with the Microsoft handler

**Automation:** `DVI Mapping Switch Tests.SwitchingBackKeepsTheAssignmentWithMicrosoftHandler`

## TEST-09 — A mapping with a custom runner cannot be switched
- **Given** a Dataverse mapping running another synchronization codeunit
- **When** it is switched
- **Then** the switch is refused

**Automation:** `DVI Mapping Switch Tests.MappingWithCustomRunnerCannotBeSwitched`

## TEST-10 — A Synchronize now copy follows its parent
- **Given** a switched mapping and a temporary copy with it as parent
- **When** the copy is resolved
- **Then** it is switched, and its couplings carry the parent's name

**Automation:** `DVI Mapping Switch Tests.TemporaryMappingResolvesToItsParentAssignment`

## TEST-11 — An unassigned mapping stays standard
- **Given** a mapping without an assignment
- **When** it is resolved
- **Then** it is not switched and its handler is Microsoft

**Automation:** `DVI Mapping Switch Tests.MappingWithoutAssignmentIsNotSwitched`

## TEST-12 — A switched mapping is taken over
- **Given** the feature on, a switched mapping and a fake engine
- **When** the standard runner is about to run it
- **Then** the fake engine runs once and the run is handled

**Automation:** `DVI Runner Dispatch Tests.SwitchedMappingIsTakenOver`

## TEST-13 — An unswitched mapping is left to Microsoft
**Automation:** `DVI Runner Dispatch Tests.UnswitchedMappingIsLeftToMicrosoft`

## TEST-14 — A disabled feature takes nothing over
**Automation:** `DVI Runner Dispatch Tests.DisabledFeatureTakesNothingOver`

## TEST-15 — A run handled by another app is not taken over
**Automation:** `DVI Runner Dispatch Tests.RunHandledByAnotherAppIsNotTakenOver`

## TEST-16 — A new destination receives the mapped value
- **Given** Customer Name mapped to Account Name and a customer named Contoso
- **When** the fields are transferred to a new account
- **Then** the account is named Contoso and the transfer reports a change

**Automation:** `DVI Field Transfer Tests.NewDestinationReceivesMappedValue`

## TEST-17 — An equal value is not a change
**Automation:** `DVI Field Transfer Tests.UnchangedValueIsNotReportedAsModified`

## TEST-18 — A bidirectional change is reported for conflict detection
**Automation:** `DVI Field Transfer Tests.BidirectionalChangeIsReportedForConflictDetection`

## TEST-19 — A constant is written without a source field
**Automation:** `DVI Field Transfer Tests.ConstantValueIsWrittenWithoutSourceField`

**Status:** compiled; run with `tools\test.ps1` against bc29loc.
