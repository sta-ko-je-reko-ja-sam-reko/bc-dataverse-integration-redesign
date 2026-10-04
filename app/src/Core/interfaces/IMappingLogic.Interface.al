namespace DataverseIntegration.Core;

using Microsoft.Integration.SyncEngine;

interface "DVI IMappingLogic"
{
    /// <summary>
    /// Validates a change of the synchronization handler on an integration table mapping.
    /// </summary>
    /// <param name="IntegrationTableMapping">The mapping with the new handler.</param>
    /// <param name="xIntegrationTableMapping">The mapping before the change.</param>
    procedure Validate_Handler(var IntegrationTableMapping: Record "Integration Table Mapping"; xIntegrationTableMapping: Record "Integration Table Mapping");
}
