# FEAT-DVI-005a - CRM Products, Units, Prices and Statistics — Integration Test Plan

Manual, on bc29loc connected to a Dynamics 365 Sales test environment, with the ITEM-PRODUCT, RESOURCE-PRODUCT,
unit group, unit, price list, price list line, OPPORTUNITY and option mappings switched. Each case is run once with
the standard and once with the redesigned synchronization, and the results compared.

## TEST-01 — New item to Dataverse (unit groups off)
- **Given** a new item with a base unit of measure and a unit price
- **When** the ITEM-PRODUCT mapping runs
- **Then** the product is active, has the local currency, the item's unit, a price list item on the default price
  list and the company ID

## TEST-02 — New item to Dataverse (unit groups on)
- **Given** unit group mapping enabled and a new item with two units of measure
- **When** the unit group, item and unit mappings run in that order
- **Then** the product points at the item's unit group; both units exist in that schedule; price list items exist per
  unit

## TEST-03 — Unit before its unit group
- **Given** unit group mapping enabled and an item whose unit group is not synchronized
- **When** only the unit mapping runs
- **Then** the unit fails with the "not synchronized" error, the unit group is synchronized as a prerequisite in the
  same job, and the next run of the unit mapping succeeds

## TEST-04 — New product from Dataverse
- **Given** a new product in Dataverse and an item template with a number series
- **When** the ITEM-PRODUCT mapping runs
- **Then** the item gets the next number of the series; its unit group and base unit are coupled to the product's

## TEST-05 — Retired product
- **Given** a coupled product set to retired in Dataverse
- **When** the ITEM-PRODUCT mapping runs
- **Then** the item is blocked

## TEST-06 — Price list with prices
- **Given** a sales price list in one currency with lines for coupled items
- **When** the price list mapping runs
- **Then** the Dataverse price list exists, is active, and its price list items follow in the same job; a second run
  couples existing price list items instead of duplicating them

## TEST-07 — Price list with an uncoupled product
- **Given** a price list line for an item that is not coupled and is inside the item mapping's filter
- **When** the price list mapping runs
- **Then** the price list fails with an error naming the item, the item is synchronized as a prerequisite, and the next
  run succeeds

## TEST-08 — Opportunity with team ownership
- **Given** team ownership, an opportunity for a person contact of a customer's company, and one for a company contact
- **When** the OPPORTUNITY mapping runs
- **Then** the first is created with the company ID and the owning team; the second is not synchronized

## TEST-09 — Payment terms label on sales documents
- **Given** Dynamics 365 Sales enabled and a new payment term
- **When** the PAYMENT TERMS mapping runs
- **Then** the option exists on the account and with the same value and label on sales orders, quotes and invoices

## TEST-10 — Account statistics
- **Given** a coupled customer with posted invoices
- **When** *Update Account Statistics* is chosen on the customer card
- **Then** the account statistics in Dataverse show the customer's balance and the paid invoices are marked paid

## TEST-11 — Pages
- **Given** the redesigned integration enabled
- **When** the item, resource, customer price group, price list and opportunity pages open
- **Then** each shows the redesigned *Dataverse* group and hides Microsoft's actions; *Product* is hidden on a mapping
  with direction **From Integration Table**

**Automation:** manual for all cases.
