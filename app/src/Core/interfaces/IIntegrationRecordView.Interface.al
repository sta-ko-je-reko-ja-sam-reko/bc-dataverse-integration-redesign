namespace DataverseIntegration.Core;

interface "DVI IIntegrationRecordView"
{
    /// <summary>
    /// Returns whether the page offers to open the Dataverse record coupled to the current record.
    /// </summary>
    /// <param name="Context">The current record, its mapping and coupling.</param>
    /// <returns>True to show the action.</returns>
    procedure CanOpenIntegrationRecord(var Context: Codeunit "DVI Record Action Context"): Boolean;

    /// <summary>
    /// Opens the coupled Dataverse record.
    /// </summary>
    /// <param name="Context">The current record, its mapping and coupling.</param>
    procedure OpenIntegrationRecord(var Context: Codeunit "DVI Record Action Context");
}
