namespace DataverseIntegration.Core;

using Microsoft.Integration.Dataverse;
using Microsoft.Integration.SyncEngine;

codeunit 80004 "DVI Runner Events"
{
    Access = Internal;
    SingleInstance = true;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"CRM Integration Table Synch.", OnBeforeRun, '', true, true)]
    local procedure OnBeforeRunSynchronization(IntegrationTableMapping: Record "Integration Table Mapping"; var IsHandled: Boolean)
    var
        ServiceLocator: Codeunit "DVI Service Locator";
    begin
        ServiceLocator.RunnerDispatch().OnBeforeSynchRun(IntegrationTableMapping, IsHandled);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"CDS Int. Table Couple", OnBeforeRun, '', true, true)]
    local procedure OnBeforeRunCoupling(IntegrationTableMapping: Record "Integration Table Mapping"; var Handled: Boolean)
    var
        ServiceLocator: Codeunit "DVI Service Locator";
    begin
        ServiceLocator.RunnerDispatch().OnBeforeCoupleRun(IntegrationTableMapping, Handled);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"CDS Int. Table Uncouple", OnBeforeRun, '', true, true)]
    local procedure OnBeforeRunUncoupling(IntegrationTableMapping: Record "Integration Table Mapping"; var Handled: Boolean)
    var
        ServiceLocator: Codeunit "DVI Service Locator";
    begin
        ServiceLocator.RunnerDispatch().OnBeforeUncoupleRun(IntegrationTableMapping, Handled);
    end;
}
