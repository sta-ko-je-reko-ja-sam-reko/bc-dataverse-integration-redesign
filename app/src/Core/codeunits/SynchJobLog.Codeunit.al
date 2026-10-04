namespace DataverseIntegration.Core;

using Microsoft.Integration.SyncEngine;

codeunit 80009 "DVI Synch. Job Log"
{
    Access = Internal;

    /// <summary>
    /// Creates the integration synchronization job entry that logs one direction of one mapping, the way the standard engine does.
    /// </summary>
    /// <param name="IntegrationTableMapping">The mapping being synchronized.</param>
    /// <param name="SynchDirection">The direction of this job: ToIntegrationTable or FromIntegrationTable.</param>
    /// <param name="JobType">The job type: Synchronization, Uncoupling or Coupling.</param>
    /// <returns>The ID of the new job entry.</returns>
    internal procedure StartJob(IntegrationTableMapping: Record "Integration Table Mapping"; SynchDirection: Option; JobType: Option): Guid
    var
        IntegrationSynchJob: Record "Integration Synch. Job";
    begin
        IntegrationSynchJob.Init();
        IntegrationSynchJob.ID := CreateGuid();
        IntegrationSynchJob."Start Date/Time" := CurrentDateTime();
        IntegrationSynchJob."Integration Table Mapping Name" := IntegrationTableMapping.GetName();
        IntegrationSynchJob."Synch. Direction" := SynchDirection;
        IntegrationSynchJob."Job Queue Log Entry No." := IntegrationTableMapping.GetJobLogEntryNo();
        IntegrationSynchJob.Type := JobType;
        IntegrationSynchJob.Insert(true);
        Commit();
        exit(IntegrationSynchJob.ID);
    end;

    /// <summary>
    /// Sets the finish time and the final message of a job entry.
    /// </summary>
    /// <param name="JobId">The job entry.</param>
    /// <param name="FinalMessage">The message to store; empty keeps the current one.</param>
    internal procedure FinishJob(JobId: Guid; FinalMessage: Text)
    var
        IntegrationSynchJob: Record "Integration Synch. Job";
    begin
        if not IntegrationSynchJob.Get(JobId) then
            exit;
        if FinalMessage <> '' then
            IntegrationSynchJob.Message := CopyStr(FinalMessage, 1, MaxStrLen(IntegrationSynchJob.Message));
        IntegrationSynchJob."Finish Date/Time" := CurrentDateTime();
        IntegrationSynchJob.Modify(true);
        Commit();
    end;

    /// <summary>
    /// Adds one to the counter of a job entry that matches the action.
    /// </summary>
    /// <param name="JobId">The job entry.</param>
    /// <param name="SynchAction">The action taken for one record.</param>
    internal procedure Count(JobId: Guid; SynchAction: Enum "DVI Synch Action")
    var
        IntegrationSynchJob: Record "Integration Synch. Job";
    begin
        if IsNullGuid(JobId) then
            exit;
        if not IntegrationSynchJob.Get(JobId) then
            exit;
        case SynchAction of
            SynchAction::DVIInsert:
                IntegrationSynchJob.Inserted += 1;
            SynchAction::DVIModify, SynchAction::DVIForceModify:
                IntegrationSynchJob.Modified += 1;
            SynchAction::DVIIgnoreUnchanged:
                IntegrationSynchJob.Unchanged += 1;
            SynchAction::DVISkip:
                IntegrationSynchJob.Skipped += 1;
            SynchAction::DVIFail:
                IntegrationSynchJob.Failed += 1;
            SynchAction::DVIDelete:
                IntegrationSynchJob.Deleted += 1;
            SynchAction::DVIUncouple:
                IntegrationSynchJob.Uncoupled += 1;
            SynchAction::DVICouple:
                IntegrationSynchJob.Coupled += 1;
            else
                exit;
        end;
        IntegrationSynchJob.Modify(false);
        Commit();
    end;

    /// <summary>
    /// Logs an error for one record of a job.
    /// </summary>
    /// <param name="JobId">The job entry.</param>
    /// <param name="SourceRecordRef">The record being synchronized.</param>
    /// <param name="DestinationRecordRef">The destination record, or a closed RecordRef when there is none.</param>
    /// <param name="ErrorMessage">The error text.</param>
    internal procedure LogError(JobId: Guid; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef; ErrorMessage: Text)
    var
        IntegrationSynchJobErrors: Record "Integration Synch. Job Errors";
        SourceRecordId: RecordId;
        DestinationRecordId: RecordId;
    begin
        if SourceRecordRef.Number() <> 0 then
            SourceRecordId := SourceRecordRef.RecordId();
        if DestinationRecordRef.Number() <> 0 then
            DestinationRecordId := DestinationRecordRef.RecordId();
        IntegrationSynchJobErrors.LogSynchError(JobId, SourceRecordId, DestinationRecordId, ErrorMessage);
    end;
}
