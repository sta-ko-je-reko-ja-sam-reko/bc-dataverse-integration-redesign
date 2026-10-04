namespace DataverseIntegration.Core;

interface "DVI IRecordCompletion"
{
    /// <summary>
    /// Finishes a record after the follow-ups it queued were synchronized, such as totals of a document after its lines. Runs only when the record queued a completion with AddCompletion; the coupling is re-stamped afterwards, so the changes made here are not seen as edits.
    /// </summary>
    /// <param name="Context">The synchronization context: mapping, direction, job, and GetSynchAction for what happened to the record.</param>
    /// <param name="LocalRecordRef">The Business Central record.</param>
    /// <param name="IntegrationRecordRef">The coupled Dataverse record.</param>
    procedure Complete(var Context: Codeunit "DVI Sync Context"; var LocalRecordRef: RecordRef; var IntegrationRecordRef: RecordRef);
}
