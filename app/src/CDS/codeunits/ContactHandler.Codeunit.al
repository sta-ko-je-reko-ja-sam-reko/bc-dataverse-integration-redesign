namespace DataverseIntegration.CDS;

using DataverseIntegration.Core;
using Microsoft.CRM.Contact;
using Microsoft.Integration.D365Sales;
using Microsoft.Integration.SyncEngine;

codeunit 80212 "DVI Contact Handler" implements "DVI IRecordSync", "DVI IRecordCoupling", "DVI IRecordFilter", "DVI IHandlerScope"
{
    Access = Public;

    procedure Serves(var Context: Codeunit "DVI Sync Context"): Boolean
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
    begin
        Context.GetMapping(IntegrationTableMapping);
        exit((IntegrationTableMapping."Table ID" = Database::Contact) and (IntegrationTableMapping."Integration Table ID" = Database::"CRM Contact"));
    end;

    procedure DefaultModule(var Context: Codeunit "DVI Sync Context"): Enum "DVI Integration Module"
    begin
        exit(Enum::"DVI Integration Module"::DVIDataverse);
    end;

    procedure IgnoreRecord(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef): Boolean
    var
        CDSRelations: Codeunit "DVI CDS Relations";
    begin
        if SourceRecordRef.Number() <> Database::Contact then
            exit(false);
        exit(CDSRelations.IsContactWithoutBusinessRelation(SourceRecordRef));
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
        CDSCompany: Codeunit "DVI CDS Company";
        CDSRelations: Codeunit "DVI CDS Relations";
    begin
        if Context.IsToIntegrationTable() then begin
            CDSRelations.SetParentAccount(SourceRecordRef, DestinationRecordRef);
            CDSCompany.SetCompanyId(DestinationRecordRef);
            CDSCompany.SetOwner(SourceRecordRef, DestinationRecordRef);
            exit;
        end;
        CDSRelations.SetContactCompany(SourceRecordRef, DestinationRecordRef);
    end;

    procedure AfterInsert(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    var
        CDSCompany: Codeunit "DVI CDS Company";
        CDSRelations: Codeunit "DVI CDS Relations";
    begin
        if Context.IsToIntegrationTable() then begin
            CDSRelations.FixPrimaryContactInDataverse(DestinationRecordRef);
            exit;
        end;
        CDSRelations.FixPrimaryContactNo(SourceRecordRef, DestinationRecordRef);
        CDSCompany.StampCompanyIdOnContact(SourceRecordRef);
    end;

    procedure BeforeModify(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    var
        CDSCompany: Codeunit "DVI CDS Company";
        CDSRelations: Codeunit "DVI CDS Relations";
    begin
        if Context.IsToIntegrationTable() then begin
            CDSRelations.SetParentAccount(SourceRecordRef, DestinationRecordRef);
            CDSCompany.SetCompanyId(DestinationRecordRef);
            exit;
        end;
        CDSRelations.SetContactCompany(SourceRecordRef, DestinationRecordRef);
    end;

    procedure AfterModify(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    begin
    end;

    procedure Unchanged(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    var
        CRMContact: Record "CRM Contact";
        CDSRelations: Codeunit "DVI CDS Relations";
        ParentAccountId: Guid;
    begin
        if not Context.IsToIntegrationTable() then
            exit;
        ParentAccountId := DestinationRecordRef.Field(CRMContact.FieldNo(ParentCustomerId)).Value();
        if not IsNullGuid(ParentAccountId) then
            exit;
        CDSRelations.SetParentAccount(SourceRecordRef, DestinationRecordRef);
        ParentAccountId := DestinationRecordRef.Field(CRMContact.FieldNo(ParentCustomerId)).Value();
        if not IsNullGuid(ParentAccountId) then
            DestinationRecordRef.Modify();
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
