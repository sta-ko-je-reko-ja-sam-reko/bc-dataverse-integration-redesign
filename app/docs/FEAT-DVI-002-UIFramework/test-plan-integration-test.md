# FEAT-DVI-002 - UI Framework — Integration Test Plan

Manual, on bc29loc connected to a Dataverse test environment, with the redesigned integration enabled.

## TEST-01 — Customer Card shows one Dataverse group
- **Given** the CUSTOMER mapping (bidirectional) and a coupled customer
- **When** the Customer Card opens
- **Then** only the redesigned *Dataverse* group is shown, with Account, Synchronize, Coupling and Synchronization
  Log; Microsoft's actions of the same names are hidden

**Automation:** manual

## TEST-02 — Direction hides Account
- **Given** the CUSTOMER mapping set to From Integration Table
- **When** the Customer Card opens for a coupled customer
- **Then** *Account* and *Create Account in Dataverse* are hidden; Synchronize, Coupling and the log stay

**Automation:** manual

## TEST-03 — Synchronize a selection
- **Given** three coupled customers selected on the Customer List
- **When** Synchronize is chosen (and a direction on a bidirectional mapping)
- **Then** one job synchronizes the three, through the takeover when the mapping is switched

**Automation:** manual

## TEST-04 — Redirect to a coupled customer
- **Given** a switched CUSTOMER mapping and a coupled account
- **When** the Business Central link on the account in Dataverse is opened
- **Then** the Customer Card of the coupled customer opens

**Automation:** manual

## TEST-05 — Redirect for an uncoupled account
- **Given** a switched CUSTOMER mapping and an uncoupled account
- **When** its Business Central link is opened
- **Then** the user can create the customer, or pick an existing customer to couple; the chosen customer opens

**Automation:** manual

## TEST-06 — Disabled feature
- **Given** the redesigned integration turned off
- **When** the Customer Card opens
- **Then** Microsoft's actions are shown and the redesigned group is not

**Automation:** manual
