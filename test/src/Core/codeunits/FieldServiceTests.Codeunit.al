namespace DataverseIntegration.Test;

using DataverseIntegration.Core;
using DataverseIntegration.FieldService;
using Microsoft.Integration.DynamicsFieldService;
using Microsoft.Integration.SyncEngine;
using Microsoft.Inventory.Location;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Journal;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Service.Document;
using Microsoft.Service.Item;
using Microsoft.Service.Setup;
using System.TestLibraries.Utilities;

codeunit 84021 "DVI Field Service Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLibrary: Codeunit "DVI Test Library";

    [Test]
    procedure SwitchingPicksTheHandlerOfEachFieldServicePair()
    begin
        // [GIVEN] / [WHEN] Mappings of each Field Service table pair are switched
        // [THEN] Each gets its handler and the Field Service module
        AssertSwitchedHandler('DVIFSRES', Database::Resource, Database::"FS Bookable Resource", Enum::"DVI Sync Handler"::DVIFSBookableResource);
        AssertSwitchedHandler('DVIFSASSET', Database::"Service Item", Database::"FS Customer Asset", Enum::"DVI Sync Handler"::DVIFSCustomerAsset);
        AssertSwitchedHandler('DVIFSLOC', Database::Location, Database::"FS Warehouse", Enum::"DVI Sync Handler"::DVIFSWarehouse);
        AssertSwitchedHandler('DVIFSWOTYPE', Database::"Service Order Type", Database::"FS Work Order Type", Enum::"DVI Sync Handler"::DVIFSWorkOrderType);
        AssertSwitchedHandler('DVIFSTASK', Database::"Job Task", Database::"FS Project Task", Enum::"DVI Sync Handler"::DVIFSProjectTask);
        AssertSwitchedHandler('DVIFSPJWOP', Database::"Job Journal Line", Database::"FS Work Order Product", Enum::"DVI Sync Handler"::DVIFSProjectLine);
        AssertSwitchedHandler('DVIFSPJWOS', Database::"Job Journal Line", Database::"FS Work Order Service", Enum::"DVI Sync Handler"::DVIFSProjectLine);
        AssertSwitchedHandler('DVIFSWO', Database::"Service Header", Database::"FS Work Order", Enum::"DVI Sync Handler"::DVIFSWorkOrder);
        AssertSwitchedHandler('DVIFSINC', Database::"Service Item Line", Database::"FS Work Order Incident", Enum::"DVI Sync Handler"::DVIFSWorkOrderIncident);
        AssertSwitchedHandler('DVIFSSLWOP', Database::"Service Line", Database::"FS Work Order Product", Enum::"DVI Sync Handler"::DVIFSWorkOrderLine);
        AssertSwitchedHandler('DVIFSSLBOOK', Database::"Service Line", Database::"FS Bookable Resource Booking", Enum::"DVI Sync Handler"::DVIFSWorkOrderLine);
    end;

    [Test]
    procedure ResourceTypeFollowsTheResource()
    var
        Resource: Record Resource;
        FSBookableResource: Record "FS Bookable Resource";
        BookableResourceHandler: Codeunit "DVI Bookable Resource Handler";
    begin
        // [GIVEN] / [WHEN] / [THEN] Machines are equipment; people are accounts with a vendor, users with time sheets, else generic
        Resource.Type := Resource.Type::Machine;
        Assert.AreEqual(FSBookableResource.ResourceType::Equipment, BookableResourceHandler.ResourceTypeOf(Resource), 'Machine');
        Resource.Type := Resource.Type::Person;
        Resource."Vendor No." := 'V1';
        Assert.AreEqual(FSBookableResource.ResourceType::Account, BookableResourceHandler.ResourceTypeOf(Resource), 'Person with vendor');
        Resource."Vendor No." := '';
        Resource."Time Sheet Owner User ID" := 'USER';
        Assert.AreEqual(FSBookableResource.ResourceType::User, BookableResourceHandler.ResourceTypeOf(Resource), 'Person with time sheets');
        Resource."Time Sheet Owner User ID" := '';
        Assert.AreEqual(FSBookableResource.ResourceType::Generic, BookableResourceHandler.ResourceTypeOf(Resource), 'Other person');
    end;

    [Test]
    procedure CrewsAndPoolsAreNotSynchronized()
    var
        TempFSBookableResource: Record "FS Bookable Resource" temporary;
        BookableResourceHandler: Codeunit "DVI Bookable Resource Handler";
        Context: Codeunit "DVI Sync Context";
        SourceRecordRef: RecordRef;
    begin
        // [GIVEN] A crew bookable resource
        TempFSBookableResource.ResourceType := TempFSBookableResource.ResourceType::Crew;
        SourceRecordRef.GetTable(TempFSBookableResource);

        // [WHEN] / [THEN] It is left out, whether Field Service is enabled or not
        Assert.IsTrue(BookableResourceHandler.IgnoreRecord(Context, SourceRecordRef), 'Crews have no Business Central resource.');

        // [GIVEN] / [WHEN] / [THEN] A user resource is synchronized
        TempFSBookableResource.ResourceType := TempFSBookableResource.ResourceType::User;
        SourceRecordRef.GetTable(TempFSBookableResource);
        Assert.IsFalse(BookableResourceHandler.IgnoreRecord(Context, SourceRecordRef), 'Users are synchronized.');
    end;

    [Test]
    procedure OnlyTasksOfOpenProjectsWithUsageLinkGoToFieldService()
    var
        Job: Record Job;
        ProjectTaskHandler: Codeunit "DVI Project Task Handler";
    begin
        // [GIVEN] An open project that applies usage links
        Job.Init();
        Job."No." := 'DVIJOB1';
        Job.Status := Job.Status::Open;
        Job."Apply Usage Link" := true;
        Job.Insert(false);

        // [WHEN] / [THEN] Its tasks go to Field Service
        Assert.IsTrue(ProjectTaskHandler.IsProjectOpenForFieldService('DVIJOB1'), 'Open project with usage link');

        // [GIVEN] / [WHEN] / [THEN] Blocked, not open, or without usage link they do not
        Job.Blocked := Job.Blocked::All;
        Job.Modify(false);
        Assert.IsFalse(ProjectTaskHandler.IsProjectOpenForFieldService('DVIJOB1'), 'Blocked project');
        Job.Blocked := Job.Blocked::" ";
        Job.Status := Job.Status::Completed;
        Job.Modify(false);
        Assert.IsFalse(ProjectTaskHandler.IsProjectOpenForFieldService('DVIJOB1'), 'Completed project');
        Job.Status := Job.Status::Open;
        Job."Apply Usage Link" := false;
        Job.Modify(false);
        Assert.IsFalse(ProjectTaskHandler.IsProjectOpenForFieldService('DVIJOB1'), 'Project without usage link');
        Assert.IsFalse(ProjectTaskHandler.IsProjectOpenForFieldService('DVINOJOB'), 'Missing project');
    end;

    [Test]
    procedure DurationsAreConvertedBetweenMinutesAndHours()
    var
        FSValueConverter: Codeunit "DVI FS Value Converter";
    begin
        // [GIVEN] / [WHEN] / [THEN] Field Service minutes become hours and back
        Assert.AreEqual(1.5, FSValueConverter.MinutesToHours(90), 'Minutes to hours');
        Assert.AreEqual(90, FSValueConverter.HoursToMinutes(1.5), 'Hours to minutes');
    end;

    [Test]
    procedure WorkOrderStatusMapsToServiceOrderStatus()
    var
        FSWorkOrder: Record "FS Work Order";
        FSValueConverter: Codeunit "DVI FS Value Converter";
    begin
        // [GIVEN] / [WHEN] / [THEN] Unscheduled and scheduled are pending, in progress is in process, completed is finished, others keep the status
        Assert.AreEqual(Enum::"Service Document Status"::Pending, FSValueConverter.ServiceStatusFor(FSWorkOrder.SystemStatus::Unscheduled, Enum::"Service Document Status"::"On Hold"), 'Unscheduled');
        Assert.AreEqual(Enum::"Service Document Status"::Pending, FSValueConverter.ServiceStatusFor(FSWorkOrder.SystemStatus::Scheduled, Enum::"Service Document Status"::"On Hold"), 'Scheduled');
        Assert.AreEqual(Enum::"Service Document Status"::"In Process", FSValueConverter.ServiceStatusFor(FSWorkOrder.SystemStatus::InProgress, Enum::"Service Document Status"::Pending), 'In progress');
        Assert.AreEqual(Enum::"Service Document Status"::Finished, FSValueConverter.ServiceStatusFor(FSWorkOrder.SystemStatus::Completed, Enum::"Service Document Status"::Pending), 'Completed');
        Assert.AreEqual(Enum::"Service Document Status"::"On Hold", FSValueConverter.ServiceStatusFor(FSWorkOrder.SystemStatus::Canceled, Enum::"Service Document Status"::"On Hold"), 'Canceled keeps the status');
    end;

    [Test]
    procedure WorkOrderStatusFieldGetsTheFieldServiceConverter()
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        ServiceHeader: Record "Service Header";
        FSWorkOrder: Record "FS Work Order";
        FieldConverter: Record "DVI Field Converter";
        DefaultAssignment: Codeunit "DVI Default Assignment";
    begin
        // [GIVEN] A service order mapping with the field mapping Status - SystemStatus
        IntegrationTableMapping := TestLibrary.CreateDataverseMapping('DVIFSWO2', Database::"Service Header", Database::"FS Work Order", IntegrationTableMapping.Direction::FromIntegrationTable);
        TestLibrary.CreateFieldMapping('DVIFSWO2', ServiceHeader.FieldNo(Status), FSWorkOrder.FieldNo(SystemStatus), IntegrationTableMapping.Direction::FromIntegrationTable, '');

        // [WHEN] The mapping is switched
        DefaultAssignment.SwitchToRedesigned(IntegrationTableMapping);

        // [THEN] The field gets the Field Service converter
        FieldConverter.Get('DVIFSWO2', ServiceHeader.FieldNo(Status), FSWorkOrder.FieldNo(SystemStatus));
        Assert.AreEqual(Enum::"DVI Value Converter"::DVIFieldServiceValue, FieldConverter.Converter, 'Converter');
    end;

    [Test]
    procedure ServiceOrderQuantitiesUseTheLargerOfQuantityAndQuantityToBill()
    var
        FSServiceOrders: Codeunit "DVI FS Service Orders";
    begin
        // [GIVEN] / [WHEN] / [THEN] The larger quantity is shipped
        Assert.AreEqual(5, FSServiceOrders.MaxOf(3, 5), 'Quantity to bill larger');
        Assert.AreEqual(4, FSServiceOrders.MaxOf(4, 2), 'Quantity larger');
    end;

    [Test]
    procedure ProjectJournalLinesAreFromFieldServiceAndOthersBidirectional()
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        FSMappingDefaults: Codeunit "DVI FS Mapping Defaults";
    begin
        // [GIVEN] / [WHEN] / [THEN] Journal lines come from Field Service, tasks and locations go to it, the rest is bidirectional
        Assert.AreEqual(IntegrationTableMapping.Direction::FromIntegrationTable, FSMappingDefaults.GetDefaultDirection(Database::"Job Journal Line"), 'Journal lines');
        Assert.AreEqual(IntegrationTableMapping.Direction::ToIntegrationTable, FSMappingDefaults.GetDefaultDirection(Database::"Job Task"), 'Project tasks');
        Assert.AreEqual(IntegrationTableMapping.Direction::ToIntegrationTable, FSMappingDefaults.GetDefaultDirection(Database::Location), 'Locations');
        Assert.AreEqual(IntegrationTableMapping.Direction::Bidirectional, FSMappingDefaults.GetDefaultDirection(Database::"Service Line"), 'Service lines');
    end;

    [Test]
    procedure ServiceOrdersWithChangedLinesAreFound()
    var
        ServiceHeader: Record "Service Header";
        ServiceLine: Record "Service Line";
        FSServiceOrders: Codeunit "DVI FS Service Orders";
        ServiceHeaderIds: List of [Guid];
    begin
        // [GIVEN] A service order with a line
        ServiceHeader."Document Type" := ServiceHeader."Document Type"::Order;
        ServiceHeader."No." := 'DVISVO1';
        ServiceHeader.Insert(false);
        ServiceLine."Document Type" := ServiceLine."Document Type"::Order;
        ServiceLine."Document No." := 'DVISVO1';
        ServiceLine."Line No." := 10000;
        ServiceLine.Insert(false);

        // [WHEN] Orders with changed lines are searched
        FSServiceOrders.FindOrdersWithChangedLines(0DT, ServiceHeaderIds);

        // [THEN] The order is found once
        Assert.IsTrue(ServiceHeaderIds.Contains(ServiceHeader.SystemId), 'The order of the changed line must be found.');
    end;

    local procedure AssertSwitchedHandler(MappingName: Code[20]; TableId: Integer; IntegrationTableId: Integer; ExpectedHandler: Enum "DVI Sync Handler")
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        MappingAssignment: Record "DVI Mapping Assignment";
        DefaultAssignment: Codeunit "DVI Default Assignment";
    begin
        IntegrationTableMapping := TestLibrary.CreateDataverseMapping(MappingName, TableId, IntegrationTableId, IntegrationTableMapping.Direction::Bidirectional);
        DefaultAssignment.SwitchToRedesigned(IntegrationTableMapping);
        MappingAssignment.Get(MappingName);
        Assert.AreEqual(ExpectedHandler, MappingAssignment.Handler, MappingName);
        Assert.AreEqual(Enum::"DVI Integration Module"::DVIFieldService, MappingAssignment.Module, MappingName);
    end;
}
