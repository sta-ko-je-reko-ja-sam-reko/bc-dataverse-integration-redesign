namespace DataverseIntegration.Core;

using Microsoft.Integration.SyncEngine;

interface "DVI ILocalRecordView"
{
    /// <summary>
    /// Opens the Business Central record coupled to a Dataverse record, for a link from Dataverse (the CRM Redirect page).
    /// </summary>
    /// <param name="IntegrationTableMapping">The mapping of the Dataverse table.</param>
    /// <param name="IntegrationId">The Dataverse record.</param>
    /// <returns>True when a page was opened; false offers to couple the record.</returns>
    procedure OpenLocalRecord(IntegrationTableMapping: Record "Integration Table Mapping"; IntegrationId: Guid): Boolean;
}
