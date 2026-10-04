namespace DataverseIntegration.CDS;

using DataverseIntegration.Core;
using Microsoft.Integration.D365Sales;
using Microsoft.Integration.Dataverse;
using Microsoft.Integration.SyncEngine;
using Microsoft.Purchases.Vendor;
using Microsoft.Sales.Customer;
using System.IO;

codeunit 80210 "DVI Account Handler" implements "DVI IRecordSync", "DVI IRecordCoupling", "DVI IHandlerScope"
{
    Access = Public;

    procedure Serves(var Context: Codeunit "DVI Sync Context"): Boolean
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
    begin
        Context.GetMapping(IntegrationTableMapping);
        exit((IntegrationTableMapping."Table ID" in [Database::Customer, Database::Vendor]) and
          (IntegrationTableMapping."Integration Table ID" = Database::"CRM Account"));
    end;

    procedure DefaultModule(var Context: Codeunit "DVI Sync Context"): Enum "DVI Integration Module"
    begin
        exit(Enum::"DVI Integration Module"::DVIDataverse);
    end;

    procedure BeforeTransferFields(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    begin
    end;

    procedure AfterTransferFields(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef; var AdditionalFieldsModified: Boolean)
    var
        CDSRelations: Codeunit "DVI CDS Relations";
    begin
        AdditionalFieldsModified := false;
        if DestinationRecordRef.Number() = Database::Customer then
            AdditionalFieldsModified := CDSRelations.BlockCustomerOfInactiveAccount(SourceRecordRef, DestinationRecordRef);
    end;

    procedure BeforeInsert(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    var
        CDSCompany: Codeunit "DVI CDS Company";
    begin
        if Context.IsToIntegrationTable() then begin
            CDSCompany.SetCompanyId(DestinationRecordRef);
            CDSCompany.SetOwner(SourceRecordRef, DestinationRecordRef);
            exit;
        end;
        FillKeyFromTemplate(Context, SourceRecordRef, DestinationRecordRef);
    end;

    procedure AfterInsert(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    var
        CDSCompany: Codeunit "DVI CDS Company";
        CDSRelations: Codeunit "DVI CDS Relations";
    begin
        if Context.IsToIntegrationTable() then begin
            if SourceRecordRef.Number() = Database::Customer then
                CDSRelations.RewindContactMapping(SourceRecordRef);
            exit;
        end;
        CDSCompany.StampCompanyIdOnAccount(SourceRecordRef);
        CDSRelations.UpdateChildContacts(SourceRecordRef);
    end;

    procedure BeforeModify(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    var
        CDSCompany: Codeunit "DVI CDS Company";
    begin
        if Context.IsToIntegrationTable() then
            CDSCompany.SetCompanyId(DestinationRecordRef);
    end;

    procedure AfterModify(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    var
        CRMSynchHelper: Codeunit "CRM Synch. Helper";
    begin
        case DestinationRecordRef.Number() of
            Database::Customer:
                CRMSynchHelper.UpdateContactOnModifyCustomer(DestinationRecordRef);
            Database::Vendor:
                CRMSynchHelper.UpdateContactOnModifyVendor(DestinationRecordRef);
        end;
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
    var
        CDSRelations: Codeunit "DVI CDS Relations";
    begin
        CDSRelations.RemoveChildContactCouplings(LocalRecordRef, IntegrationRecordRef);
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

    local procedure FillKeyFromTemplate(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        ConfigTemplateHeader: Record "Config. Template Header";
        ConfigTemplateApplier: Codeunit "DVI Config. Template Applier";
        CustomerTemplMgt: Codeunit "Customer Templ. Mgt.";
        VendorTemplMgt: Codeunit "Vendor Templ. Mgt.";
        TemplateCode: Code[10];
    begin
        Context.GetMapping(IntegrationTableMapping);
        TemplateCode := ConfigTemplateApplier.FindTemplateCode(IntegrationTableMapping, SourceRecordRef, DestinationRecordRef);
        if TemplateCode = '' then
            exit;
        if not ConfigTemplateHeader.Get(TemplateCode) then
            exit;
        case DestinationRecordRef.Number() of
            Database::Customer:
                CustomerTemplMgt.FillCustomerKeyFromInitSeries(DestinationRecordRef, ConfigTemplateHeader);
            Database::Vendor:
                VendorTemplMgt.FillVendorKeyFromInitSeries(DestinationRecordRef, ConfigTemplateHeader);
        end;
    end;
}
