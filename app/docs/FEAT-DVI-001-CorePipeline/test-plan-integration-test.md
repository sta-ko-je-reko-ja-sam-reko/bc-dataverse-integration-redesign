# FEAT-DVI-001 - Core Pipeline — Integration Test Plan

Runs against a Business Central environment connected to a Dataverse test environment, with Dynamics 365 Sales
and Field Service connections where noted. Every case compares the redesigned synchronization with the standard one
on the same data. All cases are manual until the project has a Dataverse test environment for the pipeline.

## TEST-01 — Scheduled synchronization of a switched mapping
- **Given** the CURRENCY mapping switched to the redesigned synchronization, a currency changed in Business Central
- **When** its job queue entry runs
- **Then** the currency is updated in Dataverse, the job log shows one modified record, and the coupling carries
  the mapping name CURRENCY

**Automation:** manual

## TEST-02 — Synchronize now on a card goes through the takeover
- **Given** a switched mapping
- **When** Synchronize is used on a coupled record's card
- **Then** the temporary copy of the mapping is run by the redesigned engine (its job log entry and the coupling
  name prove it) and Microsoft's subscribers do not run for the record

**Automation:** manual

## TEST-03 — Update conflict follows the mapping setting
- **Given** a bidirectional switched mapping with *Update-Conflict Resolution* = Get data update from integration
  table, and the same bidirectional field changed on both sides
- **When** the mapping runs
- **Then** the Dataverse value wins and the Business Central change is skipped, as with the standard engine

**Automation:** manual

## TEST-04 — Deletion conflict follows the mapping setting
- **Given** a switched mapping with *Deletion-Conflict Resolution* = Restore records, and a coupled Dataverse record
  deleted
- **When** the Business Central record changes and the mapping runs
- **Then** the record is created again in Dataverse and coupled

**Automation:** manual

## TEST-05 — Option mapping
- **Given** the PAYMENT TERMS mapping (to Dataverse) switched, and a new payment terms code
- **When** the mapping runs
- **Then** a new option value exists on the account's payment terms in Dataverse and the option coupling is created

**Automation:** manual

## TEST-06 — Match-based coupling
- **Given** a switched mapping with a field mapping marked for match-based coupling and one matching uncoupled
  Dataverse record
- **When** Match-Based Coupling runs
- **Then** the records are coupled, the job log shows one coupled record

**Automation:** manual

## TEST-07 — Uncoupling only touches the mapping's couplings
- **Given** the Resource table coupled through two mappings
- **When** one mapping is uncoupled without filters
- **Then** only that mapping's couplings are removed

**Automation:** manual

## TEST-08 — Disabled feature
- **Given** switched mappings
- **When** Enabled is turned off and the mappings run
- **Then** they synchronize exactly as Microsoft ships it

**Automation:** manual
