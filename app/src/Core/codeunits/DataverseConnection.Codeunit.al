namespace DataverseIntegration.Core;

using Microsoft.Integration.D365Sales;
using Microsoft.Integration.Dataverse;

codeunit 80012 "DVI Dataverse Connection" implements "DVI IConnection"
{
    Access = Public;

    var
        ConnectionNotEnabledErr: Label 'The connection to Dataverse is not enabled.';

    procedure IsEnabled(): Boolean
    var
        CDSConnectionSetup: Record "CDS Connection Setup";
    begin
        CDSConnectionSetup.SetLoadFields("Is Enabled");
        if not CDSConnectionSetup.Get() then
            exit(false);
        exit(CDSConnectionSetup."Is Enabled");
    end;

    procedure Open() ConnectionName: Text
    var
        CRMConnectionSetup: Record "CRM Connection Setup";
        CRMIntegrationManagement: Codeunit "CRM Integration Management";
        Handled: Boolean;
    begin
        CRMIntegrationManagement.OnInitCDSConnection(ConnectionName, Handled);
        if not Handled then begin
            CRMConnectionSetup.SetLoadFields("Is Enabled");
            if not CRMConnectionSetup.Get() then
                Error(ConnectionNotEnabledErr);
            if not CRMConnectionSetup."Is Enabled" then
                Error(ConnectionNotEnabledErr);
            ConnectionName := Format(CreateGuid());
            CRMConnectionSetup.RegisterConnectionWithName(ConnectionName);
        end;
        TestConnection();
    end;

    procedure Close(ConnectionName: Text)
    var
        CRMConnectionSetup: Record "CRM Connection Setup";
        CRMIntegrationManagement: Codeunit "CRM Integration Management";
        Handled: Boolean;
    begin
        CRMIntegrationManagement.OnCloseCDSConnection(ConnectionName, Handled);
        if Handled then
            exit;
        CRMConnectionSetup.UnregisterConnectionWithName(ConnectionName);
    end;

    local procedure TestConnection()
    var
        CRMConnectionSetup: Record "CRM Connection Setup";
        CRMIntegrationManagement: Codeunit "CRM Integration Management";
        Handled: Boolean;
    begin
        CRMIntegrationManagement.OnTestCDSConnection(Handled);
        if Handled then
            exit;
        if not CRMConnectionSetup.TryReadSystemUsers() then
            Error(GetLastErrorText());
    end;
}
