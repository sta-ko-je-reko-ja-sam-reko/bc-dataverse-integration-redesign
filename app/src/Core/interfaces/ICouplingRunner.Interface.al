namespace DataverseIntegration.Core;

using Microsoft.Integration.SyncEngine;

interface "DVI ICouplingRunner"
{
    /// <summary>
    /// Runs the scheduled coupling of a mapping: matches uncoupled records by the mapping's coupling criteria and couples them.
    /// </summary>
    /// <param name="IntegrationTableMapping">The mapping whose records are coupled.</param>
    procedure CoupleMapping(var IntegrationTableMapping: Record "Integration Table Mapping");

    /// <summary>
    /// Runs the scheduled uncoupling of a mapping: removes the couplings of the records the mapping's filters select.
    /// </summary>
    /// <param name="IntegrationTableMapping">The mapping whose records are uncoupled.</param>
    procedure UncoupleMapping(var IntegrationTableMapping: Record "Integration Table Mapping");
}
