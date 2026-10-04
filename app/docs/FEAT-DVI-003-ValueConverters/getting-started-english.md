# FEAT-DVI-003 - Value Converters

Some fields cannot be copied as they are between Business Central and Dataverse: a salesperson becomes the owner of
a record, a contact number becomes a reference to the coupled contact, a payment terms code becomes an option. The
redesigned integration converts these values field by field.

## See how a field is converted

1. Open **Integration Table Mappings**, select a mapping and open its **Fields**.
2. The **Value Converter** column shows how each field's value is converted. *Direct* means the value is copied as it is.

When you switch a mapping to the redesigned synchronization, every field gets the right converter automatically.

## Change a converter

1. Open **Redesigned Integration Mappings**, select the mapping and choose **Field Converters**.
2. Change **Value Converter** on the field you want to treat differently.

The choice is kept even when the standard setup re-creates the mappings.
