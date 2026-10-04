namespace DataverseIntegration.FieldService;

using DataverseIntegration.Core;
using Microsoft.Integration.D365Sales;
using Microsoft.Integration.Dataverse;
using Microsoft.Integration.DynamicsFieldService;
using Microsoft.Inventory.Item;
using Microsoft.Projects.Project.Journal;
using Microsoft.Service.Document;

codeunit 80832 "DVI FS Value Converter" implements "DVI IValueConverter"
{
    Access = Public;

    var
        UnitNotCoupledErr: Label 'The Field Service unit %1 is not coupled to an item unit of measure.', Comment = '%1 = unit ID';
        ItemUnitNotCoupledErr: Label 'The item unit of measure %1 %2 is not coupled to a Field Service unit.', Comment = '%1 = item number, %2 = unit of measure code';

    procedure AppliesTo(var Context: Codeunit "DVI Sync Context"; var SourceFieldRef: FieldRef; var DestinationFieldRef: FieldRef): Boolean
    begin
        exit(Rule(SourceFieldRef, DestinationFieldRef) <> 0);
    end;

    procedure Convert(var Context: Codeunit "DVI Sync Context"; var SourceFieldRef: FieldRef; var DestinationFieldRef: FieldRef; var NewValue: Variant; var NeedsConversion: Boolean): Boolean
    var
        FSProjects: Codeunit "DVI FS Projects";
        SourceRecordRef: RecordRef;
        DestinationRecordRef: RecordRef;
        Consumed: Decimal;
        Invoiced: Decimal;
    begin
        NeedsConversion := false;
        SourceRecordRef := SourceFieldRef.Record();
        DestinationRecordRef := DestinationFieldRef.Record();
        case Rule(SourceFieldRef, DestinationFieldRef) of
            1:
                NewValue := DestinationFieldRef.Value();
            2:
                NewValue := ServiceStatusOf(SourceRecordRef, DestinationFieldRef);
            3:
                NewValue := HoursToMinutes(SourceFieldRef.Value());
            4:
                NewValue := DateOf(SourceFieldRef.Value());
            5:
                NewValue := MinutesToHours(SourceFieldRef.Value());
            6:
                begin
                    FSProjects.PlanningQuantities(SourceRecordRef, Consumed, Invoiced);
                    NewValue := MinutesToHours(SourceFieldRef.Value()) - Consumed;
                end;
            7:
                begin
                    FSProjects.PlanningQuantities(SourceRecordRef, Consumed, Invoiced);
                    if IsBudgetOrBlankJournalLine(DestinationRecordRef) then
                        NewValue := 0
                    else
                        NewValue := MinutesToHours(SourceFieldRef.Value()) - Invoiced;
                end;
            8:
                if not DescriptionOfWorkOrderService(SourceRecordRef, DestinationRecordRef, NewValue) then
                    exit(false);
            9:
                begin
                    FSProjects.PlanningQuantities(SourceRecordRef, Consumed, Invoiced);
                    NewValue := DecimalOf(SourceFieldRef.Value()) - Consumed;
                end;
            10:
                begin
                    FSProjects.PlanningQuantities(SourceRecordRef, Consumed, Invoiced);
                    NewValue := DecimalOf(SourceFieldRef.Value()) - Invoiced;
                end;
            11:
                NewValue := NameOfWorkOrderProduct(SourceRecordRef);
            12:
                NewValue := ItemUnitOf(SourceFieldRef.Value());
            13:
                if not ServiceItemLineNoOf(SourceFieldRef.Value(), NewValue) then
                    exit(false);
            14:
                if not IncidentOf(SourceRecordRef, NewValue) then
                    exit(false);
            15:
                NewValue := FSUnitOf(SourceRecordRef);
            else
                exit(false);
        end;
        exit(true);
    end;

    /// <summary>
    /// Returns the rule that converts a field pair, or 0 when this converter does not apply.
    /// </summary>
    /// <param name="SourceFieldRef">The source field.</param>
    /// <param name="DestinationFieldRef">The destination field.</param>
    /// <returns>The rule number.</returns>
    procedure Rule(var SourceFieldRef: FieldRef; var DestinationFieldRef: FieldRef): Integer
    var
        FSWorkOrder: Record "FS Work Order";
        FSWorkOrderProduct: Record "FS Work Order Product";
        FSWorkOrderService: Record "FS Work Order Service";
        ServiceHeader: Record "Service Header";
        ServiceLine: Record "Service Line";
        SourceTableId: Integer;
        DestinationTableId: Integer;
    begin
        SourceTableId := SourceFieldRef.Record().Number();
        DestinationTableId := DestinationFieldRef.Record().Number();
        case true of
            (SourceTableId = Database::"Service Header") and (DestinationTableId = Database::"FS Work Order") and (DestinationFieldRef.Number() = FSWorkOrder.FieldNo(SystemStatus)):
                exit(1);
            (SourceTableId = Database::"FS Work Order") and (DestinationTableId = Database::"Service Header") and (DestinationFieldRef.Number() = ServiceHeader.FieldNo(Status)):
                exit(2);
            (SourceTableId = Database::"Service Line") and (DestinationTableId = Database::"FS Work Order Service") and
            (DestinationFieldRef.Number() in [FSWorkOrderService.FieldNo(DurationShipped), FSWorkOrderService.FieldNo(DurationInvoiced), FSWorkOrderService.FieldNo(DurationConsumed)]):
                exit(3);
            (SourceTableId = Database::"FS Work Order") and (SourceFieldRef.Number() = FSWorkOrder.FieldNo(CreatedOn)) and (DestinationFieldRef.Type() = FieldType::Date):
                exit(4);
            (SourceTableId = Database::"FS Work Order Service") and (SourceFieldRef.Number() = FSWorkOrderService.FieldNo(EstimateDuration)):
                exit(5);
            (SourceTableId = Database::"FS Work Order Service") and (SourceFieldRef.Number() = FSWorkOrderService.FieldNo(Duration)) and (DestinationTableId = Database::"Job Journal Line"):
                exit(6);
            (SourceTableId = Database::"FS Work Order Service") and (SourceFieldRef.Number() = FSWorkOrderService.FieldNo(Duration)):
                exit(5);
            (SourceTableId = Database::"FS Work Order Service") and (SourceFieldRef.Number() = FSWorkOrderService.FieldNo(DurationToBill)) and (DestinationTableId = Database::"Job Journal Line"):
                exit(7);
            (SourceTableId = Database::"FS Work Order Service") and (SourceFieldRef.Number() = FSWorkOrderService.FieldNo(DurationToBill)):
                exit(5);
            (SourceTableId = Database::"FS Work Order Service") and (SourceFieldRef.Number() = FSWorkOrderService.FieldNo(Description)) and (DestinationTableId = Database::"Job Journal Line"):
                exit(8);
            (SourceTableId = Database::"FS Work Order Product") and (SourceFieldRef.Number() = FSWorkOrderProduct.FieldNo(Quantity)) and (DestinationTableId = Database::"Job Journal Line"):
                exit(9);
            (SourceTableId = Database::"FS Work Order Product") and (SourceFieldRef.Number() = FSWorkOrderProduct.FieldNo(QtyToBill)) and (DestinationTableId = Database::"Job Journal Line"):
                exit(10);
            (SourceTableId = Database::"FS Work Order Product") and (SourceFieldRef.Number() = FSWorkOrderProduct.FieldNo(Description)):
                exit(11);
            (SourceTableId = Database::"FS Work Order Product") and (SourceFieldRef.Number() = FSWorkOrderProduct.FieldNo(Unit)),
            (SourceTableId = Database::"FS Work Order Service") and (SourceFieldRef.Number() = FSWorkOrderService.FieldNo(Unit)):
                exit(12);
            (SourceTableId in [Database::"FS Work Order Product", Database::"FS Work Order Service"]) and (DestinationTableId = Database::"Service Line") and
            (SourceFieldRef.Number() in [FSWorkOrderProduct.FieldNo(WorkOrderIncident), FSWorkOrderService.FieldNo(WorkOrderIncident)]) and IsWorkOrderIncidentField(SourceTableId, SourceFieldRef.Number()):
                exit(13);
            (SourceTableId = Database::"Service Line") and (DestinationTableId in [Database::"FS Work Order Product", Database::"FS Work Order Service"]) and (SourceFieldRef.Number() = ServiceLine.FieldNo("Service Item Line No.")):
                exit(14);
            (SourceTableId = Database::"Service Line") and (DestinationTableId in [Database::"FS Work Order Product", Database::"FS Work Order Service"]) and (SourceFieldRef.Number() = ServiceLine.FieldNo("Unit of Measure Code")):
                exit(15);
        end;
        exit(0);
    end;

    /// <summary>
    /// Converts a duration in hours, as Business Central stores it, to minutes, as Field Service stores it.
    /// </summary>
    /// <param name="Hours">The duration in hours.</param>
    /// <returns>The duration in minutes.</returns>
    procedure HoursToMinutes(Hours: Decimal): Decimal
    begin
        exit(Hours * 60);
    end;

    /// <summary>
    /// Converts a duration in minutes, as Field Service stores it, to hours.
    /// </summary>
    /// <param name="Minutes">The duration in minutes.</param>
    /// <returns>The duration in hours.</returns>
    procedure MinutesToHours(Minutes: Decimal): Decimal
    begin
        exit(Minutes / 60);
    end;

    /// <summary>
    /// Returns the service order status for a work order system status: Pending for unscheduled and scheduled, In Process, Finished for completed; other statuses keep the current status.
    /// </summary>
    /// <param name="SystemStatus">The work order system status.</param>
    /// <param name="CurrentStatus">The current status of the service order.</param>
    /// <returns>The new status.</returns>
    procedure ServiceStatusFor(SystemStatus: Integer; CurrentStatus: Enum "Service Document Status"): Enum "Service Document Status"
    var
        FSWorkOrder: Record "FS Work Order";
    begin
        case SystemStatus of
            FSWorkOrder.SystemStatus::Unscheduled, FSWorkOrder.SystemStatus::Scheduled:
                exit(Enum::"Service Document Status"::Pending);
            FSWorkOrder.SystemStatus::InProgress:
                exit(Enum::"Service Document Status"::"In Process");
            FSWorkOrder.SystemStatus::Completed:
                exit(Enum::"Service Document Status"::Finished);
        end;
        exit(CurrentStatus);
    end;

    local procedure ServiceStatusOf(var FSWorkOrderRecordRef: RecordRef; var StatusFieldRef: FieldRef): Enum "Service Document Status"
    var
        FSWorkOrder: Record "FS Work Order";
        CurrentStatus: Enum "Service Document Status";
    begin
        FSWorkOrderRecordRef.SetTable(FSWorkOrder);
        CurrentStatus := StatusFieldRef.Value();
        exit(ServiceStatusFor(FSWorkOrder.SystemStatus, CurrentStatus));
    end;

    local procedure DateOf(Value: DateTime): Date
    begin
        exit(DT2Date(Value));
    end;

    local procedure DecimalOf(Value: Decimal): Decimal
    begin
        exit(Value);
    end;

    local procedure IsBudgetOrBlankJournalLine(var JobJournalLineRecordRef: RecordRef): Boolean
    var
        JobJournalLine: Record "Job Journal Line";
    begin
        JobJournalLineRecordRef.SetTable(JobJournalLine);
        exit(JobJournalLine."Line Type" in [JobJournalLine."Line Type"::Budget, JobJournalLine."Line Type"::" "]);
    end;

    local procedure DescriptionOfWorkOrderService(var FSWorkOrderServiceRecordRef: RecordRef; var JobJournalLineRecordRef: RecordRef; var NewValue: Variant): Boolean
    var
        FSWorkOrderService: Record "FS Work Order Service";
        FSBookableResourceBooking: Record "FS Bookable Resource Booking";
        JobJournalLine: Record "Job Journal Line";
    begin
        FSWorkOrderServiceRecordRef.SetTable(FSWorkOrderService);
        JobJournalLineRecordRef.SetTable(JobJournalLine);
        case JobJournalLine.Type of
            JobJournalLine.Type::Resource:
                if FSBookableResourceBooking.Get(FSWorkOrderService.Booking) then begin
                    NewValue := FSBookableResourceBooking.Name;
                    exit(true);
                end;
            JobJournalLine.Type::Item:
                begin
                    NewValue := FSWorkOrderService.Name;
                    exit(true);
                end;
        end;
        exit(false);
    end;

    local procedure NameOfWorkOrderProduct(var FSWorkOrderProductRecordRef: RecordRef): Text
    var
        FSWorkOrderProduct: Record "FS Work Order Product";
    begin
        FSWorkOrderProductRecordRef.SetTable(FSWorkOrderProduct);
        exit(FSWorkOrderProduct.Name);
    end;

    local procedure ItemUnitOf(UnitId: Guid): Code[10]
    var
        ItemUnitOfMeasure: Record "Item Unit of Measure";
        CRMIntegrationRecord: Record "CRM Integration Record";
        UnitRecordId: RecordId;
    begin
        if IsNullGuid(UnitId) then
            exit('');
        if not CRMIntegrationRecord.FindRecordIDFromID(UnitId, Database::"Item Unit of Measure", UnitRecordId) then
            Error(UnitNotCoupledErr, UnitId);
        if not ItemUnitOfMeasure.Get(UnitRecordId) then
            Error(UnitNotCoupledErr, UnitId);
        exit(ItemUnitOfMeasure.Code);
    end;

    local procedure ServiceItemLineNoOf(WorkOrderIncidentId: Guid; var NewValue: Variant): Boolean
    var
        ServiceItemLine: Record "Service Item Line";
        CRMIntegrationRecord: Record "CRM Integration Record";
        ServiceItemLineRecordId: RecordId;
    begin
        if IsNullGuid(WorkOrderIncidentId) then
            exit(false);
        if not CRMIntegrationRecord.FindRecordIDFromID(WorkOrderIncidentId, Database::"Service Item Line", ServiceItemLineRecordId) then
            exit(false);
        if not ServiceItemLine.Get(ServiceItemLineRecordId) then
            exit(false);
        NewValue := ServiceItemLine."Line No.";
        exit(true);
    end;

    local procedure IncidentOf(var ServiceLineRecordRef: RecordRef; var NewValue: Variant): Boolean
    var
        ServiceLine: Record "Service Line";
        ServiceItemLine: Record "Service Item Line";
        CRMIntegrationRecord: Record "CRM Integration Record";
        WorkOrderIncidentId: Guid;
    begin
        ServiceLineRecordRef.SetTable(ServiceLine);
        if not ServiceItemLine.Get(ServiceLine."Document Type", ServiceLine."Document No.", ServiceLine."Service Item Line No.") then
            exit(false);
        if not CRMIntegrationRecord.FindIDFromRecordID(ServiceItemLine.RecordId(), WorkOrderIncidentId) then
            exit(false);
        NewValue := WorkOrderIncidentId;
        exit(true);
    end;

    local procedure FSUnitOf(var ServiceLineRecordRef: RecordRef): Guid
    var
        ServiceLine: Record "Service Line";
        ItemUnitOfMeasure: Record "Item Unit of Measure";
        CRMIntegrationRecord: Record "CRM Integration Record";
        CRMUom: Record "CRM Uom";
        UnitId: Guid;
    begin
        ServiceLineRecordRef.SetTable(ServiceLine);
        if not ItemUnitOfMeasure.Get(ServiceLine."No.", ServiceLine."Unit of Measure Code") then
            Error(ItemUnitNotCoupledErr, ServiceLine."No.", ServiceLine."Unit of Measure Code");
        if not CRMIntegrationRecord.FindIDFromRecordID(ItemUnitOfMeasure.RecordId(), UnitId) then
            Error(ItemUnitNotCoupledErr, ServiceLine."No.", ServiceLine."Unit of Measure Code");
        if not CRMUom.Get(UnitId) then
            Error(ItemUnitNotCoupledErr, ServiceLine."No.", ServiceLine."Unit of Measure Code");
        exit(CRMUom.UoMId);
    end;

    local procedure IsWorkOrderIncidentField(TableId: Integer; FieldNo: Integer): Boolean
    var
        FSWorkOrderProduct: Record "FS Work Order Product";
        FSWorkOrderService: Record "FS Work Order Service";
    begin
        if TableId = Database::"FS Work Order Product" then
            exit(FieldNo = FSWorkOrderProduct.FieldNo(WorkOrderIncident));
        exit(FieldNo = FSWorkOrderService.FieldNo(WorkOrderIncident));
    end;
}
