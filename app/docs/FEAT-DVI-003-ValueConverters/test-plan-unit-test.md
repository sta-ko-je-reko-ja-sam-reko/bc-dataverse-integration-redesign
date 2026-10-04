# FEAT-DVI-003 - Value Converters — Unit Test Plan

## TEST-01 — Switching assigns converters by field pair
- **Given** a customer mapping with name, primary contact, currency and owner field mappings, and a contact mapping
- **When** the mapping is switched
- **Then** Name gets Direct, Primary Contact No. gets Primary contact, Currency Code gets Currency, Salesperson Code
  gets Owner

**Automation:** `DVI Value Converter Tests.SwitchingAssignsConvertersByFieldPair`

## TEST-02 — Local key to coupled Dataverse ID
- **Given** a contact coupled to a Dataverse contact
- **When** a customer's primary contact is converted for Dataverse
- **Then** the value is the coupled Dataverse contact's ID

**Automation:** `DVI Value Converter Tests.CoupledKeyConvertsLocalKeyToCoupledDataverseId`

## TEST-03 — Dataverse ID to coupled local key
**Automation:** `DVI Value Converter Tests.CoupledKeyConvertsDataverseIdToCoupledLocalKey`

## TEST-04 — A blank key becomes an empty ID
**Automation:** `DVI Value Converter Tests.BlankKeyBecomesEmptyId`

## TEST-05 — Team ownership keeps the Dataverse owner
**Automation:** `DVI Value Converter Tests.TeamOwnershipKeepsTheDataverseOwner`

The field transfer tests of FEAT-DVI-001 (TEST-16 to 19) cover *Direct* through the new context parameter.

**Status:** compiled; run with `tools\test.ps1` against bc29loc.
