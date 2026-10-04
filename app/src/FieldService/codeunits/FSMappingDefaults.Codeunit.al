namespace DataverseIntegration.FieldService;

using DataverseIntegration.Core;
using Microsoft.Integration.D365Sales;
using Microsoft.Integration.Dataverse;
using Microsoft.Integration.DynamicsFieldService;
using Microsoft.Integration.SyncEngine;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Location;
using Microsoft.Inventory.Setup;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Journal;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Service.Document;
using Microsoft.Service.Item;
using Microsoft.Service.Setup;
using Microsoft.Utilities;
using System.Environment.Configuration;
using System.Threading;

codeunit 80834 "DVI FS Mapping Defaults"
{
    Access = Internal;

    var
        CRMProductName: Codeunit "CRM Product Name";
        LocationFieldMapping: Boolean;
        JobQueueEntryNameTok: Label ' %1 - %2 synchronization job.', Comment = '%1 = the integration table mapping name, %2 = the service name';
        IntegrationTablePrefixTok: Label 'Dynamics CRM', Comment = 'Product name', Locked = true;
        ItemProductMappingTok: Label 'ITEM-PRODUCT', Locked = true;

    /// <summary>
    /// Re-creates the default Field Service mappings of the integration type, with their field mappings, filters and job queue entries, and switches them to this app's handlers; replaces the Field Service app's reset.
    /// </summary>
    /// <param name="FSConnectionSetup">The Field Service connection setup.</param>
    internal procedure ResetConfiguration(var FSConnectionSetup: Record "FS Connection Setup")
    var
        CDSIntegrationMgt: Codeunit "CDS Integration Mgt.";
        FSServiceOrders: Codeunit "DVI FS Service Orders";
    begin
        CDSIntegrationMgt.RegisterConnection();
        CDSIntegrationMgt.ActivateConnection();
        LocationFieldMapping := IsLocationMandatory();
        if FSConnectionSetup."Integration Type" = FSConnectionSetup."Integration Type"::Projects then begin
            ResetProjectTaskMapping('PROJECTTASK', true);
            ResetProjectJournalLineWOProductMapping(FSConnectionSetup, 'PJLINE-WORDERPRODUCT', true);
            ResetProjectJournalLineWOServiceMapping(FSConnectionSetup, 'PJLINE-WORDERSERVICE', true);
        end;
        ResetServiceItemCustomerAssetMapping('SVCITEM-CUSTASSET', true);
        ResetResourceBookableResourceMapping(FSConnectionSetup, 'RESOURCE-BOOKABLERSC', true);
        ResetLocationMapping('LOCATION', true, false);
        AddProductTypeFieldMapping();
        if FSConnectionSetup."Integration Type" = FSConnectionSetup."Integration Type"::"Service and projects" then begin
            ResetServiceOrderTypeMapping(FSConnectionSetup, 'SRVORDERTYPE', true);
            ResetServiceOrderMapping(FSConnectionSetup, 'SRVORDER', true);
            ResetServiceOrderItemLineMapping(FSConnectionSetup, 'SRVORDERITEMLINE');
            ResetServiceOrderLineItemMapping(FSConnectionSetup, 'SRVORDERLINE-ITEM');
            ResetServiceOrderLineServiceItemMapping(FSConnectionSetup, 'SRVORDERLINE-SERVICE');
            ResetServiceOrderLineResourceMapping(FSConnectionSetup, 'SRVORDERLINE-RESOURC');
            FSServiceOrders.EnsureDefaultIncidentType();
            EnableServiceOrderArchive();
        end;
        SwitchFieldServiceMappings();
    end;

    local procedure ResetProjectTaskMapping(IntegrationTableMappingName: Code[20]; ShouldRecreateJobQueueEntry: Boolean)
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        IntegrationFieldMapping: Record "Integration Field Mapping";
        JobTask: Record "Job Task";
        FSProjectTask: Record "FS Project Task";
    begin
        JobTask.Reset();
        JobTask.SetRange("Job Task Type", JobTask."Job Task Type"::Posting);
        InsertIntegrationTableMapping(
          IntegrationTableMapping, IntegrationTableMappingName,
          Database::"Job Task", Database::"FS Project Task",
          FSProjectTask.FieldNo(ProjectTaskId), FSProjectTask.FieldNo(ModifiedOn),
          '', '', false);

        IntegrationTableMapping.SetTableFilter(
          GetTableFilterFromView(Database::"Job Task", JobTask.TableCaption(), JobTask.GetView()));
        if not ShouldResetServiceItemMapping() then
            IntegrationTableMapping."Dependency Filter" := 'CUSTOMER|RESOURCE-BOOKABLERSC'
        else
            IntegrationTableMapping."Dependency Filter" := 'CUSTOMER|RESOURCE-BOOKABLERSC|SVCITEM-CUSTASSET';
        IntegrationTableMapping.Modify();

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          JobTask.FieldNo("Job No."),
          FSProjectTask.FieldNo(ProjectNumber),
          IntegrationFieldMapping.Direction::ToIntegrationTable,
          '', true, false);

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          JobTask.FieldNo("Job Task No."),
          FSProjectTask.FieldNo(ProjectTaskNumber),
          IntegrationFieldMapping.Direction::ToIntegrationTable,
          '', true, false);

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          JobTask.FieldNo(Description),
          FSProjectTask.FieldNo(Description),
          IntegrationFieldMapping.Direction::ToIntegrationTable,
          '', true, false);

        RecreateJobQueueEntryFromIntTableMapping(IntegrationTableMapping, 1, ShouldRecreateJobQueueEntry, 5);
    end;

    local procedure ResetProjectJournalLineWOProductMapping(var FSConnectionSetup: Record "FS Connection Setup"; IntegrationTableMappingName: Code[20]; ShouldRecreateJobQueueEntry: Boolean)
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        IntegrationFieldMapping: Record "Integration Field Mapping";
        FSWorkOrderProduct: Record "FS Work Order Product";
        JobJournalLine: Record "Job Journal Line";
        CDSCompany: Record "CDS Company";
        CDSIntegrationMgt: Codeunit "CDS Integration Mgt.";
        EmptyGuid: Guid;
    begin
        FSWorkOrderProduct.Reset();
        FSWorkOrderProduct.SetRange(StateCode, FSWorkOrderProduct.StateCode::Active);
        FSWorkOrderProduct.SetFilter(ProjectTask, '<>' + Format(EmptyGuid));
        case FSConnectionSetup."Line Synch. Rule" of
            "FS Work Order Line Synch. Rule"::LineUsed:
                FSWorkOrderProduct.SetFilter(LineStatus, Format(FSWorkOrderProduct.LineStatus::Estimated) + '|' + Format(FSWorkOrderProduct.LineStatus::Used));
            "FS Work Order Line Synch. Rule"::WorkOrderCompleted:
                FSWorkOrderProduct.SetFilter(WorkOrderStatus, Format(FSWorkOrderProduct.WorkOrderStatus::Completed) + '|' + Format(FSWorkOrderProduct.WorkOrderStatus::Posted));
        end;
        FSWorkOrderProduct.SetFilter(ProjectTask, '<>' + Format(EmptyGuid));
        if CDSIntegrationMgt.GetCDSCompany(CDSCompany) then
            FSWorkOrderProduct.SetRange(CompanyId, CDSCompany.CompanyId);

        InsertIntegrationTableMapping(
          IntegrationTableMapping, IntegrationTableMappingName,
          Database::"Job Journal Line", Database::"FS Work Order Product",
          FSWorkOrderProduct.FieldNo(WorkOrderProductId), FSWorkOrderProduct.FieldNo(ModifiedOn),
          '', '', false);

        IntegrationTableMapping.SetIntegrationTableFilter(
          GetTableFilterFromView(Database::"FS Work Order Product", FSWorkOrderProduct.TableCaption(), FSWorkOrderProduct.GetView()));
        IntegrationTableMapping."Dependency Filter" := 'CUSTOMER|ITEM-PRODUCT';
        IntegrationTableMapping."Deletion-Conflict Resolution" := IntegrationTableMapping."Deletion-Conflict Resolution"::"Restore Records";
        IntegrationTableMapping.Modify();

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          JobJournalLine.FieldNo(Description),
          FSWorkOrderProduct.FieldNo(Name),
          IntegrationFieldMapping.Direction::FromIntegrationTable,
          '', true, false);

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          JobJournalLine.FieldNo("External Document No."),
          FSWorkOrderProduct.FieldNo(WorkOrderName),
          IntegrationFieldMapping.Direction::FromIntegrationTable,
          '', true, false);

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          JobJournalLine.FieldNo(Quantity),
          FSWorkOrderProduct.FieldNo(Quantity),
          IntegrationFieldMapping.Direction::FromIntegrationTable,
          '', true, false);

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          JobJournalLine.FieldNo("Qty. to Transfer to Invoice"),
          FSWorkOrderProduct.FieldNo(QtyToBill),
          IntegrationFieldMapping.Direction::FromIntegrationTable,
          '', true, false);

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          JobJournalLine.FieldNo("Currency Code"),
          FSWorkOrderProduct.FieldNo(TransactionCurrencyId),
          IntegrationFieldMapping.Direction::FromIntegrationTable,
          '', true, false);

        if LocationFieldMapping then
            InsertIntegrationFieldMapping(
              IntegrationTableMappingName,
              JobJournalLine.FieldNo("Location Code"),
              FSWorkOrderProduct.FieldNo(WarehouseId),
              IntegrationFieldMapping.Direction::FromIntegrationTable,
              '', true, false);

        RecreateJobQueueEntryFromIntTableMapping(IntegrationTableMapping, 1, ShouldRecreateJobQueueEntry, 5);
    end;

    local procedure ResetProjectJournalLineWOServiceMapping(var FSConnectionSetup: Record "FS Connection Setup"; IntegrationTableMappingName: Code[20]; ShouldRecreateJobQueueEntry: Boolean)
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        IntegrationFieldMapping: Record "Integration Field Mapping";
        FSWorkOrderService: Record "FS Work Order Service";
        JobJournalLine: Record "Job Journal Line";
        CDSCompany: Record "CDS Company";
        CDSIntegrationMgt: Codeunit "CDS Integration Mgt.";
        EmptyGuid: Guid;
    begin
        FSWorkOrderService.Reset();
        FSWorkOrderService.SetRange(StateCode, FSWorkOrderService.StateCode::Active);
        FSWorkOrderService.SetFilter(ProjectTask, '<>' + Format(EmptyGuid));
        case FSConnectionSetup."Line Synch. Rule" of
            "FS Work Order Line Synch. Rule"::LineUsed:
                FSWorkOrderService.SetFilter(LineStatus, Format(FSWorkOrderService.LineStatus::Estimated) + '|' + Format(FSWorkOrderService.LineStatus::Used));
            "FS Work Order Line Synch. Rule"::WorkOrderCompleted:
                FSWorkOrderService.SetFilter(WorkOrderStatus, Format(FSWorkOrderService.WorkOrderStatus::Completed) + '|' + Format(FSWorkOrderService.WorkOrderStatus::Posted));
        end;
        if CDSIntegrationMgt.GetCDSCompany(CDSCompany) then
            FSWorkOrderService.SetRange(CompanyId, CDSCompany.CompanyId);
        InsertIntegrationTableMapping(
          IntegrationTableMapping, IntegrationTableMappingName,
          Database::"Job Journal Line", Database::"FS Work Order Service",
          FSWorkOrderService.FieldNo(WorkOrderServiceId), FSWorkOrderService.FieldNo(ModifiedOn),
          '', '', false);

        IntegrationTableMapping.SetIntegrationTableFilter(
          GetTableFilterFromView(Database::"FS Work Order Service", FSWorkOrderService.TableCaption(), FSWorkOrderService.GetView()));

        IntegrationTableMapping."Dependency Filter" := 'CUSTOMER|ITEM-PRODUCT|RESOURCE-BOOKABLERSC';
        IntegrationTableMapping."Deletion-Conflict Resolution" := IntegrationTableMapping."Deletion-Conflict Resolution"::"Restore Records";
        IntegrationTableMapping.Modify();

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          JobJournalLine.FieldNo(Description),
          FSWorkOrderService.FieldNo(Name),
          IntegrationFieldMapping.Direction::FromIntegrationTable,
          '', true, false);

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          JobJournalLine.FieldNo("External Document No."),
          FSWorkOrderService.FieldNo(WorkOrderName),
          IntegrationFieldMapping.Direction::FromIntegrationTable,
          '', true, false);

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          JobJournalLine.FieldNo(Quantity),
          FSWorkOrderService.FieldNo(Duration),
          IntegrationFieldMapping.Direction::FromIntegrationTable,
          '', true, false);

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          JobJournalLine.FieldNo("Qty. to Transfer to Invoice"),
          FSWorkOrderService.FieldNo(DurationToBill),
          IntegrationFieldMapping.Direction::FromIntegrationTable,
          '', true, false);

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          JobJournalLine.FieldNo("Currency Code"),
          FSWorkOrderService.FieldNo(TransactionCurrencyId),
          IntegrationFieldMapping.Direction::FromIntegrationTable,
          '', true, false);

        RecreateJobQueueEntryFromIntTableMapping(IntegrationTableMapping, 1, ShouldRecreateJobQueueEntry, 5);
    end;

    local procedure ResetResourceBookableResourceMapping(var FSConnectionSetup: Record "FS Connection Setup"; IntegrationTableMappingName: Code[20]; ShouldRecreateJobQueueEntry: Boolean)
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        IntegrationFieldMapping: Record "Integration Field Mapping";
        FSBookableResource: Record "FS Bookable Resource";
        Resource: Record Resource;
        CDSCompany: Record "CDS Company";
        CDSIntegrationMgt: Codeunit "CDS Integration Mgt.";
        EmptyGuid: Guid;
    begin
        Resource.SetRange(Blocked, false);
        Resource.SetRange("Use Time Sheet", false);
        Resource.SetRange("Base Unit of Measure", FSConnectionSetup."Hour Unit of Measure");

        FSBookableResource.Reset();
        FSBookableResource.SetRange(StateCode, FSBookableResource.StateCode::Active);
        FSBookableResource.SetFilter(ResourceType, Format(FSBookableResource.ResourceType::Generic) + '|' + Format(FSBookableResource.ResourceType::Account)
           + '|' + Format(FSBookableResource.ResourceType::Equipment) + '|' + Format(FSBookableResource.ResourceType::User));
        if CDSIntegrationMgt.GetCDSCompany(CDSCompany) then
            FSBookableResource.SetFilter(CompanyId, CDSCompany.CompanyId + '|' + Format(EmptyGuid));
        InsertIntegrationTableMapping(
          IntegrationTableMapping, IntegrationTableMappingName,
          Database::Resource, Database::"FS Bookable Resource",
          FSBookableResource.FieldNo(BookableResourceId), FSBookableResource.FieldNo(ModifiedOn),
          '', '', true);

        IntegrationTableMapping.SetTableFilter(
          GetTableFilterFromView(Database::Resource, Resource.TableCaption(), Resource.GetView()));
        IntegrationTableMapping.SetIntegrationTableFilter(
          GetTableFilterFromView(Database::"FS Bookable Resource", FSBookableResource.TableCaption(), FSBookableResource.GetView()));
        IntegrationTableMapping."Dependency Filter" := 'CUSTOMER|ITEM-PRODUCT';
        IntegrationTableMapping.Modify();

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          Resource.FieldNo(Name),
          FSBookableResource.FieldNo(Name),
          IntegrationFieldMapping.Direction::Bidirectional,
          '', true, false);

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          Resource.FieldNo("Vendor No."),
          FSBookableResource.FieldNo(AccountId),
          IntegrationFieldMapping.Direction::Bidirectional,
          '', true, false);

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          Resource.FieldNo("Unit Cost"),
          FSBookableResource.FieldNo(HourlyRate),
          IntegrationFieldMapping.Direction::Bidirectional,
          '', true, false);

        RecreateJobQueueEntryFromIntTableMapping(IntegrationTableMapping, 30, ShouldRecreateJobQueueEntry, 1440);
    end;

    local procedure ResetServiceItemCustomerAssetMapping(IntegrationTableMappingName: Code[20]; ShouldRecreateJobQueueEntry: Boolean)
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        IntegrationFieldMapping: Record "Integration Field Mapping";
        FSCustomerAsset: Record "FS Customer Asset";
        ServiceItem: Record "Service Item";
        CDSCompany: Record "CDS Company";
        CDSIntegrationMgt: Codeunit "CDS Integration Mgt.";
        EmptyGuid: Guid;
    begin
        if not ShouldResetServiceItemMapping() then
            exit;

        FSCustomerAsset.Reset();
        FSCustomerAsset.SetRange(StateCode, FSCustomerAsset.StateCode::Active);
        if CDSIntegrationMgt.GetCDSCompany(CDSCompany) then
            FSCustomerAsset.SetFilter(CompanyId, CDSCompany.CompanyId + '|' + EmptyGuid);

        ServiceItem.Reset();
        ServiceItem.SetRange(Blocked, ServiceItem.Blocked::" ");
        ServiceItem.SetRange("Service Item Components", false);

        InsertIntegrationTableMapping(
          IntegrationTableMapping, IntegrationTableMappingName,
          Database::"Service Item", Database::"FS Customer Asset",
          FSCustomerAsset.FieldNo(CustomerAssetId), FSCustomerAsset.FieldNo(ModifiedOn),
          '', '', true);

        IntegrationTableMapping.SetIntegrationTableFilter(
          GetTableFilterFromView(Database::"FS Customer Asset", FSCustomerAsset.TableCaption(), FSCustomerAsset.GetView()));
        IntegrationTableMapping.SetTableFilter(
          GetTableFilterFromView(Database::"Service Item", ServiceItem.TableCaption(), ServiceItem.GetView()));
        IntegrationTableMapping."Dependency Filter" := 'CUSTOMER|ITEM-PRODUCT';
        IntegrationTableMapping.Modify();

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          ServiceItem.FieldNo(Description),
          FSCustomerAsset.FieldNo(Name),
          IntegrationFieldMapping.Direction::Bidirectional,
          '', true, false);

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          ServiceItem.FieldNo("Customer No."),
          FSCustomerAsset.FieldNo(Account),
          IntegrationFieldMapping.Direction::Bidirectional,
          '', true, false);

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          ServiceItem.FieldNo("Item No."),
          FSCustomerAsset.FieldNo(Product),
          IntegrationFieldMapping.Direction::Bidirectional,
          '', true, false);

        RecreateJobQueueEntryFromIntTableMapping(IntegrationTableMapping, 30, ShouldRecreateJobQueueEntry, 1440);
    end;

    local procedure ResetLocationMapping(IntegrationTableMappingName: Code[20]; ShouldRecreateJobQueueEntry: Boolean; SkipLocationMandatoryCheck: Boolean)
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        IntegrationFieldMapping: Record "Integration Field Mapping";
        InventorySetup: Record "Inventory Setup";
        Location: Record Location;
        FSWarehouse: Record "FS Warehouse";
        CDSCompany: Record "CDS Company";
        CDSIntegrationMgt: Codeunit "CDS Integration Mgt.";
    begin
        if not SkipLocationMandatoryCheck then
            if InventorySetup.Get() and (not InventorySetup."Location Mandatory") then
                exit;

        Location.SetRange("Use As In-Transit", false);
        Location.SetFilter("Job Consump. Whse. Handling", '''' + Format(Location."Job Consump. Whse. Handling"::"No Warehouse Handling") + '''|''' +
                                    Format(Location."Job Consump. Whse. Handling"::"Warehouse Pick (optional)") + '''|''' +
                                    Format(Location."Job Consump. Whse. Handling"::"Inventory Pick") + '''');
        Location.SetFilter("Asm. Consump. Whse. Handling", '''' + Format(Location."Asm. Consump. Whse. Handling"::"No Warehouse Handling") + '''|''' +
                                    Format(Location."Asm. Consump. Whse. Handling"::"Warehouse Pick (optional)") + '''|''' +
                                    Format(Location."Asm. Consump. Whse. Handling"::"Inventory Movement") + '''');

        if CDSIntegrationMgt.GetCDSCompany(CDSCompany) then
            FSWarehouse.SetRange(CompanyId, CDSCompany.CompanyId);

        InsertIntegrationTableMapping(
          IntegrationTableMapping, IntegrationTableMappingName,
          Database::Location, Database::"FS Warehouse",
          FSWarehouse.FieldNo(WarehouseId), FSWarehouse.FieldNo(ModifiedOn),
          '', '', false);

        IntegrationTableMapping.SetTableFilter(
          GetTableFilterFromView(Database::Location, Location.TableCaption(), Location.GetView()));
        IntegrationTableMapping.Modify();

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          Location.FieldNo(Code),
          FSWarehouse.FieldNo(Name),
          IntegrationFieldMapping.Direction::ToIntegrationTable,
          '', true, false);

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          Location.FieldNo(Name),
          FSWarehouse.FieldNo(Description),
          IntegrationFieldMapping.Direction::ToIntegrationTable,
          '', true, false);

        RecreateJobQueueEntryFromIntTableMapping(IntegrationTableMapping, 30, ShouldRecreateJobQueueEntry, 1440);
    end;

    local procedure ResetServiceOrderTypeMapping(var FSConnectionSetup: Record "FS Connection Setup"; IntegrationTableMappingName: Code[20]; ShouldRecreateJobQueueEntry: Boolean)
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        IntegrationFieldMapping: Record "Integration Field Mapping";
        ServiceOrderType: Record "Service Order Type";
        FSWorkOrderType: Record "FS Work Order Type";
        CDSCompany: Record "CDS Company";
        CDSIntegrationMgt: Codeunit "CDS Integration Mgt.";
    begin
        if not (FSConnectionSetup."Integration Type" = FSConnectionSetup."Integration Type"::"Service and projects") then
            exit;

        FSWorkOrderType.Reset();
        FSWorkOrderType.SetRange(StateCode, FSWorkOrderType.StateCode::Active);
        FSWorkOrderType.SetRange(IntegrateToService, true);
        if CDSIntegrationMgt.GetCDSCompany(CDSCompany) then
            FSWorkOrderType.SetRange(CompanyId, CDSCompany.CompanyId);

        InsertIntegrationTableMapping(
          IntegrationTableMapping, IntegrationTableMappingName,
          Database::"Service Order Type", Database::"FS Work Order Type",
          FSWorkOrderType.FieldNo(WorkOrderTypeId), FSWorkOrderType.FieldNo(ModifiedOn),
          '', '', false);

        IntegrationTableMapping.SetIntegrationTableFilter(
          GetTableFilterFromView(Database::"FS Work Order Type", FSWorkOrderType.TableCaption(), FSWorkOrderType.GetView()));
        IntegrationTableMapping.Modify();

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          ServiceOrderType.FieldNo(Code),
          FSWorkOrderType.FieldNo(Code),
          IntegrationFieldMapping.Direction::Bidirectional,
          '', true, false);

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          ServiceOrderType.FieldNo(Description),
          FSWorkOrderType.FieldNo(Name),
          IntegrationFieldMapping.Direction::Bidirectional,
          '', true, false);

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          0,
          FSWorkOrderType.FieldNo(IntegrateToService),
          IntegrationFieldMapping.Direction::Bidirectional,
          'true', true, false);

        RecreateJobQueueEntryFromIntTableMapping(IntegrationTableMapping, 30, ShouldRecreateJobQueueEntry, 1440);
    end;

    local procedure ResetServiceOrderMapping(var FSConnectionSetup: Record "FS Connection Setup"; IntegrationTableMappingName: Code[20]; ShouldRecreateJobQueueEntry: Boolean)
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        IntegrationFieldMapping: Record "Integration Field Mapping";
        ServiceOrder: Record "Service Header";
        FSWorkOrder: Record "FS Work Order";
        CDSCompany: Record "CDS Company";
        CDSIntegrationMgt: Codeunit "CDS Integration Mgt.";
        CRMSetupDefaults: Codeunit "CRM Setup Defaults";
        ArchivedServiceOrdersSynchJobDescTxt: Label 'Archived Service Orders - %1 synchronization job', Comment = '%1 = CRM product name';
    begin
        if not (FSConnectionSetup."Integration Type" = FSConnectionSetup."Integration Type"::"Service and projects") then
            exit;

        ServiceOrder.Reset();
        ServiceOrder.SetRange("Document Type", ServiceOrder."Document Type"::Order);

        FSWorkOrder.Reset();
        FSWorkOrder.SetRange(IntegrateToService, true);
        FSWorkOrder.SetFilter(SystemStatus, '%1|%2|%3|%4',
          FSWorkOrder.SystemStatus::Unscheduled,
          FSWorkOrder.SystemStatus::Scheduled,
          FSWorkOrder.SystemStatus::InProgress,
          FSWorkOrder.SystemStatus::Completed
        );
        if CDSIntegrationMgt.GetCDSCompany(CDSCompany) then
            FSWorkOrder.SetRange(CompanyId, CDSCompany.CompanyId);

        InsertIntegrationTableMapping(
          IntegrationTableMapping, IntegrationTableMappingName,
          Database::"Service Header", Database::"FS Work Order",
          FSWorkOrder.FieldNo(WorkOrderId), FSWorkOrder.FieldNo(ModifiedOn),
          '', '', false);

        IntegrationTableMapping.SetTableFilter(
          GetTableFilterFromView(Database::"Service Header", ServiceOrder.TableCaption(), ServiceOrder.GetView()));
        IntegrationTableMapping.SetIntegrationTableFilter(
          GetTableFilterFromView(Database::"FS Work Order", FSWorkOrder.TableCaption(), FSWorkOrder.GetView()));
        IntegrationTableMapping."Dependency Filter" := 'CUSTOMER|SRVORDERTYPE';
        IntegrationTableMapping.Modify();

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          ServiceOrder.FieldNo("Document Type"),
          0, IntegrationFieldMapping.Direction::FromIntegrationTable,
          'Order', true, false);

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          ServiceOrder.FieldNo("No."),
          FSWorkOrder.FieldNo(Name),
          IntegrationFieldMapping.Direction::Bidirectional,
          '', true, false);

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          ServiceOrder.FieldNo("Customer No."),
          FSWorkOrder.FieldNo(ServiceAccount),
          IntegrationFieldMapping.Direction::Bidirectional,
          '', true, false);

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          ServiceOrder.FieldNo("Order Date"),
          FSWorkOrder.FieldNo(CreatedOn),
          IntegrationFieldMapping.Direction::FromIntegrationTable,
          '', true, false);

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          ServiceOrder.FieldNo("Service Order Type"),
          FSWorkOrder.FieldNo(WorkOrderType),
          IntegrationFieldMapping.Direction::Bidirectional,
          '', true, false);

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          ServiceOrder.FieldNo("Work Description"),
          FSWorkOrder.FieldNo(WorkOrderSummary),
          IntegrationFieldMapping.Direction::Bidirectional,
          '', true, false);

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          ServiceOrder.FieldNo(Status),
          FSWorkOrder.FieldNo(SystemStatus),
          IntegrationFieldMapping.Direction::Bidirectional,
          '', true, false);

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          0,
          FSWorkOrder.FieldNo(IntegrateToService),
          IntegrationFieldMapping.Direction::Bidirectional,
          'true', true, false);

        RecreateJobQueueEntryFromIntTableMapping(IntegrationTableMapping, 1, ShouldRecreateJobQueueEntry, 30);
        CRMSetupDefaults.RecreateJobQueueEntry(ShouldRecreateJobQueueEntry, Codeunit::"FS Archived Service Orders Job", 30, StrSubstNo(ArchivedServiceOrdersSynchJobDescTxt, CRMProductName.SHORT()), false)
    end;

    local procedure ResetServiceOrderItemLineMapping(var FSConnectionSetup: Record "FS Connection Setup"; IntegrationTableMappingName: Code[20])
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        IntegrationFieldMapping: Record "Integration Field Mapping";
        ServiceItemLine: Record "Service Item Line";
        FSWorkOrderIncident: Record "FS Work Order Incident";
        CDSCompany: Record "CDS Company";
        CDSIntegrationMgt: Codeunit "CDS Integration Mgt.";
    begin
        if not (FSConnectionSetup."Integration Type" = FSConnectionSetup."Integration Type"::"Service and projects") then
            exit;

        ServiceItemLine.Reset();
        ServiceItemLine.SetRange("Document Type", ServiceItemLine."Document Type"::Order);
        ServiceItemLine.SetRange("FS Bookings", false);

        FSWorkOrderIncident.Reset();
        if CDSIntegrationMgt.GetCDSCompany(CDSCompany) then
            FSWorkOrderIncident.SetRange(CompanyId, CDSCompany.CompanyId);

        InsertIntegrationTableMapping(
          IntegrationTableMapping, IntegrationTableMappingName,
          Database::"Service Item Line", Database::"FS Work Order Incident",
          FSWorkOrderIncident.FieldNo(WorkOrderIncidentId), FSWorkOrderIncident.FieldNo(ModifiedOn),
          '', '', false);

        IntegrationTableMapping.SetTableFilter(
          GetTableFilterFromView(Database::"Service Item Line", ServiceItemLine.TableCaption(), ServiceItemLine.GetView()));
        IntegrationTableMapping.SetIntegrationTableFilter(
          GetTableFilterFromView(Database::"FS Work Order Incident", FSWorkOrderIncident.TableCaption(), FSWorkOrderIncident.GetView()));
        IntegrationTableMapping."Dependency Filter" := 'SRVORDER|SVCITEM-CUSTASSET';
        IntegrationTableMapping."Update-Conflict Resolution" := IntegrationTableMapping."Update-Conflict Resolution"::"Get Update from Integration";
        IntegrationTableMapping.Modify();

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          ServiceItemLine.FieldNo("Document Type"),
          0, IntegrationFieldMapping.Direction::FromIntegrationTable,
          'Order', true, false);

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          ServiceItemLine.FieldNo("Service Item No."),
          FSWorkOrderIncident.FieldNo(CustomerAsset),
          IntegrationFieldMapping.Direction::Bidirectional,
          '', true, false);

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          ServiceItemLine.FieldNo(Description),
          FSWorkOrderIncident.FieldNo(Description),
          IntegrationFieldMapping.Direction::Bidirectional,
          '', true, false);

    end;

    local procedure ResetServiceOrderLineItemMapping(var FSConnectionSetup: Record "FS Connection Setup"; IntegrationTableMappingName: Code[20])
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        IntegrationFieldMapping: Record "Integration Field Mapping";
        ServiceLine: Record "Service Line";
        FSWorkOrderProduct: Record "FS Work Order Product";
        CDSCompany: Record "CDS Company";
        InventorySetup: Record "Inventory Setup";
        CDSIntegrationMgt: Codeunit "CDS Integration Mgt.";
        EmptyGuid: Guid;
    begin
        if not (FSConnectionSetup."Integration Type" = FSConnectionSetup."Integration Type"::"Service and projects") then
            exit;

        ServiceLine.Reset();
        ServiceLine.SetRange("Document Type", ServiceLine."Document Type"::Order);
        ServiceLine.SetRange(Type, ServiceLine.Type::Item);
        ServiceLine.SetFilter("Item Type", '%1|%2', ServiceLine."Item Type"::Inventory, ServiceLine."Item Type"::"Non-Inventory");
        FSWorkOrderProduct.Reset();
        FSWorkOrderProduct.SetFilter(WorkOrderIncident, '<>%1', EmptyGuid);
        if CDSIntegrationMgt.GetCDSCompany(CDSCompany) then
            FSWorkOrderProduct.SetRange(CompanyId, CDSCompany.CompanyId);

        InsertIntegrationTableMapping(
          IntegrationTableMapping, IntegrationTableMappingName,
          Database::"Service Line", Database::"FS Work Order Product",
          FSWorkOrderProduct.FieldNo(WorkOrderProductId), FSWorkOrderProduct.FieldNo(ModifiedOn),
          '', '', false);

        IntegrationTableMapping.SetTableFilter(
          GetTableFilterFromView(Database::"Service Line", ServiceLine.TableCaption(), ServiceLine.GetView()));
        IntegrationTableMapping.SetIntegrationTableFilter(
          GetTableFilterFromView(Database::"FS Work Order Product", FSWorkOrderProduct.TableCaption(), FSWorkOrderProduct.GetView()));
        IntegrationTableMapping."Dependency Filter" := 'SRVORDER|SRVORDERITEMLINE';
        IntegrationTableMapping."Update-Conflict Resolution" := IntegrationTableMapping."Update-Conflict Resolution"::"Get Update from Integration";
        IntegrationTableMapping.Modify();

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          ServiceLine.FieldNo("Document Type"),
          0, IntegrationFieldMapping.Direction::FromIntegrationTable,
          'Order', true, false);

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          ServiceLine.FieldNo("Service Item Line No."),
          FSWorkOrderProduct.FieldNo(WorkOrderIncident),
          IntegrationFieldMapping.Direction::Bidirectional,
          '', true, false);

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          ServiceLine.FieldNo("No."),
          FSWorkOrderProduct.FieldNo(Product),
          IntegrationFieldMapping.Direction::Bidirectional,
          '', true, false);

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          ServiceLine.FieldNo("No."),
          FSWorkOrderProduct.FieldNo(ProductId),
          IntegrationFieldMapping.Direction::ToIntegrationTable,
          '', true, false);

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          ServiceLine.FieldNo(Description),
          FSWorkOrderProduct.FieldNo(Name),
          IntegrationFieldMapping.Direction::Bidirectional,
          '', true, false);

        if InventorySetup.Get() and (InventorySetup."Location Mandatory") then begin
            InsertIntegrationFieldMapping(
              IntegrationTableMappingName,
              ServiceLine.FieldNo("Location Code"),
              FSWorkOrderProduct.FieldNo(WarehouseId),
              IntegrationFieldMapping.Direction::Bidirectional,
              '', true, false);

            InsertIntegrationFieldMapping(
              IntegrationTableMappingName,
              ServiceLine.FieldNo("Location Code"),
              FSWorkOrderProduct.FieldNo(LocationCode),
              IntegrationFieldMapping.Direction::ToIntegrationTable,
              '', true, false);
        end;

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          ServiceLine.FieldNo("Unit of Measure Code"),
          FSWorkOrderProduct.FieldNo(Unit),
          IntegrationFieldMapping.Direction::Bidirectional,
          '', true, false);

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          ServiceLine.FieldNo("Quantity Shipped"),
          FSWorkOrderProduct.FieldNo(QuantityShipped),
          IntegrationFieldMapping.Direction::ToIntegrationTable,
          '', true, false);

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          ServiceLine.FieldNo("Quantity Invoiced"),
          FSWorkOrderProduct.FieldNo(QuantityInvoiced),
          IntegrationFieldMapping.Direction::ToIntegrationTable,
          '', true, false);

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          ServiceLine.FieldNo("Quantity Consumed"),
          FSWorkOrderProduct.FieldNo(QuantityConsumed),
          IntegrationFieldMapping.Direction::ToIntegrationTable,
          '', true, false);

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          0,
          FSWorkOrderProduct.FieldNo(IntegrateToService),
          IntegrationFieldMapping.Direction::Bidirectional,
          'true', true, false);

    end;

    local procedure ResetServiceOrderLineServiceItemMapping(var FSConnectionSetup: Record "FS Connection Setup"; IntegrationTableMappingName: Code[20])
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        IntegrationFieldMapping: Record "Integration Field Mapping";
        ServiceLine: Record "Service Line";
        FSWorkOrderService: Record "FS Work Order Service";
        CDSCompany: Record "CDS Company";
        CDSIntegrationMgt: Codeunit "CDS Integration Mgt.";
        EmptyGuid: Guid;
    begin
        if not (FSConnectionSetup."Integration Type" = FSConnectionSetup."Integration Type"::"Service and projects") then
            exit;

        ServiceLine.Reset();
        ServiceLine.SetRange("Document Type", ServiceLine."Document Type"::Order);
        ServiceLine.SetRange(Type, ServiceLine.Type::Item);
        ServiceLine.SetRange("Item Type", ServiceLine."Item Type"::Service);
        FSWorkOrderService.Reset();
        FSWorkOrderService.SetFilter(WorkOrderIncident, '<>%1', EmptyGuid);
        if CDSIntegrationMgt.GetCDSCompany(CDSCompany) then
            FSWorkOrderService.SetRange(CompanyId, CDSCompany.CompanyId);

        InsertIntegrationTableMapping(
          IntegrationTableMapping, IntegrationTableMappingName,
          Database::"Service Line", Database::"FS Work Order Service",
          FSWorkOrderService.FieldNo(WorkOrderServiceId), FSWorkOrderService.FieldNo(ModifiedOn),
          '', '', false);

        IntegrationTableMapping.SetTableFilter(
          GetTableFilterFromView(Database::"Service Line", ServiceLine.TableCaption(), ServiceLine.GetView()));
        IntegrationTableMapping.SetIntegrationTableFilter(
          GetTableFilterFromView(Database::"FS Work Order Service", FSWorkOrderService.TableCaption(), FSWorkOrderService.GetView()));
        IntegrationTableMapping."Dependency Filter" := 'SRVORDER|SRVORDERITEMLINE';
        IntegrationTableMapping."Update-Conflict Resolution" := IntegrationTableMapping."Update-Conflict Resolution"::"Get Update from Integration";
        IntegrationTableMapping.Modify();

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          ServiceLine.FieldNo("Document Type"),
          0, IntegrationFieldMapping.Direction::FromIntegrationTable,
          'Order', true, false);

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          ServiceLine.FieldNo("Service Item Line No."),
          FSWorkOrderService.FieldNo(WorkOrderIncident),
          IntegrationFieldMapping.Direction::Bidirectional,
          '', true, false);

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          ServiceLine.FieldNo("No."),
          FSWorkOrderService.FieldNo(Service),
          IntegrationFieldMapping.Direction::Bidirectional,
          '', true, false);

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          ServiceLine.FieldNo(Description),
          FSWorkOrderService.FieldNo(Name),
          IntegrationFieldMapping.Direction::Bidirectional,
          '', true, false);

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          ServiceLine.FieldNo("Unit of Measure Code"),
          FSWorkOrderService.FieldNo(Unit),
          IntegrationFieldMapping.Direction::Bidirectional,
          '', true, false);

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          ServiceLine.FieldNo("Quantity Shipped"),
          FSWorkOrderService.FieldNo(DurationShipped),
          IntegrationFieldMapping.Direction::ToIntegrationTable,
          '', true, false);

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          ServiceLine.FieldNo("Quantity Invoiced"),
          FSWorkOrderService.FieldNo(DurationInvoiced),
          IntegrationFieldMapping.Direction::ToIntegrationTable,
          '', true, false);

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          ServiceLine.FieldNo("Quantity Consumed"),
          FSWorkOrderService.FieldNo(DurationConsumed),
          IntegrationFieldMapping.Direction::ToIntegrationTable,
          '', true, false);

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          0,
          FSWorkOrderService.FieldNo(IntegrateToService),
          IntegrationFieldMapping.Direction::Bidirectional,
          'true', true, false);

    end;

    local procedure ResetServiceOrderLineResourceMapping(var FSConnectionSetup: Record "FS Connection Setup"; IntegrationTableMappingName: Code[20])
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        IntegrationFieldMapping: Record "Integration Field Mapping";
        ServiceLine: Record "Service Line";
        FSBookableResourceBooking: Record "FS Bookable Resource Booking";
        CDSCompany: Record "CDS Company";
        CDSIntegrationMgt: Codeunit "CDS Integration Mgt.";
        EmptyGuid: Guid;
    begin
        if not (FSConnectionSetup."Integration Type" = FSConnectionSetup."Integration Type"::"Service and projects") then
            exit;

        ServiceLine.Reset();
        ServiceLine.SetRange("Document Type", ServiceLine."Document Type"::Order);
        ServiceLine.SetRange(Type, ServiceLine.Type::Resource);

        FSBookableResourceBooking.Reset();
        FSBookableResourceBooking.SetFilter(WorkOrder, '<>%1', EmptyGuid);
        FSBookableResourceBooking.SetRange(BookingStatus, CompletedBookingStatus());
        if CDSIntegrationMgt.GetCDSCompany(CDSCompany) then
            FSBookableResourceBooking.SetRange(CompanyId, CDSCompany.CompanyId);

        InsertIntegrationTableMapping(
          IntegrationTableMapping, IntegrationTableMappingName,
          Database::"Service Line", Database::"FS Bookable Resource Booking",
          FSBookableResourceBooking.FieldNo(BookableResourceBookingId), FSBookableResourceBooking.FieldNo(ModifiedOn),
          '', '', false);

        IntegrationTableMapping.SetTableFilter(
          GetTableFilterFromView(Database::"Service Line", ServiceLine.TableCaption(), ServiceLine.GetView()));
        IntegrationTableMapping.SetIntegrationTableFilter(
          GetTableFilterFromView(Database::"FS Bookable Resource Booking", FSBookableResourceBooking.TableCaption(), FSBookableResourceBooking.GetView()));
        IntegrationTableMapping."Dependency Filter" := 'SRVORDER|SRVORDERITEMLINE|RESOURCE-BOOKABLERSC';
        IntegrationTableMapping."Update-Conflict Resolution" := IntegrationTableMapping."Update-Conflict Resolution"::"Get Update from Integration";
        IntegrationTableMapping.Modify();

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          ServiceLine.FieldNo("Document Type"),
          0, IntegrationFieldMapping.Direction::FromIntegrationTable,
          'Order', true, false);

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          ServiceLine.FieldNo("No."),
          FSBookableResourceBooking.FieldNo(Resource),
          IntegrationFieldMapping.Direction::FromIntegrationTable,
          '', true, false);

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          ServiceLine.FieldNo(Description),
          FSBookableResourceBooking.FieldNo(Name),
          IntegrationFieldMapping.Direction::FromIntegrationTable,
          '', true, false);

        InsertIntegrationFieldMapping(
          IntegrationTableMappingName,
          0,
          FSBookableResourceBooking.FieldNo(IntegrateToService),
          IntegrationFieldMapping.Direction::Bidirectional,
          'true', true, false);

    end;

    local procedure ShouldResetServiceItemMapping(): Boolean
    var
        ApplicationAreaMgmtFacade: Codeunit "Application Area Mgmt. Facade";
    begin
        exit(ApplicationAreaMgmtFacade.IsPremiumExperienceEnabled());
    end;

    local procedure InsertIntegrationTableMapping(var IntegrationTableMapping: Record "Integration Table Mapping"; MappingName: Code[20]; TableNo: Integer; IntegrationTableNo: Integer; IntegrationTableUIDFieldNo: Integer; IntegrationTableModifiedFieldNo: Integer; TableConfigTemplateCode: Code[10]; IntegrationTableConfigTemplateCode: Code[10]; SynchOnlyCoupledRecords: Boolean)
    var
        CDSIntegrationMgt: Codeunit "CDS Integration Mgt.";
        UncoupleCodeunitId: Integer;
        Direction: Integer;
    begin
        Direction := GetDefaultDirection(TableNo);
        if Direction in [IntegrationTableMapping.Direction::ToIntegrationTable, IntegrationTableMapping.Direction::Bidirectional] then
            if CDSIntegrationMgt.HasCompanyIdField(IntegrationTableNo) or HasFieldServiceCompanyIdField(IntegrationTableNo) then
                UncoupleCodeunitId := Codeunit::"CDS Int. Table Uncouple";
        IntegrationTableMapping.CreateRecord(MappingName, TableNo, IntegrationTableNo, IntegrationTableUIDFieldNo,
          IntegrationTableModifiedFieldNo, TableConfigTemplateCode, IntegrationTableConfigTemplateCode,
          SynchOnlyCoupledRecords, Direction, IntegrationTablePrefixTok,
          Codeunit::"CRM Integration Table Synch.", UncoupleCodeunitId);
    end;

    local procedure InsertIntegrationFieldMapping(IntegrationTableMappingName: Code[20]; TableFieldNo: Integer; IntegrationTableFieldNo: Integer; SynchDirection: Option; ConstValue: Text; ValidateField: Boolean; ValidateIntegrationTableField: Boolean)
    var
        IntegrationFieldMapping: Record "Integration Field Mapping";
    begin
        IntegrationFieldMapping.CreateRecord(IntegrationTableMappingName, TableFieldNo, IntegrationTableFieldNo, SynchDirection,
          ConstValue, ValidateField, ValidateIntegrationTableField);
    end;

    local procedure RecreateJobQueueEntryFromIntTableMapping(IntegrationTableMapping: Record "Integration Table Mapping"; IntervalInMinutes: Integer; ShouldRecreateJobQueueEntry: Boolean; InactivityTimeoutPeriod: Integer)
    var
        JobQueueEntry: Record "Job Queue Entry";
    begin
        JobQueueEntry.SetRange("Object Type to Run", JobQueueEntry."Object Type to Run"::Codeunit);
        JobQueueEntry.SetRange("Object ID to Run", Codeunit::"Integration Synch. Job Runner");
        JobQueueEntry.SetRange("Record ID to Process", IntegrationTableMapping.RecordId());
        JobQueueEntry.DeleteTasks();
        JobQueueEntry.InitRecurringJob(IntervalInMinutes);
        JobQueueEntry."Object Type to Run" := JobQueueEntry."Object Type to Run"::Codeunit;
        JobQueueEntry."Object ID to Run" := Codeunit::"Integration Synch. Job Runner";
        JobQueueEntry."Record ID to Process" := IntegrationTableMapping.RecordId();
        JobQueueEntry."Run in User Session" := false;
        JobQueueEntry.Description :=
          CopyStr(StrSubstNo(JobQueueEntryNameTok, IntegrationTableMapping.Name, CRMProductName.CDSServiceName()), 1, MaxStrLen(JobQueueEntry.Description));
        JobQueueEntry."Maximum No. of Attempts to Run" := 10;
        JobQueueEntry.Status := JobQueueEntry.Status::Ready;
        JobQueueEntry."Rerun Delay (sec.)" := 30;
        JobQueueEntry."Inactivity Timeout Period" := InactivityTimeoutPeriod;
        if ShouldRecreateJobQueueEntry then
            Codeunit.Run(Codeunit::"Job Queue - Enqueue", JobQueueEntry)
        else
            JobQueueEntry.Insert(true);
    end;

    /// <summary>
    /// Returns the default direction of a Field Service mapping by its Business Central table.
    /// </summary>
    /// <param name="NAVTableID">The Business Central table.</param>
    /// <returns>The direction; Bidirectional for the service order lines.</returns>
    internal procedure GetDefaultDirection(NAVTableID: Integer): Integer
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
    begin
        case NAVTableID of
            Database::"Job Task",
            Database::Location:
                exit(IntegrationTableMapping.Direction::ToIntegrationTable);
            Database::"Job Journal Line":
                exit(IntegrationTableMapping.Direction::FromIntegrationTable);
        end;
        exit(IntegrationTableMapping.Direction::Bidirectional);
    end;

    local procedure GetTableFilterFromView(TableID: Integer; Caption: Text; View: Text): Text
    var
        FilterBuilder: FilterPageBuilder;
    begin
        FilterBuilder.AddTable(Caption, TableID);
        FilterBuilder.SetView(Caption, View);
        exit(FilterBuilder.GetView(Caption, false));
    end;

    local procedure CompletedBookingStatus(): Guid
    var
        FSBookingStatus: Record "FS Booking Status";
    begin
        FSBookingStatus.SetRange(FieldServiceStatus, FSBookingStatus.FieldServiceStatus::Completed);
        if FSBookingStatus.FindFirst() then
            exit(FSBookingStatus.BookingStatusId);
    end;

    local procedure HasFieldServiceCompanyIdField(IntegrationTableNo: Integer): Boolean
    begin
        exit(IntegrationTableNo in [Database::"FS Work Order", Database::"FS Bookable Resource", Database::"FS Customer Asset", Database::"FS Work Order Product",
          Database::"FS Work Order Service", Database::"FS Project Task", Database::"FS Warehouse"]);
    end;

    local procedure IsLocationMandatory(): Boolean
    var
        InventorySetup: Record "Inventory Setup";
    begin
        InventorySetup.SetLoadFields("Location Mandatory");
        if InventorySetup.Get() then
            exit(InventorySetup."Location Mandatory");
        exit(false);
    end;

    local procedure EnableServiceOrderArchive()
    var
        ServiceMgtSetup: Record "Service Mgt. Setup";
    begin
        ServiceMgtSetup.Get();
        if ServiceMgtSetup."Archive Orders" then
            exit;
        ServiceMgtSetup.Validate("Archive Orders", true);
        ServiceMgtSetup.Modify(true);
    end;

    local procedure AddProductTypeFieldMapping()
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        IntegrationFieldMapping: Record "Integration Field Mapping";
        Item: Record Item;
        CRMProduct: Record "CRM Product";
    begin
        if not IntegrationTableMapping.Get(ItemProductMappingTok) then
            exit;
        IntegrationFieldMapping.SetRange("Integration Table Mapping Name", ItemProductMappingTok);
        IntegrationFieldMapping.SetRange("Field No.", Item.FieldNo(Type));
        IntegrationFieldMapping.SetRange("Integration Table Field No.", CRMProduct.FieldNo(FieldServiceProductType));
        if not IntegrationFieldMapping.IsEmpty() then
            exit;
        InsertIntegrationFieldMapping(ItemProductMappingTok, Item.FieldNo(Type), CRMProduct.FieldNo(FieldServiceProductType),
          IntegrationFieldMapping.Direction::ToIntegrationTable, '', false, false);
    end;

    local procedure SwitchFieldServiceMappings()
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        DefaultAssignment: Codeunit "DVI Default Assignment";
        MappingNames: List of [Code[20]];
        MappingName: Code[20];
    begin
        MappingNames.AddRange('PROJECTTASK', 'PJLINE-WORDERPRODUCT', 'PJLINE-WORDERSERVICE', 'SVCITEM-CUSTASSET', 'RESOURCE-BOOKABLERSC', 'LOCATION',
          'SRVORDERTYPE', 'SRVORDER', 'SRVORDERITEMLINE', 'SRVORDERLINE-ITEM', 'SRVORDERLINE-SERVICE', 'SRVORDERLINE-RESOURC');
        foreach MappingName in MappingNames do
            if IntegrationTableMapping.Get(MappingName) then
                DefaultAssignment.SwitchToRedesigned(IntegrationTableMapping);
    end;
}
