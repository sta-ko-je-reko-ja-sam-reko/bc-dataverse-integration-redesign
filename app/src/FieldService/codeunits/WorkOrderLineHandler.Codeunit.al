namespace DataverseIntegration.FieldService;

using DataverseIntegration.CDS;
using DataverseIntegration.Core;
using Microsoft.Integration.DynamicsFieldService;
using Microsoft.Integration.SyncEngine;
using Microsoft.Service.Document;

codeunit 80818 "DVI Work Order Line Handler" implements "DVI IRecordSync", "DVI IRecordCoupling", "DVI IRecordFilter", "DVI IHandlerScope"
{
    Access = Public;

    procedure Serves(var Context: Codeunit "DVI Sync Context"): Boolean
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
    begin
        Context.GetMapping(IntegrationTableMapping);
        exit((IntegrationTableMapping."Table ID" = Database::"Service Line") and
          (IntegrationTableMapping."Integration Table ID" in [Database::"FS Work Order Product", Database::"FS Work Order Service", Database::"FS Bookable Resource Booking"]));
    end;

    procedure DefaultModule(var Context: Codeunit "DVI Sync Context"): Enum "DVI Integration Module"
    begin
        exit(Enum::"DVI Integration Module"::DVIFieldService);
    end;

    procedure IgnoreRecord(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef): Boolean
    var
        FSServiceOrders: Codeunit "DVI FS Service Orders";
    begin
        exit(FSServiceOrders.IgnoreLine(SourceRecordRef));
    end;

    procedure BeforeTransferFields(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    var
        FSServiceOrders: Codeunit "DVI FS Service Orders";
    begin
        if not Context.IsToIntegrationTable() then
            FSServiceOrders.SetUpLine(SourceRecordRef, DestinationRecordRef);
    end;

    procedure AfterTransferFields(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef; var AdditionalFieldsModified: Boolean)
    var
        FSServiceOrders: Codeunit "DVI FS Service Orders";
    begin
        if Context.IsToIntegrationTable() and (DestinationRecordRef.Number() = Database::"FS Bookable Resource Booking") then begin
            AdditionalFieldsModified := false;
            exit;
        end;
        FSServiceOrders.UpdateQuantities(SourceRecordRef, DestinationRecordRef, Context.IsToIntegrationTable());
        AdditionalFieldsModified := true;
    end;

    procedure BeforeInsert(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    var
        FSServiceOrders: Codeunit "DVI FS Service Orders";
    begin
        if not Context.IsToIntegrationTable() then begin
            if SourceRecordRef.Number() = Database::"FS Bookable Resource Booking" then
                FSServiceOrders.AssignBookingItemLine(DestinationRecordRef);
            exit;
        end;
        if DestinationRecordRef.Number() in [Database::"FS Work Order Product", Database::"FS Work Order Service"] then begin
            FSServiceOrders.SetCompanyId(DestinationRecordRef);
            FSServiceOrders.SetWorkOrderOfLine(SourceRecordRef, DestinationRecordRef);
        end;
    end;

    procedure AfterInsert(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    begin
    end;

    procedure BeforeModify(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    begin
    end;

    procedure AfterModify(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    begin
    end;

    procedure Unchanged(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    begin
    end;

    procedure FindUncoupledDestination(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef; var DestinationIsDeleted: Boolean): Boolean
    begin
        DestinationIsDeleted := false;
        exit(false);
    end;

    procedure AfterCouple(var Context: Codeunit "DVI Sync Context"; var LocalRecordRef: RecordRef; var IntegrationRecordRef: RecordRef)
    begin
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
}
