# FEAT-DVI-004 - CDS

## Use the redesigned synchronization for customers, vendors, contacts, currencies and salespeople

1. Open **Integration Table Mappings**.
2. Select the mappings for customers, vendors, contacts, currencies and salespeople, and choose
   **Use Redesigned Synchronization**.
3. The **Synchronization Handler** column shows the handler that takes care of each one, for example
   *Customer/Vendor - Account*.

Synchronization then works as you know it: new customers and vendors in Dataverse get numbers from your templates,
inactive accounts block their customers, contacts get their company and primary contact, and currencies get their
exchange rates.

## The Dataverse actions

The **Vendor**, **Contact**, **Currency** and **Salesperson/Purchaser** cards and lists have the same **Dataverse**
group as customers: open the coupled record, synchronize, set up or delete the coupling, create records and see the
synchronization log. Only the actions that apply to the record are shown.

## Owning team

When salespeople are created from Dataverse users, add those users to the owning team yourself: open
**Dataverse Connection Setup** and choose **Add Users to Team**.
