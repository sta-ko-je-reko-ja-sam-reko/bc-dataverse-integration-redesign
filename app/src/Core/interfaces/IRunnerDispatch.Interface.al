namespace DataverseIntegration.Core;

using Microsoft.Integration.SyncEngine;

interface "DVI IRunnerDispatch"
{
    /// <summary>
    /// Reacts to the standard synchronization runner starting for a mapping; takes the run over when the mapping is switched to the redesigned synchronization.
    /// </summary>
    /// <param name="IntegrationTableMapping">The mapping the job queue runs.</param>
    /// <param name="Handled">Set to true when the run was taken over, so the standard runner does nothing.</param>
    procedure OnBeforeSynchRun(IntegrationTableMapping: Record "Integration Table Mapping"; var Handled: Boolean);

    /// <summary>
    /// Reacts to the standard coupling runner starting for a mapping.
    /// </summary>
    /// <param name="IntegrationTableMapping">The mapping whose records are coupled.</param>
    /// <param name="Handled">Set to true when the run was taken over.</param>
    procedure OnBeforeCoupleRun(IntegrationTableMapping: Record "Integration Table Mapping"; var Handled: Boolean);

    /// <summary>
    /// Reacts to the standard uncoupling runner starting for a mapping.
    /// </summary>
    /// <param name="IntegrationTableMapping">The mapping whose records are uncoupled.</param>
    /// <param name="Handled">Set to true when the run was taken over.</param>
    procedure OnBeforeUncoupleRun(IntegrationTableMapping: Record "Integration Table Mapping"; var Handled: Boolean);
}
