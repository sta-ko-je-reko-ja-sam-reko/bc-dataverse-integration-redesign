namespace DataverseIntegration.Core;

using System.Environment.Configuration;

codeunit 80001 "DVI Feature Mgt."
{
    Access = Public;
    SingleInstance = true;

    var
        EnabledChecked: Boolean;
        EnabledCached: Boolean;
        EnableRestartMsg: Label 'The session will restart in #1 second(s) because the redesigned Dataverse integration has been enabled.', Comment = '#1 = seconds remaining';
        DisableRestartMsg: Label 'The session will restart in #1 second(s) because the redesigned Dataverse integration has been disabled.', Comment = '#1 = seconds remaining';
        NotEnabledErr: Label 'The redesigned Dataverse integration is not enabled. Turn it on in Dataverse Integration Redesign Setup.';

    /// <summary>
    /// Returns whether the redesigned Dataverse integration is enabled. The value is read once per session, because changing it restarts the session.
    /// </summary>
    /// <returns>True when the setup record exists and Enabled is set.</returns>
    procedure IsEnabled(): Boolean
    var
        Setup: Record "DVI Setup";
    begin
        if EnabledChecked then
            exit(EnabledCached);
        Setup.SetLoadFields("DVI Enabled");
        if Setup.Get() then
            EnabledCached := Setup."DVI Enabled";
        EnabledChecked := true;
        exit(EnabledCached);
    end;

    /// <summary>
    /// Raises an error when the redesigned Dataverse integration is not enabled.
    /// </summary>
    procedure CheckEnabled()
    begin
        if not IsEnabled() then
            Error(NotEnabledErr);
    end;

    /// <summary>
    /// Recomputes the application areas and restarts the session so that a change of Enabled takes effect.
    /// </summary>
    /// <param name="NowEnabled">The new value of Enabled, used to choose the message shown before the restart.</param>
    procedure ApplyExperienceChange(NowEnabled: Boolean)
    var
        ApplicationAreaMgmtFacade: Codeunit "Application Area Mgmt. Facade";
        SessionSetting: SessionSettings;
        RestartDialog: Dialog;
        Countdown: Integer;
    begin
        EnabledChecked := false;
        ApplicationAreaMgmtFacade.RefreshExperienceTierCurrentCompany();
        if NowEnabled then
            RestartDialog.Open(EnableRestartMsg)
        else
            RestartDialog.Open(DisableRestartMsg);
        for Countdown := RestartCountdownSeconds() downto 1 do begin
            RestartDialog.Update(1, Countdown);
            Sleep(1000);
        end;
        RestartDialog.Close();
        SessionSetting.Init();
        SessionSetting.RequestSessionUpdate(true);
    end;

    local procedure RestartCountdownSeconds(): Integer
    begin
        exit(3);
    end;
}
