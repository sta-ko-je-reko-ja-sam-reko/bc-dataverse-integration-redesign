namespace DataverseIntegration.Core;

interface "DVI IRecordFilter"
{
    /// <summary>
    /// Decides whether a record found by the scheduled synchronization is left out.
    /// </summary>
    /// <param name="Context">The synchronization context.</param>
    /// <param name="SourceRecordRef">The candidate record.</param>
    /// <returns>True to leave the record out of this synchronization.</returns>
    procedure IgnoreRecord(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef): Boolean;
}
