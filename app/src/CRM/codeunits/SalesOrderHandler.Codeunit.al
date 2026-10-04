namespace DataverseIntegration.CRM;

using DataverseIntegration.CDS;
using DataverseIntegration.Core;
using Microsoft.Integration.D365Sales;
using Microsoft.Integration.Dataverse;
using Microsoft.Integration.SyncEngine;
using Microsoft.Sales.Document;

codeunit 80407 "DVI Sales Order Handler" implements "DVI IRecordSync", "DVI IRecordCoupling", "DVI IRecordFilter", "DVI IHandlerScope", "DVI IRecordCompletion"
{
    Access = Public;

    procedure Serves(var Context: Codeunit "DVI Sync Context"): Boolean
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
    begin
        Context.GetMapping(IntegrationTableMapping);
        exit((IntegrationTableMapping."Table ID" = Database::"Sales Header") and (IntegrationTableMapping."Integration Table ID" = Database::"CRM Salesorder"));
    end;

    procedure DefaultModule(var Context: Codeunit "DVI Sync Context"): Enum "DVI Integration Module"
    begin
        exit(Enum::"DVI Integration Module"::DVISales);
    end;

    procedure IgnoreRecord(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef): Boolean
    var
        CRMSalesOrders: Codeunit "DVI CRM Sales Orders";
    begin
        exit(CRMSalesOrders.IsArchived(SourceRecordRef));
    end;

    procedure BeforeTransferFields(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    var
        SalesHeader: Record "Sales Header";
        CRMSalesOrders: Codeunit "DVI CRM Sales Orders";
    begin
        if Context.IsToIntegrationTable() or not CRMSalesOrders.IsBidirectional() then
            exit;
        DestinationRecordRef.SetTable(SalesHeader);
        SalesHeader.Status := SalesHeader.Status::Open;
        DestinationRecordRef.GetTable(SalesHeader);
    end;

    procedure AfterTransferFields(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef; var AdditionalFieldsModified: Boolean)
    begin
        AdditionalFieldsModified := false;
    end;

    procedure BeforeInsert(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    var
        CDSCompany: Codeunit "DVI CDS Company";
        CRMSalesOrders: Codeunit "DVI CRM Sales Orders";
    begin
        if not CRMSalesOrders.IsBidirectional() then
            exit;
        if not Context.IsToIntegrationTable() then begin
            CRMSalesOrders.SetQuoteNo(SourceRecordRef, DestinationRecordRef);
            exit;
        end;
        CRMSalesOrders.SetPriceList(SourceRecordRef, DestinationRecordRef);
        CDSCompany.SetCompanyId(DestinationRecordRef);
        CRMSalesOrders.SetNameAndOccurrence(SourceRecordRef, DestinationRecordRef);
        CDSCompany.SetOwner(SourceRecordRef, DestinationRecordRef);
    end;

    procedure AfterInsert(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    begin
        QueueLinesAndCompletion(Context, SourceRecordRef, DestinationRecordRef, Enum::"DVI Synch Action"::DVIInsert);
    end;

    procedure BeforeModify(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    var
        CDSCompany: Codeunit "DVI CDS Company";
        CRMSalesOrders: Codeunit "DVI CRM Sales Orders";
    begin
        if not Context.IsToIntegrationTable() then
            exit;
        if CRMSalesOrders.IsBidirectional() then
            CRMSalesOrders.SetPriceList(SourceRecordRef, DestinationRecordRef)
        else
            CRMSalesOrders.SetOneWayState(SourceRecordRef, DestinationRecordRef, true);
        CDSCompany.SetCompanyId(DestinationRecordRef);
    end;

    procedure AfterModify(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    var
        CRMSalesOrders: Codeunit "DVI CRM Sales Orders";
    begin
        if Context.IsToIntegrationTable() and not CRMSalesOrders.IsBidirectional() then begin
            CRMSalesOrders.SetOneWayState(SourceRecordRef, DestinationRecordRef, false);
            exit;
        end;
        QueueLinesAndCompletion(Context, SourceRecordRef, DestinationRecordRef, Enum::"DVI Synch Action"::DVIModify);
    end;

    procedure Unchanged(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    var
        CRMSalesOrders: Codeunit "DVI CRM Sales Orders";
    begin
        if not CRMSalesOrders.IsBidirectional() then
            exit;
        if not Context.IsToIntegrationTable() then
            CRMSalesOrders.Reopen(DestinationRecordRef);
        QueueLinesAndCompletion(Context, SourceRecordRef, DestinationRecordRef, Enum::"DVI Synch Action"::DVIIgnoreUnchanged);
    end;

    procedure Complete(var Context: Codeunit "DVI Sync Context"; var LocalRecordRef: RecordRef; var IntegrationRecordRef: RecordRef)
    var
        CRMSalesOrders: Codeunit "DVI CRM Sales Orders";
    begin
        if Context.IsToIntegrationTable() then
            CRMSalesOrders.CompleteInDataverse(Context, LocalRecordRef, IntegrationRecordRef)
        else
            CRMSalesOrders.CompleteInBusinessCentral(Context, IntegrationRecordRef, LocalRecordRef);
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
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        CRMIntegrationRecord: Record "CRM Integration Record";
        CRMIntegrationManagement: Codeunit "CRM Integration Management";
        CoupledLineIds: List of [Guid];
    begin
        if LocalRecordRef.Number() <> Database::"Sales Header" then
            exit;
        LocalRecordRef.SetTable(SalesHeader);
        SalesLine.SetRange("Document Type", SalesLine."Document Type"::Order);
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.SetLoadFields(SystemId);
        if SalesLine.FindSet() then
            repeat
                if CRMIntegrationRecord.IsRecordCoupled(SalesLine.RecordId()) then
                    CoupledLineIds.Add(SalesLine.SystemId);
            until SalesLine.Next() = 0;
        if CoupledLineIds.Count() > 0 then
            CRMIntegrationManagement.RemoveCoupling(Database::"Sales Line", CoupledLineIds, false);
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

    local procedure QueueLinesAndCompletion(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef; SynchAction: Enum "DVI Synch Action")
    var
        CRMSalesOrders: Codeunit "DVI CRM Sales Orders";
        LocalSystemId: Guid;
    begin
        if not CRMSalesOrders.IsBidirectional() then
            exit;
        if Context.IsToIntegrationTable() then begin
            CRMSalesOrders.QueueLinesToDataverse(Context, SourceRecordRef, DestinationRecordRef);
            LocalSystemId := SourceRecordRef.Field(SourceRecordRef.SystemIdNo()).Value();
        end else begin
            CRMSalesOrders.QueueLinesFromDataverse(Context, SourceRecordRef, DestinationRecordRef);
            LocalSystemId := DestinationRecordRef.Field(DestinationRecordRef.SystemIdNo()).Value();
        end;
        Context.AddCompletion(Context.GetMappingName(), LocalSystemId, Context.IsToIntegrationTable(), SynchAction);
    end;
}
