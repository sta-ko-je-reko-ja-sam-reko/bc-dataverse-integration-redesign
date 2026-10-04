namespace DataverseIntegration.Core;

interface "DVI IConflictPolicy"
{
    /// <summary>
    /// Resolves an update conflict: both records changed since the last synchronization and a bidirectional field differs.
    /// </summary>
    /// <param name="Context">The synchronization context.</param>
    /// <param name="SourceRecordRef">The record being synchronized.</param>
    /// <param name="DestinationRecordRef">The coupled record that was changed as well.</param>
    /// <param name="SkipRecord">Set to true to skip the record instead of overwriting the destination.</param>
    /// <returns>True when the conflict is resolved; false makes the record fail with a conflict error.</returns>
    procedure ResolveUpdateConflict(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef; var SkipRecord: Boolean): Boolean;

    /// <summary>
    /// Resolves a deletion conflict: the source record is coupled to a record that no longer exists.
    /// </summary>
    /// <param name="Context">The synchronization context.</param>
    /// <param name="SourceRecordRef">The record being synchronized.</param>
    /// <returns>What the pipeline does with the record.</returns>
    procedure ResolveDeletionConflict(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef): Enum "DVI Deletion Outcome";
}
