namespace DataverseIntegration.CDS;

using DataverseIntegration.Core;
using Microsoft.CRM.Team;
using Microsoft.Integration.D365Sales;
using Microsoft.Integration.SyncEngine;

codeunit 80214 "DVI Salesperson Handler" implements "DVI IRecordSync", "DVI IHandlerScope"
{
    Access = Public;

    var
        CodeFilterTok: Label 'SP NO. 0*', Locked = true;
        FirstCodeTok: Label 'SP NO. 00001', Locked = true;

    procedure Serves(var Context: Codeunit "DVI Sync Context"): Boolean
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
    begin
        Context.GetMapping(IntegrationTableMapping);
        exit((IntegrationTableMapping."Table ID" = Database::"Salesperson/Purchaser") and (IntegrationTableMapping."Integration Table ID" = Database::"CRM Systemuser"));
    end;

    procedure DefaultModule(var Context: Codeunit "DVI Sync Context"): Enum "DVI Integration Module"
    begin
        exit(Enum::"DVI Integration Module"::DVIDataverse);
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
        SalespersonPurchaser: Record "Salesperson/Purchaser";
    begin
        if DestinationRecordRef.Number() <> Database::"Salesperson/Purchaser" then
            exit;
        DestinationRecordRef.Field(SalespersonPurchaser.FieldNo(Code)).Value(NextCode());
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

    local procedure NextCode(): Code[20]
    var
        SalespersonPurchaser: Record "Salesperson/Purchaser";
    begin
        SalespersonPurchaser.SetLoadFields(Code);
        SalespersonPurchaser.SetFilter(Code, CodeFilterTok);
        if SalespersonPurchaser.FindLast() then
            exit(IncStr(SalespersonPurchaser.Code));
        exit(FirstCodeTok);
    end;
}
