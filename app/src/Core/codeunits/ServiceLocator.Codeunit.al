namespace DataverseIntegration.Core;

codeunit 80000 "DVI Service Locator"
{
    Access = Public;
    SingleInstance = true;

    var
        RunnerDispatchImpl: Interface "DVI IRunnerDispatch";
        TableSynchImpl: Interface "DVI ITableSynch";
        CouplingRunnerImpl: Interface "DVI ICouplingRunner";
        RedirectTargetImpl: Interface "DVI IRedirectTarget";
        RunnerDispatchDefined: Boolean;
        RedirectTargetDefined: Boolean;
        TableSynchDefined: Boolean;
        CouplingRunnerDefined: Boolean;

    /// <summary>
    /// Returns the reaction to the standard runners starting.
    /// </summary>
    /// <returns>The injected implementation, or the default dispatch.</returns>
    procedure RunnerDispatch(): Interface "DVI IRunnerDispatch"
    var
        DefaultRunnerDispatch: Codeunit "DVI Runner Dispatch";
    begin
        if not RunnerDispatchDefined then
            ImplementRunnerDispatch(DefaultRunnerDispatch);
        exit(RunnerDispatchImpl);
    end;

    /// <summary>
    /// Replaces the reaction to the standard runners starting, for tests and dependent apps.
    /// </summary>
    /// <param name="Implementation">The implementation to use for the rest of the session.</param>
    procedure ImplementRunnerDispatch(Implementation: Interface "DVI IRunnerDispatch")
    begin
        RunnerDispatchImpl := Implementation;
        RunnerDispatchDefined := true;
    end;

    /// <summary>
    /// Returns the engine that synchronizes a switched mapping.
    /// </summary>
    /// <returns>The injected implementation, or the default engine.</returns>
    procedure TableSynch(): Interface "DVI ITableSynch"
    var
        DefaultTableSynch: Codeunit "DVI Table Synch.";
    begin
        if not TableSynchDefined then
            ImplementTableSynch(DefaultTableSynch);
        exit(TableSynchImpl);
    end;

    /// <summary>
    /// Replaces the engine that synchronizes a switched mapping, for tests and dependent apps.
    /// </summary>
    /// <param name="Implementation">The implementation to use for the rest of the session.</param>
    procedure ImplementTableSynch(Implementation: Interface "DVI ITableSynch")
    begin
        TableSynchImpl := Implementation;
        TableSynchDefined := true;
    end;

    /// <summary>
    /// Returns the runner that couples and uncouples the records of a switched mapping.
    /// </summary>
    /// <returns>The injected implementation, or the default runner.</returns>
    procedure CouplingRunner(): Interface "DVI ICouplingRunner"
    var
        DefaultCouplingRunner: Codeunit "DVI Coupling Runner";
    begin
        if not CouplingRunnerDefined then
            ImplementCouplingRunner(DefaultCouplingRunner);
        exit(CouplingRunnerImpl);
    end;

    /// <summary>
    /// Replaces the runner that couples and uncouples the records of a switched mapping, for tests and dependent apps.
    /// </summary>
    /// <param name="Implementation">The implementation to use for the rest of the session.</param>
    procedure ImplementCouplingRunner(Implementation: Interface "DVI ICouplingRunner")
    begin
        CouplingRunnerImpl := Implementation;
        CouplingRunnerDefined := true;
    end;

    /// <summary>
    /// Returns the implementation that opens Business Central records from Dataverse links.
    /// </summary>
    /// <returns>The injected implementation, or the default redirect.</returns>
    procedure RedirectTarget(): Interface "DVI IRedirectTarget"
    var
        DefaultRedirect: Codeunit "DVI Redirect";
    begin
        if not RedirectTargetDefined then
            ImplementRedirectTarget(DefaultRedirect);
        exit(RedirectTargetImpl);
    end;

    /// <summary>
    /// Replaces the implementation that opens Business Central records from Dataverse links, for tests and dependent apps.
    /// </summary>
    /// <param name="Implementation">The implementation to use for the rest of the session.</param>
    procedure ImplementRedirectTarget(Implementation: Interface "DVI IRedirectTarget")
    begin
        RedirectTargetImpl := Implementation;
        RedirectTargetDefined := true;
    end;
}
