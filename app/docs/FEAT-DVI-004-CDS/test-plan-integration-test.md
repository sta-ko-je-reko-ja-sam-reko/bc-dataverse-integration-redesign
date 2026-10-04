# FEAT-DVI-004 - CDS — Integration Test Plan

Manual, on bc29loc connected to a Dataverse test environment, with the CUSTOMER, VENDOR, CONTACT, CURRENCY and
SALESPEOPLE mappings switched. Each case is run once with the standard and once with the redesigned synchronization,
and the results compared.

## TEST-01 — New customer to Dataverse
- **Given** a new customer with a salesperson coupled to a Dataverse user (person ownership)
- **When** the CUSTOMER mapping runs
- **Then** the account exists with the company ID and the user as owner; the customer's contacts follow in the next
  CONTACT run

## TEST-02 — New account from Dataverse
- **Given** a new account in Dataverse and a customer template with a number series
- **When** the CUSTOMER mapping runs
- **Then** the customer gets the next number of the series, the account gets the company ID, coupled contacts of the
  account get their company

## TEST-03 — Inactive account
- **Given** a coupled account set to inactive in Dataverse
- **When** the CUSTOMER mapping runs
- **Then** the customer is blocked

## TEST-04 — Contact to Dataverse and primary contact
- **Given** a person contact of a coupled customer's company, and an account without primary contact
- **When** the CONTACT mapping runs
- **Then** the Dataverse contact has the account as parent and the account gets it as primary contact; the account is
  not reported as changed in the next run

## TEST-05 — Contact without business relation
- **Given** a contact whose company has no customer or vendor
- **When** the CONTACT mapping runs
- **Then** the contact is not synchronized

## TEST-06 — Currency
- **Given** a currency with an exchange rate and an existing transaction currency with the same ISO code
- **When** the CURRENCY mapping runs
- **Then** the two are coupled, not duplicated, and the exchange rate is updated

## TEST-07 — Uncoupling an account
- **Given** a coupled customer with coupled person contacts
- **When** the customer is uncoupled
- **Then** the account no longer carries the company ID and the contacts' couplings are removed

## TEST-08 — Pages
- **Given** the redesigned integration enabled
- **When** the vendor, contact, currency and salesperson cards and lists open
- **Then** each shows the redesigned *Dataverse* group and hides Microsoft's actions

**Automation:** manual for all cases.
