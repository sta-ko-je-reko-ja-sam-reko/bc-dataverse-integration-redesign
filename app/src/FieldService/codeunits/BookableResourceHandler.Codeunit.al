namespace DataverseIntegration.FieldService;

using DataverseIntegration.CDS;
using DataverseIntegration.Core;
using Microsoft.Integration.D365Sales;
using Microsoft.Integration.DynamicsFieldService;
using Microsoft.Integration.SyncEngine;
using Microsoft.Projects.Resources.Resource;
using System.Security.User;

codeunit 80810 "DVI Bookable Resource Handler" implements "DVI IRecordSync", "DVI IRecordCoupling", "DVI IRecordFilter", "DVI IHandlerScope"
{
    Access = Public;

    procedure Serves(var Context: Codeunit "DVI Sync Context"): Boolean
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
    begin
        Context.GetMapping(IntegrationTableMapping);
        exit((IntegrationTableMapping."Table ID" = Database::Resource) and (IntegrationTableMapping."Integration Table ID" = Database::"FS Bookable Resource"));
    end;

    procedure DefaultModule(var Context: Codeunit "DVI Sync Context"): Enum "DVI Integration Module"
    begin
        exit(Enum::"DVI Integration Module"::DVIFieldService);
    end;

    procedure IgnoreRecord(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef): Boolean
    var
        FSBookableResource: Record "FS Bookable Resource";
    begin
        if SourceRecordRef.Number() <> Database::"FS Bookable Resource" then
            exit(false);
        SourceRecordRef.SetTable(FSBookableResource);
        exit(IsUnsupportedType(FSBookableResource.ResourceType));
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
        Resource: Record Resource;
        FSBookableResource: Record "FS Bookable Resource";
        FSConnectionSetup: Record "FS Connection Setup";
        CDSCompany: Codeunit "DVI CDS Company";
    begin
        if Context.IsToIntegrationTable() then begin
            SourceRecordRef.SetTable(Resource);
            DestinationRecordRef.SetTable(FSBookableResource);
            FSBookableResource.TimeZone := 92;
            FSBookableResource.ResourceType := ResourceTypeOf(Resource);
            FSBookableResource.UserId := FindUserOfResource(Resource);
            DestinationRecordRef.GetTable(FSBookableResource);
            CDSCompany.SetCompanyId(DestinationRecordRef);
            exit;
        end;
        SourceRecordRef.SetTable(FSBookableResource);
        DestinationRecordRef.SetTable(Resource);
        if FSBookableResource.ResourceType = FSBookableResource.ResourceType::Equipment then
            Resource.Type := Resource.Type::Machine
        else
            Resource.Type := Resource.Type::Person;
        FSConnectionSetup.SetLoadFields("Hour Unit of Measure");
        if FSConnectionSetup.Get() then
            Resource."Base Unit of Measure" := FSConnectionSetup."Hour Unit of Measure";
        Resource."Time Sheet Owner User ID" := FindUserOfBookableResource(FSBookableResource);
        DestinationRecordRef.GetTable(Resource);
    end;

    procedure AfterInsert(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    var
        FSRecords: Codeunit "DVI FS Records";
    begin
        if not Context.IsToIntegrationTable() then
            FSRecords.StampCompanyOnSource(SourceRecordRef);
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
    /// Returns whether a bookable resource type has no Business Central counterpart: contacts, crews, facilities and pools.
    /// </summary>
    /// <param name="ResourceType">The type of the bookable resource.</param>
    /// <returns>True when resources of this type are not synchronized.</returns>
    procedure IsUnsupportedType(ResourceType: Integer): Boolean
    var
        FSBookableResource: Record "FS Bookable Resource";
    begin
        exit(ResourceType in [FSBookableResource.ResourceType::Contact, FSBookableResource.ResourceType::Crew, FSBookableResource.ResourceType::Facility, FSBookableResource.ResourceType::Pool]);
    end;

    /// <summary>
    /// Returns the bookable resource type of a resource: equipment for machines; for people an account when they have a vendor, a user when they own time sheets, else generic.
    /// </summary>
    /// <param name="Resource">The resource.</param>
    /// <returns>The bookable resource type.</returns>
    procedure ResourceTypeOf(Resource: Record Resource): Integer
    var
        FSBookableResource: Record "FS Bookable Resource";
    begin
        if Resource.Type = Resource.Type::Machine then
            exit(FSBookableResource.ResourceType::Equipment);
        if Resource."Vendor No." <> '' then
            exit(FSBookableResource.ResourceType::Account);
        if Resource."Time Sheet Owner User ID" <> '' then
            exit(FSBookableResource.ResourceType::User);
        exit(FSBookableResource.ResourceType::Generic);
    end;

    local procedure FindUserOfResource(Resource: Record Resource): Guid
    var
        UserSetup: Record "User Setup";
        CRMSystemuser: Record "CRM Systemuser";
    begin
        if Resource."Time Sheet Owner User ID" = '' then
            exit;
        UserSetup.SetLoadFields("E-Mail");
        if not UserSetup.Get(Resource."Time Sheet Owner User ID") then
            exit;
        if UserSetup."E-Mail" = '' then
            exit;
        CRMSystemuser.SetRange(InternalEMailAddress, UserSetup."E-Mail");
        if CRMSystemuser.FindFirst() then
            exit(CRMSystemuser.SystemUserId);
    end;

    local procedure FindUserOfBookableResource(FSBookableResource: Record "FS Bookable Resource"): Code[50]
    var
        UserSetup: Record "User Setup";
        CRMSystemuser: Record "CRM Systemuser";
    begin
        if FSBookableResource.ResourceType <> FSBookableResource.ResourceType::User then
            exit('');
        if IsNullGuid(FSBookableResource.UserId) then
            exit('');
        if not CRMSystemuser.Get(FSBookableResource.UserId) then
            exit('');
        if CRMSystemuser.InternalEMailAddress = '' then
            exit('');
        UserSetup.SetRange("E-Mail", CRMSystemuser.InternalEMailAddress);
        if UserSetup.FindFirst() then
            exit(UserSetup."User ID");
        exit('');
    end;
}
