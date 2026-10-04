namespace DataverseIntegration.Core;

interface "DVI ICreateAction"
{
    /// <summary>
    /// Returns whether the page offers to create the selected records in Dataverse.
    /// </summary>
    /// <param name="Context">The current record, its mapping and coupling.</param>
    /// <returns>True to show the action.</returns>
    procedure CanCreateInDataverse(var Context: Codeunit "DVI Record Action Context"): Boolean;

    /// <summary>
    /// Creates the selected, uncoupled records in Dataverse and couples them.
    /// </summary>
    /// <param name="Context">The current record, its mapping and coupling.</param>
    /// <param name="SelectedRecordRef">The records selected on the page.</param>
    procedure CreateInDataverse(var Context: Codeunit "DVI Record Action Context"; var SelectedRecordRef: RecordRef);

    /// <summary>
    /// Returns whether the page offers to create Business Central records from Dataverse records.
    /// </summary>
    /// <param name="Context">The current record and its mapping.</param>
    /// <returns>True to show the action.</returns>
    procedure CanCreateInBusinessCentral(var Context: Codeunit "DVI Record Action Context"): Boolean;

    /// <summary>
    /// Lets the user pick Dataverse records and creates Business Central records from them.
    /// </summary>
    /// <param name="Context">The current record and its mapping.</param>
    procedure CreateInBusinessCentral(var Context: Codeunit "DVI Record Action Context");
}
