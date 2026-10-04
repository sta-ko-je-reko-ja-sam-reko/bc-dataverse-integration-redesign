# FEAT-DVI-006 - Field Service — Integration Test Plan

Manual, on bc29loc connected to a Dynamics 365 Field Service test environment. Run *Use Default Synchronization Setup*
on *FS Connection Setup* first (once with integration type *Projects*, once with *Service and projects*). Each case is
run once with the standard and once with the redesigned synchronization, and the results compared.

## TEST-01 — Reset
- **When** *Use Default Synchronization Setup* runs
- **Then** the Field Service mappings of the integration type exist with field mappings, filters and job queue entries,
  each with its redesigned handler; with *Location Mandatory* the work order product mapping has the location field

## TEST-02 — Resource and bookable resource
- **Given** a person resource whose time sheet owner has an e-mail matching a Dataverse user
- **When** the resource mapping runs
- **Then** the bookable resource is of type User with that user and the company ID; a crew created in Field Service is
  not synchronized

## TEST-03 — Project task
- **Given** an open project with usage link, for a customer that is not coupled
- **When** the project task mapping runs
- **Then** the task fails, the customer is synchronized as a prerequisite, and the next run creates the task with
  billing and service account

## TEST-04 — Work order product to project journal
- **Given** a used work order product on a project task, post rule *Line used*
- **When** the journal line mapping runs
- **Then** the journal line is created and posted; the work order product shows the consumed quantity; the next run
  skips it

## TEST-05 — Work order service with booked resource
- **Given** a used work order service for a service item with a coupled booked resource
- **When** the journal line mapping runs
- **Then** a billable line and a budget line for the resource are created, coupled and posted together

## TEST-06 — Changed work order product after posting
- **Given** a posted work order product whose quantity is raised in Field Service
- **When** the journal line mapping runs
- **Then** a new journal line is created for the difference

## TEST-07 — Work order to service order
- **Given** a work order with an incident, a product, a service and a completed booking
- **When** the service order mapping runs
- **Then** the service order has a service item line, an item line, a service line and a resource line on the *FS
  Bookings* service item line, with quantities as in Field Service; the next run reports everything unchanged

## TEST-08 — Deleted work order product
- **Given** a coupled work order whose product is deleted in Field Service, with archiving of service orders on
- **When** the service order mapping runs
- **Then** the order is archived once and the service line is removed

## TEST-09 — Service line changed in Business Central
- **Given** a coupled service order whose service line quantity changes (header unchanged)
- **When** the service order mapping runs
- **Then** the order is found through its line and the work order product is updated

## TEST-10 — Link to an archived work order
- **Given** a work order whose service order was archived and deleted
- **When** the work order's link to Business Central is opened
- **Then** the service order archive opens

## TEST-11 — Pages
- **Given** the redesigned integration enabled
- **When** the resource, service item, location, service order type, project task and service order pages open
- **Then** each shows the *Field Service* group and hides the Field Service app's group; the resource pages also show the
  *Dataverse* group for the product

**Automation:** manual for all cases.
