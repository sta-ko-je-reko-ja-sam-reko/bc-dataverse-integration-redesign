namespace DataverseIntegration.Core;

using Microsoft.Integration.D365Sales;

codeunit 80018 "DVI Sales Connection" implements "DVI IConnection"
{
    Access = Public;

    procedure IsEnabled(): Boolean
    var
        CRMConnectionSetup: Record "CRM Connection Setup";
    begin
        CRMConnectionSetup.SetLoadFields("Is Enabled");
        if not CRMConnectionSetup.Get() then
            exit(false);
        exit(CRMConnectionSetup."Is Enabled");
    end;

    procedure Open(): Text
    var
        DataverseConnection: Codeunit "DVI Dataverse Connection";
    begin
        exit(DataverseConnection.Open());
    end;

    procedure Close(ConnectionName: Text)
    var
        DataverseConnection: Codeunit "DVI Dataverse Connection";
    begin
        DataverseConnection.Close(ConnectionName);
    end;
}
