# FEAT-DVI-005b - CRM Sales Documents — Integration Test Plan

Manual, on bc29loc connected to a Dynamics 365 Sales test environment, with the sales order, sales order line, posted
sales invoice and posted sales invoice line mappings switched. Each case is run once with the standard and once with
the redesigned synchronization, and the results compared.

## TEST-01 — New sales order to Dataverse (bidirectional)
- **Given** bidirectional sales order integration and a released sales order with two item lines and a line discount
- **When** the sales order mapping runs
- **Then** the Dataverse order exists with the price list, company ID, customer name and owner; both lines exist with
  unit and tax; the line discount total matches; the order is Submitted; the next run reports it unchanged

## TEST-02 — Deleted sales line
- **Given** a coupled order from TEST-01 and one of its lines deleted in Business Central
- **When** the sales order mapping runs
- **Then** the Dataverse line and its coupling are removed

## TEST-03 — New order from Dataverse (bidirectional)
- **Given** a submitted Dataverse order from a quote, with an order discount, freight and a note
- **When** the sales order mapping runs
- **Then** the sales order has the quote number (the quote is archived), its lines, the invoice discount and a freight
  line; it is released; the Dataverse order shows the Business Central order number; the note exists; the next run
  reports both unchanged

## TEST-04 — Write-in line
- **Given** a Dataverse order line without product and a write-in item in *Sales & Receivables Setup*
- **When** the order is synchronized to Business Central
- **Then** the sales line uses the write-in item; sending it back keeps the Dataverse line without product

## TEST-05 — Orders only to Dataverse
- **Given** one-way sales order integration and a coupled order that is partly invoiced, then fully invoiced
- **When** the sales order mapping runs after each step
- **Then** the Dataverse order is Submitted, then Invoiced

## TEST-06 — Posted invoice of a Dataverse order
- **Given** a sales order from a Dataverse order, shipped and invoiced
- **When** the posted sales invoice mapping runs
- **Then** the Dataverse invoice refers to the order, its opportunity and price list, has the order's customer and
  owner; its lines exist; totals, discount and payment status are set

## TEST-07 — Posted invoice with prices including VAT
- **Given** a posted invoice with prices including VAT whose line amounts do not divide evenly
- **When** the posted sales invoice mapping runs
- **Then** a *Rounding* line makes the Dataverse total equal the posted total, and is not added twice

## TEST-08 — Invoice with an uncoupled product or customer
- **Given** a posted invoice for a customer and an item that are not coupled
- **When** the posted sales invoice mapping runs
- **Then** the invoice fails with an error naming the record, the record is synchronized as a prerequisite, and the next
  run creates the invoice

## TEST-09 — Invoice lines alone
- **Given** the posted sales invoice line mapping run on its own
- **When** it finds lines of invoices that are not coupled
- **Then** they are skipped without errors and are sent with their invoice

## TEST-10 — Pages
- **Given** the redesigned integration enabled
- **When** the sales order, sales order list, posted sales invoice and posted sales invoices pages open
- **Then** each shows the redesigned *Dataverse* group and hides Microsoft's actions; *Go to Dataverse sales order list*
  (one-way mode) stays

**Automation:** manual for all cases.
