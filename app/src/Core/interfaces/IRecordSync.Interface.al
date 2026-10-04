namespace DataverseIntegration.Core;

interface "DVI IRecordSync"
{
    /// <summary>
    /// Runs before the field mappings are transferred from the source record to the destination record.
    /// </summary>
    /// <param name="Context">The synchronization context: mapping, job, direction and follow-up queue.</param>
    /// <param name="SourceRecordRef">The record being synchronized.</param>
    /// <param name="DestinationRecordRef">The record that receives the values; new and not yet inserted when the context reports an insert.</param>
    procedure BeforeTransferFields(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef);

    /// <summary>
    /// Runs after the field mappings were transferred. Sets AdditionalFieldsModified when it changed the destination itself.
    /// </summary>
    /// <param name="Context">The synchronization context.</param>
    /// <param name="SourceRecordRef">The record being synchronized.</param>
    /// <param name="DestinationRecordRef">The record that received the values.</param>
    /// <param name="AdditionalFieldsModified">Set to true when this method changed fields of the destination.</param>
    procedure AfterTransferFields(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef; var AdditionalFieldsModified: Boolean);

    /// <summary>
    /// Runs before a new destination record is inserted.
    /// </summary>
    /// <param name="Context">The synchronization context.</param>
    /// <param name="SourceRecordRef">The record being synchronized.</param>
    /// <param name="DestinationRecordRef">The record about to be inserted.</param>
    procedure BeforeInsert(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef);

    /// <summary>
    /// Runs after a new destination record was inserted, its template applied and the coupling created.
    /// </summary>
    /// <param name="Context">The synchronization context.</param>
    /// <param name="SourceRecordRef">The record being synchronized.</param>
    /// <param name="DestinationRecordRef">The inserted record.</param>
    procedure AfterInsert(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef);

    /// <summary>
    /// Runs before an existing destination record is modified.
    /// </summary>
    /// <param name="Context">The synchronization context.</param>
    /// <param name="SourceRecordRef">The record being synchronized.</param>
    /// <param name="DestinationRecordRef">The record about to be modified.</param>
    procedure BeforeModify(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef);

    /// <summary>
    /// Runs after an existing destination record was modified and its coupling updated.
    /// </summary>
    /// <param name="Context">The synchronization context.</param>
    /// <param name="SourceRecordRef">The record being synchronized.</param>
    /// <param name="DestinationRecordRef">The modified record.</param>
    procedure AfterModify(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef);

    /// <summary>
    /// Runs when the source record has no changes to transfer.
    /// </summary>
    /// <param name="Context">The synchronization context.</param>
    /// <param name="SourceRecordRef">The record being synchronized.</param>
    /// <param name="DestinationRecordRef">The coupled record.</param>
    procedure Unchanged(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef);
}
