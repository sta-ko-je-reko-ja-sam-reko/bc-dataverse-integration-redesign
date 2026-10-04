namespace DataverseIntegration.Core;

using Microsoft.Integration.Dataverse;
using Microsoft.Integration.SyncEngine;

codeunit 80013 "DVI Mapping Logic" implements "DVI IMappingLogic"
{
    Access = Public;

    var
        NotDataverseMappingErr: Label 'The integration table mapping %1 is not a Dataverse mapping, so it cannot be switched to the redesigned synchronization.', Comment = '%1 = mapping name';
        NotStandardRunnerErr: Label 'The integration table mapping %1 runs codeunit %2 instead of the standard Dataverse synchronization, so it cannot be switched to the redesigned synchronization.', Comment = '%1 = mapping name, %2 = codeunit ID';

    procedure Validate_Handler(var MappingAssignment: Record "DVI Mapping Assignment"; xMappingAssignment: Record "DVI Mapping Assignment")
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
    begin
        if MappingAssignment.Handler = xMappingAssignment.Handler then
            exit;
        if MappingAssignment.Handler = Enum::"DVI Sync Handler"::DVIMicrosoft then
            exit;
        IntegrationTableMapping.SetLoadFields(Type, "Synch. Codeunit ID");
        if not IntegrationTableMapping.Get(MappingAssignment."Mapping Name") then
            exit;
        if IntegrationTableMapping.Type <> IntegrationTableMapping.Type::Dataverse then
            Error(NotDataverseMappingErr, IntegrationTableMapping.Name);
        if IntegrationTableMapping."Synch. Codeunit ID" <> Codeunit::"CRM Integration Table Synch." then
            Error(NotStandardRunnerErr, IntegrationTableMapping.Name, IntegrationTableMapping."Synch. Codeunit ID");
    end;
}
