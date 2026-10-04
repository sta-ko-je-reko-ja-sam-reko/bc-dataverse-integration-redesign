namespace DataverseIntegration.FieldService;

using DataverseIntegration.CDS;
using DataverseIntegration.Core;
using Microsoft.Integration.DynamicsFieldService;
using Microsoft.Integration.SyncEngine;
using Microsoft.Service.Document;

codeunit 80816 "DVI Work Order Handler" implements "DVI IRecordSync", "DVI IRecordCoupling", "DVI IRecordFilter", "DVI IHandlerScope", "DVI IChangeDetection", "DVI ILocalRecordView"
{
    Access = Public;

    procedure Serves(var Context: Codeunit "DVI Sync Context"): Boolean
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
    begin
        Context.GetMapping(IntegrationTableMapping);
        exit((IntegrationTableMapping."Table ID" = Database::"Service Header") and (IntegrationTableMapping."Integration Table ID" = Database::"FS Work Order"));
    end;

    procedure DefaultModule(var Context: Codeunit "DVI Sync Context"): Enum "DVI Integration Module"
    begin
        exit(Enum::"DVI Integration Module"::DVIFieldService);
    end;

    procedure IgnoreRecord(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef): Boolean
    var
        FSServiceOrders: Codeunit "DVI FS Service Orders";
    begin
        exit(FSServiceOrders.IgnoreOrder(SourceRecordRef));
    end;

    procedure FindIndirectlyChanged(var Context: Codeunit "DVI Sync Context"; ModifiedSince: DateTime; var LocalSystemIds: List of [Guid])
    var
        FSServiceOrders: Codeunit "DVI FS Service Orders";
    begin
        FSServiceOrders.FindOrdersWithChangedLines(ModifiedSince, LocalSystemIds);
    end;

    procedure OpenLocalRecord(IntegrationTableMapping: Record "Integration Table Mapping"; IntegrationId: Guid): Boolean
    var
        FSServiceOrders: Codeunit "DVI FS Service Orders";
    begin
        exit(FSServiceOrders.OpenServiceOrder(IntegrationId));
    end;

    procedure BeforeTransferFields(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    begin
    end;

    procedure AfterTransferFields(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef; var AdditionalFieldsModified: Boolean)
    begin
        AdditionalFieldsModified := false;
    end;

    procedure BeforeInsert(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    begin
        PrepareWorkOrder(Context, SourceRecordRef, DestinationRecordRef);
    end;

    procedure AfterInsert(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    var
        FSServiceOrders: Codeunit "DVI FS Service Orders";
    begin
        if not Context.IsToIntegrationTable() then
            FSServiceOrders.ValidateCustomer(DestinationRecordRef);
        QueueLines(Context, SourceRecordRef, DestinationRecordRef);
    end;

    procedure BeforeModify(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    begin
        PrepareWorkOrder(Context, SourceRecordRef, DestinationRecordRef);
    end;

    procedure AfterModify(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    begin
        QueueLines(Context, SourceRecordRef, DestinationRecordRef);
    end;

    procedure Unchanged(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    begin
        QueueLines(Context, SourceRecordRef, DestinationRecordRef);
    end;

    procedure FindUncoupledDestination(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef; var DestinationIsDeleted: Boolean): Boolean
    begin
        DestinationIsDeleted := false;
        exit(false);
    end;

    procedure AfterCouple(var Context: Codeunit "DVI Sync Context"; var LocalRecordRef: RecordRef; var IntegrationRecordRef: RecordRef)
    var
        FSServiceOrders: Codeunit "DVI FS Service Orders";
        FSRecords: Codeunit "DVI FS Records";
    begin
        if LocalRecordRef.Number() <> Database::"Service Header" then
            exit;
        FSServiceOrders.CheckLinesAssigned(LocalRecordRef);
        FSRecords.StampCompanyOnSource(IntegrationRecordRef);
    end;

    procedure BeforeUncouple(var Context: Codeunit "DVI Sync Context"; var LocalRecordRef: RecordRef; var IntegrationRecordRef: RecordRef)
    var
        CDSCompany: Codeunit "DVI CDS Company";
    begin
        CDSCompany.ResetCompanyId(IntegrationRecordRef);
    end;

    procedure AfterUncouple(var Context: Codeunit "DVI Sync Context"; var LocalRecordRef: RecordRef; var IntegrationRecordRef: RecordRef)
    begin
    end;

    procedure SetMatchingFilter(var Context: Codeunit "DVI Sync Context"; var IntegrationRecordRef: RecordRef; var MatchingIntegrationFieldRef: FieldRef; var LocalRecordRef: RecordRef; var MatchingLocalFieldRef: FieldRef): Boolean
    begin
        exit(false);
    end;

    procedure CreateNewOnNoMatch(var Context: Codeunit "DVI Sync Context"): Boolean
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
    begin
        Context.GetMapping(IntegrationTableMapping);
        exit(IntegrationTableMapping."Create New in Case of No Match");
    end;

    local procedure PrepareWorkOrder(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    var
        FSServiceOrders: Codeunit "DVI FS Service Orders";
    begin
        if not Context.IsToIntegrationTable() then
            exit;
        FSServiceOrders.CheckLinesAssigned(SourceRecordRef);
        FSServiceOrders.SetCompanyId(DestinationRecordRef);
    end;

    local procedure QueueLines(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    var
        FSServiceOrders: Codeunit "DVI FS Service Orders";
    begin
        if Context.IsToIntegrationTable() then
            FSServiceOrders.QueueLinesToFieldService(Context, SourceRecordRef)
        else
            FSServiceOrders.QueueLinesFromFieldService(Context, SourceRecordRef, DestinationRecordRef);
    end;
}
