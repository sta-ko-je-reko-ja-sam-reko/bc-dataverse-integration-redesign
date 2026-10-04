namespace DataverseIntegration.Core;

using Microsoft.Integration.Dataverse;
using Microsoft.Integration.SyncEngine;

codeunit 80013 "DVI Mapping Logic" implements "DVI IMappingLogic"
{
    Access = Public;

    var
        NotDataverseMappingErr: Label 'The integration table mapping %1 is not a Dataverse mapping, so it cannot be switched to the redesigned synchronization.', Comment = '%1 = mapping name';
        NotStandardRunnerErr: Label 'The integration table mapping %1 runs codeunit %2 instead of the standard Dataverse synchronization, so it cannot be switched to the redesigned synchronization.', Comment = '%1 = mapping name, %2 = codeunit ID';

    procedure Validate_Handler(var IntegrationTableMapping: Record "Integration Table Mapping"; xIntegrationTableMapping: Record "Integration Table Mapping")
    begin
        if IntegrationTableMapping."DVI Handler" = xIntegrationTableMapping."DVI Handler" then
            exit;
        if IntegrationTableMapping."DVI Handler" = Enum::"DVI Sync Handler"::DVIMicrosoft then
            exit;
        if IntegrationTableMapping.Type <> IntegrationTableMapping.Type::Dataverse then
            Error(NotDataverseMappingErr, IntegrationTableMapping.Name);
        if IntegrationTableMapping."Synch. Codeunit ID" <> Codeunit::"CRM Integration Table Synch." then
            Error(NotStandardRunnerErr, IntegrationTableMapping.Name, IntegrationTableMapping."Synch. Codeunit ID");
    end;
}
