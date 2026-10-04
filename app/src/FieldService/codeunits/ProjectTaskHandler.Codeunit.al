namespace DataverseIntegration.FieldService;

using DataverseIntegration.CDS;
using DataverseIntegration.Core;
using DataverseIntegration.CRM;
using Microsoft.Integration.D365Sales;
using Microsoft.Integration.DynamicsFieldService;
using Microsoft.Integration.SyncEngine;
using Microsoft.Projects.Project.Job;
using Microsoft.Sales.Customer;

codeunit 80814 "DVI Project Task Handler" implements "DVI IRecordSync", "DVI IRecordCoupling", "DVI IRecordFilter", "DVI IHandlerScope"
{
    Access = Public;

    var
        CustomerNotCoupledErr: Label 'The customer %1 of project %2 must be coupled to a Dataverse account.', Comment = '%1 = customer number, %2 = project number';

    procedure Serves(var Context: Codeunit "DVI Sync Context"): Boolean
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
    begin
        Context.GetMapping(IntegrationTableMapping);
        exit((IntegrationTableMapping."Table ID" = Database::"Job Task") and (IntegrationTableMapping."Integration Table ID" = Database::"FS Project Task"));
    end;

    procedure DefaultModule(var Context: Codeunit "DVI Sync Context"): Enum "DVI Integration Module"
    begin
        exit(Enum::"DVI Integration Module"::DVIFieldService);
    end;

    procedure IgnoreRecord(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef): Boolean
    var
        JobTask: Record "Job Task";
    begin
        if SourceRecordRef.Number() <> Database::"Job Task" then
            exit(false);
        SourceRecordRef.SetTable(JobTask);
        exit(not IsProjectOpenForFieldService(JobTask."Job No."));
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
        JobTask: Record "Job Task";
        Job: Record Job;
        FSProjectTask: Record "FS Project Task";
        CDSCompany: Codeunit "DVI CDS Company";
    begin
        if not Context.IsToIntegrationTable() then
            exit;
        SourceRecordRef.SetTable(JobTask);
        DestinationRecordRef.SetTable(FSProjectTask);
        if Job.Get(JobTask."Job No.") then begin
            FSProjectTask.ProjectDescription := Job.Description;
            if Job."Bill-to Customer No." <> '' then
                FSProjectTask.BillingAccountId := RequireAccount(Context, Job."Bill-to Customer No.", Job."No.");
            if Job."Sell-to Customer No." <> '' then
                FSProjectTask.ServiceAccountId := RequireAccount(Context, Job."Sell-to Customer No.", Job."No.")
            else
                FSProjectTask.ServiceAccountId := FSProjectTask.BillingAccountId;
        end;
        DestinationRecordRef.GetTable(FSProjectTask);
        CDSCompany.SetCompanyId(DestinationRecordRef);
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

    /// <summary>
    /// Returns whether the tasks of a project go to Field Service: the project exists, is not blocked, is open and applies usage links.
    /// </summary>
    /// <param name="JobNo">The project.</param>
    /// <returns>True when the project's tasks are synchronized.</returns>
    procedure IsProjectOpenForFieldService(JobNo: Code[20]): Boolean
    var
        Job: Record Job;
    begin
        Job.SetLoadFields(Blocked, Status, "Apply Usage Link");
        if not Job.Get(JobNo) then
            exit(false);
        if Job.Blocked <> Job.Blocked::" " then
            exit(false);
        if Job.Status <> Job.Status::Open then
            exit(false);
        exit(Job."Apply Usage Link");
    end;

    local procedure RequireAccount(var Context: Codeunit "DVI Sync Context"; CustomerNo: Code[20]; JobNo: Code[20]) AccountId: Guid
    var
        Customer: Record Customer;
        CRMPrices: Codeunit "DVI CRM Prices";
        CustomerRecordRef: RecordRef;
    begin
        Customer.SetRange("No.", CustomerNo);
        CustomerRecordRef.GetTable(Customer);
        AccountId := CRMPrices.RequireCoupledRecord(Context, CustomerRecordRef, Database::"CRM Account");
        if IsNullGuid(AccountId) then
            Error(CustomerNotCoupledErr, CustomerNo, JobNo);
    end;
}
