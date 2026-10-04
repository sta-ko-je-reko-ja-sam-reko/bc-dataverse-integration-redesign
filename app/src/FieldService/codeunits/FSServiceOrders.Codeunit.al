namespace DataverseIntegration.FieldService;

using DataverseIntegration.CDS;
using DataverseIntegration.Core;
using Microsoft.Integration.D365Sales;
using Microsoft.Integration.Dataverse;
using Microsoft.Integration.DynamicsFieldService;
using Microsoft.Integration.SyncEngine;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Service.Archive;
using Microsoft.Service.Document;
using Microsoft.Service.Setup;

codeunit 80833 "DVI FS Service Orders"
{
    Access = Internal;

    var
        ArchivedOrders: List of [Code[20]];
        DefaultIncidentTxt: Label 'Service Order Incident';
        DefaultIncidentTypeTxt: Label 'Business Central - Default Incident Type';

    /// <summary>
    /// Returns whether a service order or work order is coupled as archived, or a work order has no incidents yet.
    /// </summary>
    /// <param name="SourceRecordRef">The service header or the work order.</param>
    /// <returns>True to leave the record out.</returns>
    internal procedure IgnoreOrder(var SourceRecordRef: RecordRef): Boolean
    var
        FSWorkOrder: Record "FS Work Order";
        FSWorkOrderIncident: Record "FS Work Order Incident";
        CRMIntegrationRecord: Record "CRM Integration Record";
    begin
        case SourceRecordRef.Number() of
            Database::"Service Header":
                if CRMIntegrationRecord.FindByRecordID(SourceRecordRef.RecordId()) then
                    exit(CRMIntegrationRecord."Archived Service Order");
            Database::"FS Work Order":
                begin
                    SourceRecordRef.SetTable(FSWorkOrder);
                    FSWorkOrderIncident.SetRange(WorkOrder, FSWorkOrder.WorkOrderId);
                    if FSWorkOrderIncident.IsEmpty() then
                        exit(true);
                    exit(IsArchivedWorkOrder(FSWorkOrder.WorkOrderId));
                end;
        end;
        exit(false);
    end;

    /// <summary>
    /// Returns whether a work order product or service belongs to an archived work order.
    /// </summary>
    /// <param name="SourceRecordRef">The work order product or service.</param>
    /// <returns>True to leave the line out.</returns>
    internal procedure IgnoreLine(var SourceRecordRef: RecordRef): Boolean
    var
        FSWorkOrderProduct: Record "FS Work Order Product";
        FSWorkOrderService: Record "FS Work Order Service";
    begin
        case SourceRecordRef.Number() of
            Database::"FS Work Order Product":
                begin
                    SourceRecordRef.SetTable(FSWorkOrderProduct);
                    exit(IsArchivedWorkOrder(FSWorkOrderProduct.WorkOrder));
                end;
            Database::"FS Work Order Service":
                begin
                    SourceRecordRef.SetTable(FSWorkOrderService);
                    exit(IsArchivedWorkOrder(FSWorkOrderService.WorkOrder));
                end;
        end;
        exit(false);
    end;

    /// <summary>
    /// Raises an error when a service order has lines that are not assigned to a service item line, which Field Service cannot hold.
    /// </summary>
    /// <param name="ServiceHeaderRecordRef">The service order.</param>
    internal procedure CheckLinesAssigned(var ServiceHeaderRecordRef: RecordRef)
    var
        ServiceHeader: Record "Service Header";
        ServiceLine: Record "Service Line";
    begin
        ServiceHeaderRecordRef.SetTable(ServiceHeader);
        ServiceLine.SetRange("Document Type", ServiceLine."Document Type"::Order);
        ServiceLine.SetRange("Document No.", ServiceHeader."No.");
        ServiceLine.SetRange("Service Item Line No.", 0);
        if ServiceLine.FindFirst() then
            ServiceLine.TestField("Service Item Line No.");
    end;

    /// <summary>
    /// Recalculates a service order created from a work order from its customer, as the customer was set before the order was initialized.
    /// </summary>
    /// <param name="ServiceHeaderRecordRef">The new service order.</param>
    internal procedure ValidateCustomer(var ServiceHeaderRecordRef: RecordRef)
    var
        ServiceHeader: Record "Service Header";
    begin
        ServiceHeaderRecordRef.SetTable(ServiceHeader);
        ServiceHeader.Get(ServiceHeader."Document Type", ServiceHeader."No.");
        ServiceHeader.Validate("Customer No.");
        ServiceHeader.Modify(true);
        ServiceHeaderRecordRef.GetTable(ServiceHeader);
    end;

    /// <summary>
    /// Removes the service item lines and service lines whose Field Service record was deleted, archiving the order first, and queues the work order's incidents, products, services and completed bookings for synchronization after the order.
    /// </summary>
    /// <param name="Context">The synchronization context, used to queue the lines.</param>
    /// <param name="FSWorkOrderRecordRef">The work order.</param>
    /// <param name="ServiceHeaderRecordRef">The service order.</param>
    internal procedure QueueLinesFromFieldService(var Context: Codeunit "DVI Sync Context"; var FSWorkOrderRecordRef: RecordRef; var ServiceHeaderRecordRef: RecordRef)
    var
        FSWorkOrder: Record "FS Work Order";
        ServiceHeader: Record "Service Header";
    begin
        FSWorkOrderRecordRef.SetTable(FSWorkOrder);
        ServiceHeaderRecordRef.SetTable(ServiceHeader);
        Clear(ArchivedOrders);
        RemoveDeletedItemLines(ServiceHeader);
        RemoveDeletedLines(ServiceHeader, Database::"FS Work Order Product");
        RemoveDeletedLines(ServiceHeader, Database::"FS Work Order Service");
        RemoveDeletedLines(ServiceHeader, Database::"FS Bookable Resource Booking");
        QueueIncidents(Context, FSWorkOrder);
        QueueProducts(Context, FSWorkOrder);
        QueueServices(Context, FSWorkOrder);
        QueueBookings(Context, FSWorkOrder);
    end;

    /// <summary>
    /// Queues the service item lines and the item and service lines of a service order for synchronization to Field Service after the order.
    /// </summary>
    /// <param name="Context">The synchronization context, used to queue the lines.</param>
    /// <param name="ServiceHeaderRecordRef">The service order.</param>
    internal procedure QueueLinesToFieldService(var Context: Codeunit "DVI Sync Context"; var ServiceHeaderRecordRef: RecordRef)
    var
        ServiceHeader: Record "Service Header";
        ServiceItemLine: Record "Service Item Line";
        ServiceLine: Record "Service Line";
        IntegrationTableMapping: Record "Integration Table Mapping";
        FSRecords: Codeunit "DVI FS Records";
    begin
        ServiceHeaderRecordRef.SetTable(ServiceHeader);
        if FSRecords.FindMapping(Database::"Service Item Line", Database::"FS Work Order Incident", IntegrationTableMapping) then begin
            ServiceItemLine.SetRange("Document Type", ServiceHeader."Document Type");
            ServiceItemLine.SetRange("Document No.", ServiceHeader."No.");
            ServiceItemLine.SetRange("FS Bookings", false);
            ServiceItemLine.SetLoadFields(SystemId);
            if ServiceItemLine.FindSet() then
                repeat
                    Context.AddFollowUp(IntegrationTableMapping.Name, ServiceItemLine.SystemId, true);
                until ServiceItemLine.Next() = 0;
        end;
        ServiceLine.SetRange("Document Type", ServiceHeader."Document Type");
        ServiceLine.SetRange("Document No.", ServiceHeader."No.");
        ServiceLine.SetRange(Type, ServiceLine.Type::Item);
        if FSRecords.FindMapping(Database::"Service Line", Database::"FS Work Order Product", IntegrationTableMapping) then begin
            ServiceLine.SetFilter("Item Type", '%1|%2', ServiceLine."Item Type"::Inventory, ServiceLine."Item Type"::"Non-Inventory");
            QueueServiceLines(Context, ServiceLine, IntegrationTableMapping.Name);
        end;
        if FSRecords.FindMapping(Database::"Service Line", Database::"FS Work Order Service", IntegrationTableMapping) then begin
            ServiceLine.SetRange("Item Type", ServiceLine."Item Type"::Service);
            QueueServiceLines(Context, ServiceLine, IntegrationTableMapping.Name);
        end;
    end;

    /// <summary>
    /// Finds service orders whose service item lines or service lines changed since a time, so they are sent to Field Service even when the header did not change.
    /// </summary>
    /// <param name="ModifiedSince">The time of the last synchronization.</param>
    /// <param name="ServiceHeaderIds">Receives the SystemIds of the service orders.</param>
    internal procedure FindOrdersWithChangedLines(ModifiedSince: DateTime; var ServiceHeaderIds: List of [Guid])
    var
        ServiceItemLine: Record "Service Item Line";
        ServiceLine: Record "Service Line";
        OrderNos: List of [Code[20]];
        OrderNo: Code[20];
    begin
        ServiceItemLine.SetRange("Document Type", ServiceItemLine."Document Type"::Order);
        if ModifiedSince <> 0DT then
            ServiceItemLine.SetFilter(SystemModifiedAt, '>%1', ModifiedSince);
        ServiceItemLine.SetLoadFields("Document No.");
        if ServiceItemLine.FindSet() then
            repeat
                if not OrderNos.Contains(ServiceItemLine."Document No.") then
                    OrderNos.Add(ServiceItemLine."Document No.");
            until ServiceItemLine.Next() = 0;
        ServiceLine.SetRange("Document Type", ServiceLine."Document Type"::Order);
        if ModifiedSince <> 0DT then
            ServiceLine.SetFilter(SystemModifiedAt, '>%1', ModifiedSince);
        ServiceLine.SetLoadFields("Document No.");
        if ServiceLine.FindSet() then
            repeat
                if not OrderNos.Contains(ServiceLine."Document No.") then
                    OrderNos.Add(ServiceLine."Document No.");
            until ServiceLine.Next() = 0;
        foreach OrderNo in OrderNos do
            AddOrderId(OrderNo, ServiceHeaderIds);
    end;

    /// <summary>
    /// Sets the service order, line number and description of a service item line created from a work order incident.
    /// </summary>
    /// <param name="FSWorkOrderIncidentRecordRef">The work order incident.</param>
    /// <param name="ServiceItemLineRecordRef">The new service item line.</param>
    internal procedure SetUpItemLine(var FSWorkOrderIncidentRecordRef: RecordRef; var ServiceItemLineRecordRef: RecordRef)
    var
        FSWorkOrderIncident: Record "FS Work Order Incident";
        FSIncidentType: Record "FS Incident Type";
        ServiceItemLine: Record "Service Item Line";
    begin
        FSWorkOrderIncidentRecordRef.SetTable(FSWorkOrderIncident);
        ServiceItemLineRecordRef.SetTable(ServiceItemLine);
        if ServiceItemLine."Document No." <> '' then
            exit;
        ServiceItemLine."Document Type" := ServiceItemLine."Document Type"::Order;
        ServiceItemLine."Document No." := OrderNoOfWorkOrder(FSWorkOrderIncident.WorkOrder);
        ServiceItemLine."Line No." := NextItemLineNo(ServiceItemLine."Document No.");
        if IsNullGuid(FSWorkOrderIncident.CustomerAsset) then
            if FSIncidentType.Get(FSWorkOrderIncident.IncidentType) then
                ServiceItemLine.Description := FSIncidentType.Name
            else
                ServiceItemLine.Description := DefaultIncidentTxt;
        ServiceItemLineRecordRef.GetTable(ServiceItemLine);
    end;

    /// <summary>
    /// Sets the service order, line number and type of a service line created from a work order product, service or booking.
    /// </summary>
    /// <param name="SourceRecordRef">The work order product, service or booking.</param>
    /// <param name="ServiceLineRecordRef">The new service line.</param>
    internal procedure SetUpLine(var SourceRecordRef: RecordRef; var ServiceLineRecordRef: RecordRef)
    var
        FSWorkOrderProduct: Record "FS Work Order Product";
        FSWorkOrderService: Record "FS Work Order Service";
        FSBookableResourceBooking: Record "FS Bookable Resource Booking";
        ServiceLine: Record "Service Line";
        WorkOrderId: Guid;
    begin
        ServiceLineRecordRef.SetTable(ServiceLine);
        if ServiceLine."Document No." <> '' then
            exit;
        case SourceRecordRef.Number() of
            Database::"FS Work Order Product":
                begin
                    SourceRecordRef.SetTable(FSWorkOrderProduct);
                    WorkOrderId := FSWorkOrderProduct.WorkOrder;
                    ServiceLine.Type := ServiceLine.Type::Item;
                end;
            Database::"FS Work Order Service":
                begin
                    SourceRecordRef.SetTable(FSWorkOrderService);
                    WorkOrderId := FSWorkOrderService.WorkOrder;
                    ServiceLine.Type := ServiceLine.Type::Item;
                end;
            Database::"FS Bookable Resource Booking":
                begin
                    SourceRecordRef.SetTable(FSBookableResourceBooking);
                    WorkOrderId := FSBookableResourceBooking.WorkOrder;
                    ServiceLine.Type := ServiceLine.Type::Resource;
                end;
        end;
        ServiceLine."Document Type" := ServiceLine."Document Type"::Order;
        ServiceLine."Document No." := OrderNoOfWorkOrder(WorkOrderId);
        ServiceLine."Line No." := NextLineNo(ServiceLine."Document No.");
        ServiceLineRecordRef.GetTable(ServiceLine);
    end;

    /// <summary>
    /// Assigns a service line created from a booking to the order's Field Service bookings service item line, creating that line when needed.
    /// </summary>
    /// <param name="ServiceLineRecordRef">The new service line.</param>
    internal procedure AssignBookingItemLine(var ServiceLineRecordRef: RecordRef)
    var
        ServiceLine: Record "Service Line";
        ServiceItemLine: Record "Service Item Line";
        Resource: Record Resource;
    begin
        ServiceLineRecordRef.SetTable(ServiceLine);
        ServiceItemLine.SetRange("Document Type", ServiceLine."Document Type");
        ServiceItemLine.SetRange("Document No.", ServiceLine."Document No.");
        ServiceItemLine.SetRange("FS Bookings", true);
        if not ServiceItemLine.FindFirst() then begin
            ServiceItemLine.Init();
            ServiceItemLine.Validate("Document Type", ServiceLine."Document Type");
            ServiceItemLine.Validate("Document No.", ServiceLine."Document No.");
            ServiceItemLine.Validate("Line No.", NextItemLineNo(ServiceLine."Document No."));
            ServiceItemLine.Validate(Description, CopyStr(Resource.TableCaption(), 1, MaxStrLen(ServiceItemLine.Description)));
            ServiceItemLine.Validate("FS Bookings", true);
            ServiceItemLine.Insert(true);
        end;
        ServiceLine.Validate("Service Item Line No.", ServiceItemLine."Line No.");
        ServiceLineRecordRef.GetTable(ServiceLine);
    end;

    /// <summary>
    /// Sets the work order and the default incident type of a work order incident created from a service item line.
    /// </summary>
    /// <param name="ServiceItemLineRecordRef">The service item line.</param>
    /// <param name="FSWorkOrderIncidentRecordRef">The new work order incident.</param>
    internal procedure SetUpIncident(var ServiceItemLineRecordRef: RecordRef; var FSWorkOrderIncidentRecordRef: RecordRef)
    var
        ServiceItemLine: Record "Service Item Line";
        FSWorkOrderIncident: Record "FS Work Order Incident";
    begin
        ServiceItemLineRecordRef.SetTable(ServiceItemLine);
        FSWorkOrderIncidentRecordRef.SetTable(FSWorkOrderIncident);
        FSWorkOrderIncident.WorkOrder := WorkOrderOfOrder(ServiceItemLine."Document No.");
        FSWorkOrderIncident.IncidentType := EnsureDefaultIncidentType();
        FSWorkOrderIncidentRecordRef.GetTable(FSWorkOrderIncident);
    end;

    /// <summary>
    /// Sets the work order of a work order product or service created from a service line.
    /// </summary>
    /// <param name="ServiceLineRecordRef">The service line.</param>
    /// <param name="DestinationRecordRef">The new work order product or service.</param>
    internal procedure SetWorkOrderOfLine(var ServiceLineRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    var
        ServiceLine: Record "Service Line";
        FSWorkOrderProduct: Record "FS Work Order Product";
        FSWorkOrderService: Record "FS Work Order Service";
    begin
        ServiceLineRecordRef.SetTable(ServiceLine);
        if DestinationRecordRef.Number() = Database::"FS Work Order Product" then begin
            DestinationRecordRef.SetTable(FSWorkOrderProduct);
            FSWorkOrderProduct.WorkOrder := WorkOrderOfOrder(ServiceLine."Document No.");
            DestinationRecordRef.GetTable(FSWorkOrderProduct);
            exit;
        end;
        DestinationRecordRef.SetTable(FSWorkOrderService);
        FSWorkOrderService.WorkOrder := WorkOrderOfOrder(ServiceLine."Document No.");
        DestinationRecordRef.GetTable(FSWorkOrderService);
    end;

    /// <summary>
    /// Sets the quantities of a service line from a work order product or service, or the estimate of the Field Service line from the service line: an estimated line has no quantities to ship, invoice or consume; a used line ships the larger of quantity and quantity to bill and invoices the quantity to bill.
    /// </summary>
    /// <param name="SourceRecordRef">The record being synchronized.</param>
    /// <param name="DestinationRecordRef">The destination record.</param>
    /// <param name="ToFieldService">True when the service line is the source.</param>
    internal procedure UpdateQuantities(var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef; ToFieldService: Boolean)
    var
        ServiceLine: Record "Service Line";
        FSWorkOrderProduct: Record "FS Work Order Product";
        FSWorkOrderService: Record "FS Work Order Service";
        FSBookableResourceBooking: Record "FS Bookable Resource Booking";
        FSValueConverter: Codeunit "DVI FS Value Converter";
        FSRecordRef: RecordRef;
        Estimated: Boolean;
        Quantity: Decimal;
        QuantityToBill: Decimal;
        Estimate: Decimal;
    begin
        if ToFieldService then begin
            SourceRecordRef.SetTable(ServiceLine);
            FSRecordRef := DestinationRecordRef;
        end else begin
            DestinationRecordRef.SetTable(ServiceLine);
            FSRecordRef := SourceRecordRef;
        end;
        case FSRecordRef.Number() of
            Database::"FS Bookable Resource Booking":
                begin
                    FSRecordRef.SetTable(FSBookableResourceBooking);
                    if ServiceLine."Qty. to Consume" <> 0 then
                        ServiceLine.Validate("Qty. to Consume", 0);
                    ServiceLine.Validate(Quantity, FSValueConverter.MinutesToHours(FSBookableResourceBooking.Duration));
                    ServiceLine.Validate("Qty. to Consume", ServiceLine.Quantity - ServiceLine."Quantity Consumed");
                    DestinationRecordRef.GetTable(ServiceLine);
                    exit;
                end;
            Database::"FS Work Order Product":
                begin
                    FSRecordRef.SetTable(FSWorkOrderProduct);
                    Estimated := FSWorkOrderProduct.LineStatus = FSWorkOrderProduct.LineStatus::Estimated;
                    Quantity := FSWorkOrderProduct.Quantity;
                    QuantityToBill := FSWorkOrderProduct.QtyToBill;
                    Estimate := FSWorkOrderProduct.EstimateQuantity;
                end;
            Database::"FS Work Order Service":
                begin
                    FSRecordRef.SetTable(FSWorkOrderService);
                    Estimated := FSWorkOrderService.LineStatus = FSWorkOrderService.LineStatus::Estimated;
                    Quantity := FSValueConverter.MinutesToHours(FSWorkOrderService.Duration);
                    QuantityToBill := FSValueConverter.MinutesToHours(FSWorkOrderService.DurationToBill);
                    Estimate := FSValueConverter.MinutesToHours(FSWorkOrderService.EstimateDuration);
                end;
            else
                exit;
        end;
        if Estimated then begin
            if ToFieldService then
                SetEstimate(FSRecordRef, ServiceLine.Quantity)
            else
                ServiceLine.Validate(Quantity, Estimate);
            ServiceLine.Validate("Qty. to Ship", 0);
            ServiceLine.Validate("Qty. to Invoice", 0);
            ServiceLine.Validate("Qty. to Consume", 0);
            if ToFieldService then
                ServiceLine.Modify(true);
        end else begin
            ServiceLine.Validate(Quantity, MaxOf(Quantity, QuantityToBill));
            ServiceLine.Validate("Qty. to Ship", MaxOf(Quantity, QuantityToBill) - ServiceLine."Quantity Shipped");
            ServiceLine.Validate("Qty. to Invoice", QuantityToBill - ServiceLine."Quantity Invoiced");
        end;
        if ToFieldService then begin
            SourceRecordRef.GetTable(ServiceLine);
            DestinationRecordRef := FSRecordRef;
        end else
            DestinationRecordRef.GetTable(ServiceLine);
    end;

    /// <summary>
    /// Writes the Business Central company to a new Field Service record.
    /// </summary>
    /// <param name="FSRecordRef">The new Field Service record.</param>
    internal procedure SetCompanyId(var FSRecordRef: RecordRef)
    var
        CDSCompany: Codeunit "DVI CDS Company";
    begin
        CDSCompany.SetCompanyId(FSRecordRef);
    end;

    /// <summary>
    /// Returns the larger of two quantities.
    /// </summary>
    /// <param name="Quantity1">The first quantity.</param>
    /// <param name="Quantity2">The second quantity.</param>
    /// <returns>The larger quantity.</returns>
    internal procedure MaxOf(Quantity1: Decimal; Quantity2: Decimal): Decimal
    begin
        if Quantity2 > Quantity1 then
            exit(Quantity2);
        exit(Quantity1);
    end;

    /// <summary>
    /// Opens the service order of a work order, or its archive when the order was deleted after archiving.
    /// </summary>
    /// <param name="WorkOrderId">The work order.</param>
    /// <returns>True when a page was opened.</returns>
    internal procedure OpenServiceOrder(WorkOrderId: Guid): Boolean
    var
        ServiceHeader: Record "Service Header";
        ServiceHeaderArchive: Record "Service Header Archive";
        CRMIntegrationRecord: Record "CRM Integration Record";
    begin
        CRMIntegrationRecord.SetRange("CRM ID", WorkOrderId);
        CRMIntegrationRecord.SetRange("Table ID", Database::"Service Header");
        if not CRMIntegrationRecord.FindFirst() then
            exit(false);
        if ServiceHeader.GetBySystemId(CRMIntegrationRecord."Integration ID") then begin
            Page.Run(Page::"Service Order", ServiceHeader);
            exit(true);
        end;
        if IsNullGuid(CRMIntegrationRecord."Archived Service Header Id") then
            exit(false);
        if not ServiceHeaderArchive.GetBySystemId(CRMIntegrationRecord."Archived Service Header Id") then
            exit(false);
        Page.Run(Page::"Service Order Archive", ServiceHeaderArchive);
        exit(true);
    end;

    local procedure IsArchivedWorkOrder(WorkOrderId: Guid): Boolean
    var
        CRMIntegrationRecord: Record "CRM Integration Record";
    begin
        if IsNullGuid(WorkOrderId) then
            exit(false);
        if not CRMIntegrationRecord.FindByCRMID(WorkOrderId) then
            exit(false);
        exit(CRMIntegrationRecord."Archived Service Order");
    end;

    local procedure RemoveDeletedItemLines(ServiceHeader: Record "Service Header")
    var
        ServiceItemLine: Record "Service Item Line";
        DeletedServiceItemLine: Record "Service Item Line";
        ServiceLine: Record "Service Line";
        FSWorkOrderIncident: Record "FS Work Order Incident";
        CRMIntegrationRecord: Record "CRM Integration Record";
    begin
        ServiceItemLine.SetRange("Document Type", ServiceItemLine."Document Type"::Order);
        ServiceItemLine.SetRange("Document No.", ServiceHeader."No.");
        if ServiceItemLine.FindSet() then
            repeat
                CRMIntegrationRecord.SetRange("Integration ID", ServiceItemLine.SystemId);
                CRMIntegrationRecord.SetRange("Table ID", Database::"Service Item Line");
                if CRMIntegrationRecord.FindFirst() then begin
                    FSWorkOrderIncident.SetRange(WorkOrderIncidentId, CRMIntegrationRecord."CRM ID");
                    if FSWorkOrderIncident.IsEmpty() then begin
                        CRMIntegrationRecord.Delete();
                        Archive(ServiceHeader);
                        if DeletedServiceItemLine.GetBySystemId(ServiceItemLine.SystemId) then begin
                            ServiceLine.SetRange("Document Type", ServiceItemLine."Document Type");
                            ServiceLine.SetRange("Document No.", ServiceItemLine."Document No.");
                            ServiceLine.SetRange("Service Item Line No.", ServiceItemLine."Line No.");
                            if not ServiceLine.IsEmpty() then
                                ServiceLine.DeleteAll(true);
                            DeletedServiceItemLine.Delete(true);
                        end;
                    end;
                end;
            until ServiceItemLine.Next() = 0;
    end;

    local procedure RemoveDeletedLines(ServiceHeader: Record "Service Header"; FSTableId: Integer)
    var
        ServiceLine: Record "Service Line";
        DeletedServiceLine: Record "Service Line";
        CRMIntegrationRecord: Record "CRM Integration Record";
    begin
        ServiceLine.SetRange("Document Type", ServiceLine."Document Type"::Order);
        ServiceLine.SetRange("Document No.", ServiceHeader."No.");
        case FSTableId of
            Database::"FS Work Order Product":
                begin
                    ServiceLine.SetRange(Type, ServiceLine.Type::Item);
                    ServiceLine.SetFilter("Item Type", '%1|%2', ServiceLine."Item Type"::Inventory, ServiceLine."Item Type"::"Non-Inventory");
                end;
            Database::"FS Work Order Service":
                begin
                    ServiceLine.SetRange(Type, ServiceLine.Type::Item);
                    ServiceLine.SetRange("Item Type", ServiceLine."Item Type"::Service);
                end;
            Database::"FS Bookable Resource Booking":
                ServiceLine.SetRange(Type, ServiceLine.Type::Resource);
        end;
        if ServiceLine.FindSet() then
            repeat
                CRMIntegrationRecord.SetRange("Integration ID", ServiceLine.SystemId);
                CRMIntegrationRecord.SetRange("Table ID", Database::"Service Line");
                if CRMIntegrationRecord.FindFirst() then
                    if not ExistsInFieldService(FSTableId, CRMIntegrationRecord."CRM ID") then begin
                        CRMIntegrationRecord.Delete();
                        Archive(ServiceHeader);
                        if DeletedServiceLine.GetBySystemId(ServiceLine.SystemId) then begin
                            if FSTableId = Database::"FS Bookable Resource Booking" then
                                DeleteBookingItemLine(DeletedServiceLine);
                            DeletedServiceLine.Delete(true);
                        end;
                    end;
            until ServiceLine.Next() = 0;
    end;

    local procedure ExistsInFieldService(FSTableId: Integer; Id: Guid): Boolean
    var
        FSRecordRef: RecordRef;
        IdFieldNo: Integer;
    begin
        FSRecordRef.Open(FSTableId);
        IdFieldNo := FSRecordRef.KeyIndex(1).FieldIndex(1).Number();
        FSRecordRef.Field(IdFieldNo).SetRange(Id);
        exit(not FSRecordRef.IsEmpty());
    end;

    local procedure DeleteBookingItemLine(ServiceLineToDelete: Record "Service Line")
    var
        ServiceItemLine: Record "Service Item Line";
        ServiceLine: Record "Service Line";
    begin
        ServiceLine.SetRange("Document Type", ServiceLineToDelete."Document Type");
        ServiceLine.SetRange("Document No.", ServiceLineToDelete."Document No.");
        ServiceLine.SetRange("Service Item Line No.", ServiceLineToDelete."Service Item Line No.");
        ServiceLine.SetFilter("Line No.", '<>%1', ServiceLineToDelete."Line No.");
        if not ServiceLine.IsEmpty() then
            exit;
        ServiceItemLine.SetRange("Document Type", ServiceLineToDelete."Document Type");
        ServiceItemLine.SetRange("Document No.", ServiceLineToDelete."Document No.");
        ServiceItemLine.SetRange("Line No.", ServiceLineToDelete."Service Item Line No.");
        if not ServiceItemLine.IsEmpty() then
            ServiceItemLine.DeleteAll();
    end;

    local procedure Archive(ServiceHeader: Record "Service Header")
    var
        ServiceMgtSetup: Record "Service Mgt. Setup";
        ServiceDocumentArchiveMgmt: Codeunit "Service Document Archive Mgmt.";
    begin
        if ArchivedOrders.Contains(ServiceHeader."No.") then
            exit;
        ServiceMgtSetup.SetLoadFields("Archive Orders");
        if not ServiceMgtSetup.Get() then
            exit;
        if not ServiceMgtSetup."Archive Orders" then
            exit;
        ArchivedOrders.Add(ServiceHeader."No.");
        ServiceDocumentArchiveMgmt.ArchServiceDocumentNoConfirm(ServiceHeader);
    end;

    local procedure QueueIncidents(var Context: Codeunit "DVI Sync Context"; FSWorkOrder: Record "FS Work Order")
    var
        FSWorkOrderIncident: Record "FS Work Order Incident";
        IntegrationTableMapping: Record "Integration Table Mapping";
        FSRecords: Codeunit "DVI FS Records";
    begin
        if not FSRecords.FindMapping(Database::"Service Item Line", Database::"FS Work Order Incident", IntegrationTableMapping) then
            exit;
        FSWorkOrderIncident.SetRange(WorkOrder, FSWorkOrder.WorkOrderId);
        if FSWorkOrderIncident.FindSet() then
            repeat
                if not SkipReimport(FSWorkOrderIncident.WorkOrderIncidentId, FSWorkOrderIncident.ModifiedOn) then
                    Context.AddFollowUp(IntegrationTableMapping.Name, FSWorkOrderIncident.WorkOrderIncidentId, false);
            until FSWorkOrderIncident.Next() = 0;
    end;

    local procedure QueueProducts(var Context: Codeunit "DVI Sync Context"; FSWorkOrder: Record "FS Work Order")
    var
        FSWorkOrderProduct: Record "FS Work Order Product";
        IntegrationTableMapping: Record "Integration Table Mapping";
        FSRecords: Codeunit "DVI FS Records";
    begin
        if not FSRecords.FindMapping(Database::"Service Line", Database::"FS Work Order Product", IntegrationTableMapping) then
            exit;
        FSWorkOrderProduct.SetRange(WorkOrder, FSWorkOrder.WorkOrderId);
        if FSWorkOrderProduct.FindSet() then
            repeat
                if not SkipReimport(FSWorkOrderProduct.WorkOrderProductId, FSWorkOrderProduct.ModifiedOn) then
                    Context.AddFollowUp(IntegrationTableMapping.Name, FSWorkOrderProduct.WorkOrderProductId, false);
            until FSWorkOrderProduct.Next() = 0;
    end;

    local procedure QueueServices(var Context: Codeunit "DVI Sync Context"; FSWorkOrder: Record "FS Work Order")
    var
        FSWorkOrderService: Record "FS Work Order Service";
        IntegrationTableMapping: Record "Integration Table Mapping";
        FSRecords: Codeunit "DVI FS Records";
    begin
        if not FSRecords.FindMapping(Database::"Service Line", Database::"FS Work Order Service", IntegrationTableMapping) then
            exit;
        FSWorkOrderService.SetRange(WorkOrder, FSWorkOrder.WorkOrderId);
        if FSWorkOrderService.FindSet() then
            repeat
                if not SkipReimport(FSWorkOrderService.WorkOrderServiceId, FSWorkOrderService.ModifiedOn) then
                    Context.AddFollowUp(IntegrationTableMapping.Name, FSWorkOrderService.WorkOrderServiceId, false);
            until FSWorkOrderService.Next() = 0;
    end;

    local procedure QueueBookings(var Context: Codeunit "DVI Sync Context"; FSWorkOrder: Record "FS Work Order")
    var
        FSBookableResourceBooking: Record "FS Bookable Resource Booking";
        IntegrationTableMapping: Record "Integration Table Mapping";
        FSRecords: Codeunit "DVI FS Records";
        CompletedStatusId: Guid;
    begin
        if not FSRecords.FindMapping(Database::"Service Line", Database::"FS Bookable Resource Booking", IntegrationTableMapping) then
            exit;
        CompletedStatusId := CompletedBookingStatus();
        if IsNullGuid(CompletedStatusId) then
            exit;
        FSBookableResourceBooking.SetRange(WorkOrder, FSWorkOrder.WorkOrderId);
        FSBookableResourceBooking.SetRange(BookingStatus, CompletedStatusId);
        if FSBookableResourceBooking.FindSet() then
            repeat
                if not SkipReimport(FSBookableResourceBooking.BookableResourceBookingId, FSBookableResourceBooking.ModifiedOn) then
                    Context.AddFollowUp(IntegrationTableMapping.Name, FSBookableResourceBooking.BookableResourceBookingId, false);
            until FSBookableResourceBooking.Next() = 0;
    end;

    local procedure QueueServiceLines(var Context: Codeunit "DVI Sync Context"; var ServiceLine: Record "Service Line"; MappingName: Code[20])
    begin
        ServiceLine.SetLoadFields(SystemId);
        if ServiceLine.FindSet() then
            repeat
                Context.AddFollowUp(MappingName, ServiceLine.SystemId, true);
            until ServiceLine.Next() = 0;
    end;

    local procedure SkipReimport(Id: Guid; ModifiedOn: DateTime): Boolean
    var
        CRMIntegrationRecord: Record "CRM Integration Record";
    begin
        CRMIntegrationRecord.SetRange("CRM ID", Id);
        if not CRMIntegrationRecord.FindFirst() then
            exit(false);
        if not CRMIntegrationRecord."Skip Reimport" then
            exit(false);
        if CRMIntegrationRecord."Last Synch. Modified On" > ModifiedOn then
            exit(true);
        CRMIntegrationRecord.Delete();
        exit(false);
    end;

    local procedure CompletedBookingStatus(): Guid
    var
        FSBookingStatus: Record "FS Booking Status";
    begin
        FSBookingStatus.SetRange(FieldServiceStatus, FSBookingStatus.FieldServiceStatus::Completed);
        if FSBookingStatus.FindFirst() then
            exit(FSBookingStatus.BookingStatusId);
    end;

    /// <summary>
    /// Returns the default incident type of new work order incidents, creating it in Field Service when the setup has none.
    /// </summary>
    /// <returns>The incident type ID.</returns>
    internal procedure EnsureDefaultIncidentType(): Guid
    var
        FSConnectionSetup: Record "FS Connection Setup";
        FSIncidentType: Record "FS Incident Type";
    begin
        FSConnectionSetup.Get();
        if not IsNullGuid(FSConnectionSetup."Default Work Order Incident ID") then
            exit(FSConnectionSetup."Default Work Order Incident ID");
        FSIncidentType.IncidentTypeId := CreateGuid();
        FSIncidentType.Name := DefaultIncidentTypeTxt;
        FSIncidentType.Insert();
        FSConnectionSetup."Default Work Order Incident ID" := FSIncidentType.IncidentTypeId;
        FSConnectionSetup.Modify();
        exit(FSIncidentType.IncidentTypeId);
    end;

    local procedure SetEstimate(var FSRecordRef: RecordRef; Quantity: Decimal)
    var
        FSWorkOrderProduct: Record "FS Work Order Product";
        FSWorkOrderService: Record "FS Work Order Service";
        FSValueConverter: Codeunit "DVI FS Value Converter";
    begin
        if FSRecordRef.Number() = Database::"FS Work Order Product" then begin
            FSRecordRef.SetTable(FSWorkOrderProduct);
            FSWorkOrderProduct.EstimateQuantity := Quantity;
            FSRecordRef.GetTable(FSWorkOrderProduct);
            exit;
        end;
        FSRecordRef.SetTable(FSWorkOrderService);
        FSWorkOrderService.EstimateDuration := FSValueConverter.HoursToMinutes(Quantity);
        FSRecordRef.GetTable(FSWorkOrderService);
    end;

    local procedure OrderNoOfWorkOrder(WorkOrderId: Guid): Code[20]
    var
        ServiceHeader: Record "Service Header";
        CRMIntegrationRecord: Record "CRM Integration Record";
        ServiceHeaderRecordId: RecordId;
    begin
        if not CRMIntegrationRecord.FindRecordIDFromID(WorkOrderId, Database::"Service Header", ServiceHeaderRecordId) then
            exit('');
        if ServiceHeader.Get(ServiceHeaderRecordId) then
            exit(ServiceHeader."No.");
        exit('');
    end;

    local procedure WorkOrderOfOrder(DocumentNo: Code[20]) WorkOrderId: Guid
    var
        ServiceHeader: Record "Service Header";
        CRMIntegrationRecord: Record "CRM Integration Record";
    begin
        if ServiceHeader.Get(ServiceHeader."Document Type"::Order, DocumentNo) then
            if CRMIntegrationRecord.FindIDFromRecordID(ServiceHeader.RecordId(), WorkOrderId) then;
    end;

    local procedure AddOrderId(OrderNo: Code[20]; var ServiceHeaderIds: List of [Guid])
    var
        ServiceHeader: Record "Service Header";
    begin
        ServiceHeader.SetLoadFields(SystemId);
        if ServiceHeader.Get(ServiceHeader."Document Type"::Order, OrderNo) then
            ServiceHeaderIds.Add(ServiceHeader.SystemId);
    end;

    local procedure NextItemLineNo(DocumentNo: Code[20]): Integer
    var
        ServiceItemLine: Record "Service Item Line";
    begin
        ServiceItemLine.SetRange("Document Type", ServiceItemLine."Document Type"::Order);
        ServiceItemLine.SetRange("Document No.", DocumentNo);
        if ServiceItemLine.FindLast() then
            exit(ServiceItemLine."Line No." + 10000);
        exit(10000);
    end;

    local procedure NextLineNo(DocumentNo: Code[20]): Integer
    var
        ServiceLine: Record "Service Line";
    begin
        ServiceLine.SetRange("Document Type", ServiceLine."Document Type"::Order);
        ServiceLine.SetRange("Document No.", DocumentNo);
        if ServiceLine.FindLast() then
            exit(ServiceLine."Line No." + 10000);
        exit(10000);
    end;
}
