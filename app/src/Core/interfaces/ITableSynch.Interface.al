namespace DataverseIntegration.Core;

using Microsoft.Integration.SyncEngine;

interface "DVI ITableSynch"
{
    /// <summary>
    /// Runs the scheduled synchronization of one integration table mapping in the directions it allows.
    /// </summary>
    /// <param name="IntegrationTableMapping">The mapping that the job queue runs.</param>
    procedure SynchronizeMapping(var IntegrationTableMapping: Record "Integration Table Mapping");
}
