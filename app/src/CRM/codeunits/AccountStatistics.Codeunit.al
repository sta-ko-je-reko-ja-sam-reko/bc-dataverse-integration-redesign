namespace DataverseIntegration.CRM;

using DataverseIntegration.Core;
using Microsoft.Integration.Dataverse;
using Microsoft.Integration.SyncEngine;
using Microsoft.Sales.Customer;

codeunit 80412 "DVI Account Statistics" implements "DVI IStatisticsAction"
{
    Access = Public;

    procedure CanUpdateStatistics(var Context: Codeunit "DVI Record Action Context"): Boolean
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        CRMIntegrationManagement: Codeunit "CRM Integration Management";
    begin
        if not Context.HasMapping() then
            exit(false);
        Context.GetMapping(IntegrationTableMapping);
        if IntegrationTableMapping."Table ID" <> Database::Customer then
            exit(false);
        if not (Context.IsCoupled() and Context.AllowsToIntegrationTable()) then
            exit(false);
        exit(CRMIntegrationManagement.IsCRMIntegrationEnabled());
    end;

    procedure UpdateStatistics(var Context: Codeunit "DVI Record Action Context")
    var
        Customer: Record Customer;
        CRMIntegrationManagement: Codeunit "CRM Integration Management";
    begin
        if not Customer.Get(Context.GetRecordId()) then
            exit;
        CRMIntegrationManagement.CreateOrUpdateCRMAccountStatistics(Customer);
    end;
}
