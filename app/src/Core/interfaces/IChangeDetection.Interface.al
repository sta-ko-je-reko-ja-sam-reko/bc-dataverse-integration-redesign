namespace DataverseIntegration.Core;

interface "DVI IChangeDetection"
{
    /// <summary>
    /// Adds Business Central records that changed through related records only, such as a service order whose lines changed, to the records the scheduled synchronization sends to Dataverse.
    /// </summary>
    /// <param name="Context">The synchronization context; its mapping identifies the table.</param>
    /// <param name="ModifiedSince">The time of the last synchronization, or 0DT for all records.</param>
    /// <param name="LocalSystemIds">Receives the SystemIds of the additional records.</param>
    procedure FindIndirectlyChanged(var Context: Codeunit "DVI Sync Context"; ModifiedSince: DateTime; var LocalSystemIds: List of [Guid]);
}
