namespace DataverseIntegration.Core;

interface "DVI ISynchronizeAction"
{
    /// <summary>
    /// Returns whether the page offers to synchronize the current record or the selection now.
    /// </summary>
    /// <param name="Context">The current record, its mapping and coupling.</param>
    /// <returns>True to show the action.</returns>
    procedure CanSynchronize(var Context: Codeunit "DVI Record Action Context"): Boolean;

    /// <summary>
    /// Synchronizes the selected records of the current mapping now, in a direction the mapping allows.
    /// </summary>
    /// <param name="Context">The current record, its mapping and coupling.</param>
    /// <param name="SelectedRecordRef">The records selected on the page, filtered to the current mapping's table.</param>
    procedure Synchronize(var Context: Codeunit "DVI Record Action Context"; var SelectedRecordRef: RecordRef);
}
