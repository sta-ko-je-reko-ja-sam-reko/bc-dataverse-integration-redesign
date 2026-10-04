namespace DataverseIntegration.Core;

using Microsoft.Integration.SyncEngine;

codeunit 80005 "DVI Runner Dispatch" implements "DVI IRunnerDispatch"
{
    Access = Public;

    procedure OnBeforeSynchRun(IntegrationTableMapping: Record "Integration Table Mapping"; var Handled: Boolean)
    var
        ServiceLocator: Codeunit "DVI Service Locator";
    begin
        if not TakesOver(IntegrationTableMapping, Handled) then
            exit;
        ServiceLocator.TableSynch().SynchronizeMapping(IntegrationTableMapping);
        Handled := true;
    end;

    procedure OnBeforeCoupleRun(IntegrationTableMapping: Record "Integration Table Mapping"; var Handled: Boolean)
    var
        ServiceLocator: Codeunit "DVI Service Locator";
    begin
        if not TakesOver(IntegrationTableMapping, Handled) then
            exit;
        ServiceLocator.CouplingRunner().CoupleMapping(IntegrationTableMapping);
        Handled := true;
    end;

    procedure OnBeforeUncoupleRun(IntegrationTableMapping: Record "Integration Table Mapping"; var Handled: Boolean)
    var
        ServiceLocator: Codeunit "DVI Service Locator";
    begin
        if not TakesOver(IntegrationTableMapping, Handled) then
            exit;
        ServiceLocator.CouplingRunner().UncoupleMapping(IntegrationTableMapping);
        Handled := true;
    end;

    local procedure TakesOver(IntegrationTableMapping: Record "Integration Table Mapping"; Handled: Boolean): Boolean
    var
        FeatureMgt: Codeunit "DVI Feature Mgt.";
        MappingResolver: Codeunit "DVI Mapping Resolver";
    begin
        if not FeatureMgt.IsEnabled() then
            exit(false);
        if Handled then
            exit(false);
        exit(MappingResolver.IsSwitched(IntegrationTableMapping));
    end;
}
