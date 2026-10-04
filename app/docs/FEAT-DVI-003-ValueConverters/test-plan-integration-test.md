# FEAT-DVI-003 - Value Converters — Integration Test Plan

Manual, on bc29loc connected to a Dataverse test environment, with the redesigned integration enabled and the
CUSTOMER, CONTACT, SALESPEOPLE and CURRENCY mappings switched.

## TEST-01 — Salesperson to owner, person ownership
- **Given** person ownership and a customer whose salesperson is coupled to a Dataverse user
- **When** the customer synchronizes to Dataverse
- **Then** the account is owned by that user

## TEST-02 — Primary contact both ways
- **Given** a customer whose primary contact is coupled
- **When** the customer synchronizes to Dataverse and back
- **Then** the account's primary contact is the coupled contact, and the customer keeps its primary contact

## TEST-03 — Local currency with a different base currency
- **Given** a Dataverse base currency different from the local currency
- **When** a customer in local currency synchronizes to Dataverse
- **Then** the account's currency is the transaction currency for the local currency code

## TEST-04 — Changing a converter by hand
- **Given** a field mapping switched to Direct on *Integration Field Converters*
- **When** the mapping synchronizes
- **Then** the value is copied without conversion

**Automation:** manual for all cases.
