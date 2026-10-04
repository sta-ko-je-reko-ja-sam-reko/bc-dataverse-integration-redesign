namespace DataverseIntegration.Core;

interface "DVI ICouplingAction"
{
    /// <summary>
    /// Returns whether the page offers to set up or change the coupling of the current record.
    /// </summary>
    /// <param name="Context">The current record, its mapping and coupling.</param>
    /// <returns>True to show the action.</returns>
    procedure CanSetUpCoupling(var Context: Codeunit "DVI Record Action Context"): Boolean;

    /// <summary>
    /// Lets the user couple the current record to a Dataverse record.
    /// </summary>
    /// <param name="Context">The current record, its mapping and coupling.</param>
    procedure SetUpCoupling(var Context: Codeunit "DVI Record Action Context");

    /// <summary>
    /// Returns whether the page offers to delete the coupling of the current record.
    /// </summary>
    /// <param name="Context">The current record, its mapping and coupling.</param>
    /// <returns>True to show the action.</returns>
    procedure CanDeleteCoupling(var Context: Codeunit "DVI Record Action Context"): Boolean;

    /// <summary>
    /// Deletes the coupling of the selected records.
    /// </summary>
    /// <param name="Context">The current record, its mapping and coupling.</param>
    /// <param name="SelectedRecordRef">The records selected on the page.</param>
    procedure DeleteCoupling(var Context: Codeunit "DVI Record Action Context"; var SelectedRecordRef: RecordRef);

    /// <summary>
    /// Returns whether the page offers match-based coupling of the selected records.
    /// </summary>
    /// <param name="Context">The current record, its mapping and coupling.</param>
    /// <returns>True to show the action.</returns>
    procedure CanMatchBasedCoupling(var Context: Codeunit "DVI Record Action Context"): Boolean;

    /// <summary>
    /// Couples the selected records to Dataverse records by matching field values.
    /// </summary>
    /// <param name="Context">The current record, its mapping and coupling.</param>
    /// <param name="SelectedRecordRef">The records selected on the page.</param>
    procedure MatchBasedCoupling(var Context: Codeunit "DVI Record Action Context"; var SelectedRecordRef: RecordRef);
}
