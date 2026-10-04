namespace DataverseIntegration.Core;

interface "DVI ISynchLogView"
{
    /// <summary>
    /// Returns whether the page offers the synchronization log of the current record.
    /// </summary>
    /// <param name="Context">The current record, its mapping and coupling.</param>
    /// <returns>True to show the action.</returns>
    procedure CanShowLog(var Context: Codeunit "DVI Record Action Context"): Boolean;

    /// <summary>
    /// Shows the synchronization jobs of the current record's mapping, narrowed to the record's latest jobs when it is coupled.
    /// </summary>
    /// <param name="Context">The current record, its mapping and coupling.</param>
    procedure ShowLog(var Context: Codeunit "DVI Record Action Context");
}
