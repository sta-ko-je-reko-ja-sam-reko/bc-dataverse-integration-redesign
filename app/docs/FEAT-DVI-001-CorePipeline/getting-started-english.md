# FEAT-DVI-001 - Core Pipeline

## Turn on the redesigned integration

1. Search for **Dataverse Integration Redesign Setup** and open it.
2. Turn on **Enabled** and close the page.
3. The session restarts after a few seconds. Afterwards, the redesigned actions and columns are available.

While **Enabled** is off, every integration with Dataverse, Dynamics 365 Sales and Field Service works exactly as
before.

## Choose which mappings use it

1. Search for **Integration Table Mappings** and open the list.
2. Select one or more mappings and choose **Use Redesigned Synchronization**.
3. The **Synchronization Handler** column now shows the handler, and **Integration Module** the integration the
   mapping belongs to.
4. To go back, select the mappings and choose **Use Standard Synchronization**.

To switch every mapping at once, open **Redesigned Integration Mappings** and choose **Switch All Mappings**. On the
same page you can change the handler or module of a single mapping.

> Use the redesigned synchronization on a test environment for now. The handlers that carry the specific behaviour
> of customers, contacts, sales documents and Field Service work orders are added in the next releases.

## What stays the same

- Synchronization still runs from the same job queue entries, and **Synchronize** on a card still works.
- Results appear in the usual **Integration Synchronization Jobs** and **Integration Synchronization Errors** pages.
- If the standard setup re-creates the mappings, they keep using the redesigned synchronization.
