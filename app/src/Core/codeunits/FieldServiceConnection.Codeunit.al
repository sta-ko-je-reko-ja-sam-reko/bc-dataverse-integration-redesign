namespace DataverseIntegration.Core;

using Microsoft.Integration.DynamicsFieldService;

codeunit 80019 "DVI Field Service Connection" implements "DVI IConnection"
{
    Access = Public;

    procedure IsEnabled(): Boolean
    var
        FSConnectionSetup: Record "FS Connection Setup";
    begin
        FSConnectionSetup.SetLoadFields("Is Enabled");
        if not FSConnectionSetup.Get() then
            exit(false);
        exit(FSConnectionSetup."Is Enabled");
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
