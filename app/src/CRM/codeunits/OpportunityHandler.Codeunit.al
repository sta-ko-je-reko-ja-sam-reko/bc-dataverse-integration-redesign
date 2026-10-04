namespace DataverseIntegration.CRM;

using DataverseIntegration.CDS;
using DataverseIntegration.Core;
using Microsoft.CRM.Contact;
using Microsoft.CRM.Opportunity;
using Microsoft.Integration.D365Sales;
using Microsoft.Integration.Dataverse;
using Microsoft.Integration.SyncEngine;

codeunit 80405 "DVI Opportunity Handler" implements "DVI IRecordSync", "DVI IRecordCoupling", "DVI IRecordFilter", "DVI IHandlerScope"
{
    Access = Public;

    procedure Serves(var Context: Codeunit "DVI Sync Context"): Boolean
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
    begin
        Context.GetMapping(IntegrationTableMapping);
        exit((IntegrationTableMapping."Table ID" = Database::Opportunity) and (IntegrationTableMapping."Integration Table ID" = Database::"CRM Opportunity"));
    end;

    procedure DefaultModule(var Context: Codeunit "DVI Sync Context"): Enum "DVI Integration Module"
    begin
        exit(Enum::"DVI Integration Module"::DVISales);
    end;

    procedure IgnoreRecord(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef): Boolean
    var
        Opportunity: Record Opportunity;
        Contact: Record Contact;
        CDSConnectionSetup: Record "CDS Connection Setup";
        CRMIntegrationManagement: Codeunit "CRM Integration Management";
        CDSRelations: Codeunit "DVI CDS Relations";
        ContactRecordRef: RecordRef;
    begin
        if SourceRecordRef.Number() <> Database::Opportunity then
            exit(false);
        if not CRMIntegrationManagement.IsCDSIntegrationEnabled() then
            exit(false);
        CDSConnectionSetup.SetLoadFields("Ownership Model");
        if not CDSConnectionSetup.Get() then
            exit(false);
        if CDSConnectionSetup."Ownership Model" = CDSConnectionSetup."Ownership Model"::Person then
            exit(false);
        SourceRecordRef.SetTable(Opportunity);
        if not Contact.Get(Opportunity."Contact No.") then
            exit(false);
        if (Contact.Type <> Contact.Type::Person) or (Contact."Company No." = '') then
            exit(true);
        ContactRecordRef.GetTable(Contact);
        exit(CDSRelations.IsContactWithoutBusinessRelation(ContactRecordRef));
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
    begin
        if not Context.IsToIntegrationTable() then
            exit;
        CDSCompany.SetCompanyId(DestinationRecordRef);
        CDSCompany.SetOwner(SourceRecordRef, DestinationRecordRef);
    end;

    procedure AfterInsert(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    begin
    end;

    procedure BeforeModify(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    var
        CDSCompany: Codeunit "DVI CDS Company";
    begin
        if Context.IsToIntegrationTable() then
            CDSCompany.SetCompanyId(DestinationRecordRef);
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
