# FEAT-DVI-006 - Field Service

## Set up Field Service with the redesigned synchronization

1. Open the Field Service connection setup page (*FS Connection Setup*).
2. Choose **Use Default Synchronization Setup**. The Field Service mappings are created for your integration type
   (projects, or service and projects) and use the redesigned synchronization.

Existing mappings can also be switched on **Integration Table Mappings** with **Use Redesigned Synchronization**.

## What changes for you

- Resources, service items, locations, service order types and project tasks synchronize as before; crews and pools,
  and tasks of projects that are not open, are left out.
- Used work order products and services become project journal lines and are posted by your posting rule; the
  consumed quantities appear in Field Service right away.
- Work orders become service orders with their incidents, products, services and completed bookings in the same run.
  A change to a service line is enough for the service order to be sent to Field Service.
- A link from a work order whose service order was archived opens the archive.

## When something has to go first

A project task needs its customers in Dataverse. If one is missing, the task fails with an error that says which, and
the customer is synchronized in the same run. Run the synchronization again and the task goes through.

## The Field Service actions

Resource, service item, location, service order type, project task and service order pages have a **Field Service**
group with the same actions as the **Dataverse** group. On resources you see both: **Dataverse** for the product and
**Field Service** for the bookable resource.
