namespace DataverseIntegration.CRM;

using DataverseIntegration.Core;
using Microsoft.Integration.D365Sales;
using Microsoft.Integration.SyncEngine;
using Microsoft.Sales.History;

codeunit 80413 "DVI Invoice Line Handler" implements "DVI IRecordSync", "DVI IRecordFilter", "DVI IHandlerScope"
{
    Access = Public;

    procedure Serves(var Context: Codeunit "DVI Sync Context"): Boolean
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
    begin
        Context.GetMapping(IntegrationTableMapping);
        exit((IntegrationTableMapping."Table ID" = Database::"Sales Invoice Line") and (IntegrationTableMapping."Integration Table ID" = Database::"CRM Invoicedetail"));
    end;

    procedure DefaultModule(var Context: Codeunit "DVI Sync Context"): Enum "DVI Integration Module"
    begin
        exit(Enum::"DVI Integration Module"::DVISales);
    end;

    procedure IgnoreRecord(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef): Boolean
    var
        CRMInvoices: Codeunit "DVI CRM Invoices";
    begin
        if SourceRecordRef.Number() <> Database::"Sales Invoice Line" then
            exit(false);
        exit(CRMInvoices.IsLineOfUncoupledInvoice(SourceRecordRef));
    end;

    procedure BeforeTransferFields(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    begin
    end;

    procedure AfterTransferFields(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef; var AdditionalFieldsModified: Boolean)
    begin
        AdditionalFieldsModified := false;
    end;

    procedure BeforeInsert(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    var
        CRMInvoices: Codeunit "DVI CRM Invoices";
    begin
        if Context.IsToIntegrationTable() then
            CRMInvoices.PrepareLine(Context, SourceRecordRef, DestinationRecordRef);
    end;

    procedure AfterInsert(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    var
        CRMInvoices: Codeunit "DVI CRM Invoices";
    begin
        if Context.IsToIntegrationTable() then
            CRMInvoices.UpdateLineAmounts(SourceRecordRef, DestinationRecordRef);
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
}
