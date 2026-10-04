# FEAT-DVI-005a - CRM Products, Units, Prices and Statistics

## Use the redesigned synchronization for products, prices and opportunities

1. Open **Integration Table Mappings**.
2. Select the mappings for items, resources, unit groups, units of measure, price lists, prices and opportunities, and
   choose **Use Redesigned Synchronization**.
3. The **Synchronization Handler** column shows the handler that takes care of each one, for example
   *Item/Resource - Product*.

Synchronization then works as you know it: items and resources become active products with your local currency and
units, blocked products block their items, price lists carry their prices, and opportunities get the right owner.

## When something has to go first

A unit needs its unit group in Dataverse, and a price needs its product. If one is missing, the record that needs it
fails with an error that says what is missing, and the missing record is synchronized in the same run. Run the
synchronization again and the record goes through.

## Payment terms, shipment methods and shipping agents

When you use Dynamics 365 Sales, new or renamed payment terms, shipment methods and shipping agents also appear on
Dataverse sales orders, quotes and invoices.

## The Dataverse actions

The **Item**, **Resource**, **Customer Price Groups**, **Sales Price List(s)** and **Opportunity** pages have the same
**Dataverse** group as customers. Only the actions that apply to the record are shown.

On the customer card and list, **Update Account Statistics** sends the customer's figures to Dataverse. It is shown
for customers that are coupled to an account when Dynamics 365 Sales is enabled.
