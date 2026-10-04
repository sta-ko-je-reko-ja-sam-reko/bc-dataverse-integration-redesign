namespace DataverseIntegration.Core;

using System.Reflection;

codeunit 80036 "DVI Record Lookup"
{
    Access = Internal;

    var
        NoLookupPageErr: Label 'There is no lookup page for the table %1.', Comment = '%1 = table caption';

    /// <summary>
    /// Lets the user pick a record of a table through the table's lookup page.
    /// </summary>
    /// <param name="TableId">The table.</param>
    /// <param name="SelectedRecordRef">Receives the picked record.</param>
    /// <returns>True when the user picked a record.</returns>
    internal procedure LookupRecord(TableId: Integer; var SelectedRecordRef: RecordRef): Boolean
    var
        TableMetadata: Record "Table Metadata";
        RecordVariant: Variant;
    begin
        TableMetadata.SetLoadFields(Caption, LookupPageID);
        TableMetadata.Get(TableId);
        if TableMetadata.LookupPageID = 0 then
            Error(NoLookupPageErr, TableMetadata.Caption);
        SelectedRecordRef.Open(TableId);
        RecordVariant := SelectedRecordRef;
        if Page.RunModal(TableMetadata.LookupPageID, RecordVariant) <> Action::LookupOK then
            exit(false);
        SelectedRecordRef := RecordVariant;
        exit(true);
    end;
}
