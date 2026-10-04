namespace DataverseIntegration.Core;

interface "DVI IRedirectTarget"
{
    /// <summary>
    /// Opens the Business Central record coupled to a Dataverse record when a link from Dataverse reaches Business Central.
    /// </summary>
    /// <param name="IntegrationId">The ID of the Dataverse record.</param>
    /// <param name="EntityTypeName">The logical name of the Dataverse entity, from the link.</param>
    /// <param name="Opened">Set to true when a Business Central record was opened.</param>
    /// <param name="Handled">True when another subscriber already handled the link; set to true when this implementation handles it.</param>
    procedure OpenCoupledRecord(IntegrationId: Guid; EntityTypeName: Text; var Opened: Boolean; var Handled: Boolean);
}
