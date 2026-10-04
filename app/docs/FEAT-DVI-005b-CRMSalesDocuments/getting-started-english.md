# FEAT-DVI-005b - CRM Sales Documents

## Use the redesigned synchronization for sales orders and invoices

1. Open **Integration Table Mappings**.
2. Select the mappings for sales orders, sales order lines, posted sales invoices and posted sales invoice lines, and
   choose **Use Redesigned Synchronization**.
3. The **Synchronization Handler** column shows the handler that takes care of each one, for example
   *Sales Order - Order*.

Synchronization then works as you know it. An order or invoice is sent with its lines in the same run; totals,
discounts, the order state and the release of orders from Dataverse are set after the lines, and are not sent back as
changes in the next run.

## When something has to go first

An invoice needs its customer and its products in Dataverse. If one is missing, the invoice fails with an error that
says what is missing, and the missing record is synchronized in the same run. Run the synchronization again and the
invoice goes through.

## Write-in products

Lines without a product in Dataverse use the write-in item or resource that you choose in **Sales & Receivables
Setup**, and that item or resource is sent back as a line without product.

## The Dataverse actions

The **Sales Order** and **Posted Sales Invoice** pages and their lists have the same **Dataverse** group as customers.
Only the actions that apply to the record are shown.
