namespace DataverseIntegration.Core;

interface "DVI IStatisticsAction"
{
    /// <summary>
    /// Returns whether the page offers to send statistics of the current record to Dataverse.
    /// </summary>
    /// <param name="Context">The current record, its mapping and coupling.</param>
    /// <returns>True to show the action.</returns>
    procedure CanUpdateStatistics(var Context: Codeunit "DVI Record Action Context"): Boolean;

    /// <summary>
    /// Sends statistics of the current record to its coupled Dataverse record.
    /// </summary>
    /// <param name="Context">The current record, its mapping and coupling.</param>
    procedure UpdateStatistics(var Context: Codeunit "DVI Record Action Context");
}
