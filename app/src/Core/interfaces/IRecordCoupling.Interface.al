namespace DataverseIntegration.Core;

interface "DVI IRecordCoupling"
{
    /// <summary>
    /// Looks for an existing destination record to couple an uncoupled source record to, instead of inserting a new one.
    /// </summary>
    /// <param name="Context">The synchronization context.</param>
    /// <param name="SourceRecordRef">The uncoupled record being synchronized.</param>
    /// <param name="DestinationRecordRef">Receives the matching destination record when one is found.</param>
    /// <param name="DestinationIsDeleted">Set to true when the match exists but is marked as deleted.</param>
    /// <returns>True when a destination record was found.</returns>
    procedure FindUncoupledDestination(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef; var DestinationIsDeleted: Boolean): Boolean;

    /// <summary>
    /// Runs after a Business Central record and a Dataverse record were coupled by the coupling job.
    /// </summary>
    /// <param name="Context">The synchronization context.</param>
    /// <param name="LocalRecordRef">The Business Central record.</param>
    /// <param name="IntegrationRecordRef">The Dataverse record.</param>
    procedure AfterCouple(var Context: Codeunit "DVI Sync Context"; var LocalRecordRef: RecordRef; var IntegrationRecordRef: RecordRef);

    /// <summary>
    /// Runs before the coupling between a Business Central record and a Dataverse record is removed.
    /// </summary>
    /// <param name="Context">The synchronization context.</param>
    /// <param name="LocalRecordRef">The Business Central record.</param>
    /// <param name="IntegrationRecordRef">The Dataverse record.</param>
    procedure BeforeUncouple(var Context: Codeunit "DVI Sync Context"; var LocalRecordRef: RecordRef; var IntegrationRecordRef: RecordRef);

    /// <summary>
    /// Runs after the coupling between a Business Central record and a Dataverse record was removed.
    /// </summary>
    /// <param name="Context">The synchronization context.</param>
    /// <param name="LocalRecordRef">The Business Central record.</param>
    /// <param name="IntegrationRecordRef">The Dataverse record.</param>
    procedure AfterUncouple(var Context: Codeunit "DVI Sync Context"; var LocalRecordRef: RecordRef; var IntegrationRecordRef: RecordRef);

    /// <summary>
    /// Sets the filter that match-based coupling uses to find the Dataverse record matching one field of a Business Central record.
    /// </summary>
    /// <param name="Context">The synchronization context.</param>
    /// <param name="IntegrationRecordRef">The Dataverse table being searched.</param>
    /// <param name="MatchingIntegrationFieldRef">The Dataverse field that receives the filter.</param>
    /// <param name="LocalRecordRef">The Business Central record being coupled.</param>
    /// <param name="MatchingLocalFieldRef">The Business Central field whose value is matched.</param>
    /// <returns>True when this method set the filter; false applies the standard filter (exact or case-insensitive by the field mapping).</returns>
    procedure SetMatchingFilter(var Context: Codeunit "DVI Sync Context"; var IntegrationRecordRef: RecordRef; var MatchingIntegrationFieldRef: FieldRef; var LocalRecordRef: RecordRef; var MatchingLocalFieldRef: FieldRef): Boolean;

    /// <summary>
    /// Decides whether match-based coupling creates new Dataverse records for the Business Central records it could not match.
    /// </summary>
    /// <param name="Context">The synchronization context.</param>
    /// <returns>True to create the unmatched records in Dataverse.</returns>
    procedure CreateNewOnNoMatch(var Context: Codeunit "DVI Sync Context"): Boolean;
}
