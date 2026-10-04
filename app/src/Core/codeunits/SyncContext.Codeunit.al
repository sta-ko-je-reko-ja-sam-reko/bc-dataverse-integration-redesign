namespace DataverseIntegration.Core;

using Microsoft.Integration.SyncEngine;

codeunit 80003 "DVI Sync Context"
{
    Access = Public;

    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        TempFollowUpBuffer: Record "DVI Follow-up Buffer" temporary;
        JobId: Guid;
        ToIntegrationTable: Boolean;
        DestinationInserted: Boolean;

    /// <summary>
    /// Sets the integration table mapping the record is synchronized through.
    /// </summary>
    /// <param name="NewIntegrationTableMapping">The mapping.</param>
    procedure SetMapping(NewIntegrationTableMapping: Record "Integration Table Mapping")
    begin
        IntegrationTableMapping := NewIntegrationTableMapping;
    end;

    /// <summary>
    /// Returns the integration table mapping the record is synchronized through.
    /// </summary>
    /// <param name="CurrentIntegrationTableMapping">Receives the mapping.</param>
    procedure GetMapping(var CurrentIntegrationTableMapping: Record "Integration Table Mapping")
    begin
        CurrentIntegrationTableMapping := IntegrationTableMapping;
    end;

    /// <summary>
    /// Returns the name of the integration table mapping.
    /// </summary>
    /// <returns>The mapping name.</returns>
    procedure GetMappingName(): Code[20]
    begin
        exit(IntegrationTableMapping.Name);
    end;

    /// <summary>
    /// Sets the ID of the integration synchronization job that logs this run.
    /// </summary>
    /// <param name="NewJobId">The job ID.</param>
    procedure SetJobId(NewJobId: Guid)
    begin
        JobId := NewJobId;
    end;

    /// <summary>
    /// Returns the ID of the integration synchronization job that logs this run.
    /// </summary>
    /// <returns>The job ID; a null GUID outside a job.</returns>
    procedure GetJobId(): Guid
    begin
        exit(JobId);
    end;

    /// <summary>
    /// Sets the direction of the current record: from Business Central to Dataverse, or the other way.
    /// </summary>
    /// <param name="NewToIntegrationTable">True when the record goes from Business Central to Dataverse.</param>
    procedure SetToIntegrationTable(NewToIntegrationTable: Boolean)
    begin
        ToIntegrationTable := NewToIntegrationTable;
    end;

    /// <summary>
    /// Returns whether the current record goes from Business Central to Dataverse.
    /// </summary>
    /// <returns>True for Business Central to Dataverse; false for Dataverse to Business Central.</returns>
    procedure IsToIntegrationTable(): Boolean
    begin
        exit(ToIntegrationTable);
    end;

    /// <summary>
    /// Sets whether the destination record of the current record is new.
    /// </summary>
    /// <param name="NewDestinationInserted">True when the destination record is inserted rather than modified.</param>
    procedure SetDestinationInserted(NewDestinationInserted: Boolean)
    begin
        DestinationInserted := NewDestinationInserted;
    end;

    /// <summary>
    /// Returns whether the destination record of the current record is new.
    /// </summary>
    /// <returns>True when the destination record is inserted rather than modified.</returns>
    procedure IsDestinationInserted(): Boolean
    begin
        exit(DestinationInserted);
    end;

    /// <summary>
    /// Queues a dependent record for synchronization after the current record's transaction, instead of re-entering the pipeline from a step.
    /// </summary>
    /// <param name="MappingName">The integration table mapping that synchronizes the dependent record.</param>
    /// <param name="SourceSystemId">The SystemId of the dependent record on the source side.</param>
    /// <param name="FollowUpToIntegrationTable">True when the dependent record goes from Business Central to Dataverse.</param>
    procedure AddFollowUp(MappingName: Code[20]; SourceSystemId: Guid; FollowUpToIntegrationTable: Boolean)
    var
        EntryNo: Integer;
    begin
        TempFollowUpBuffer.Reset();
        if TempFollowUpBuffer.FindLast() then
            EntryNo := TempFollowUpBuffer."Entry No.";
        TempFollowUpBuffer.Init();
        TempFollowUpBuffer."Entry No." := EntryNo + 1;
        TempFollowUpBuffer."Mapping Name" := MappingName;
        TempFollowUpBuffer."Source System Id" := SourceSystemId;
        TempFollowUpBuffer."To Integration Table" := FollowUpToIntegrationTable;
        TempFollowUpBuffer.Insert(false);
    end;

    /// <summary>
    /// Queues a record the current record depends on, such as a product a price needs. Unlike a follow-up, it is synchronized even when the current record fails, so the next run can succeed.
    /// </summary>
    /// <param name="MappingName">The integration table mapping that synchronizes the prerequisite.</param>
    /// <param name="SourceSystemId">The SystemId of the prerequisite on the source side.</param>
    /// <param name="PrerequisiteToIntegrationTable">True when the prerequisite goes from Business Central to Dataverse.</param>
    procedure AddPrerequisite(MappingName: Code[20]; SourceSystemId: Guid; PrerequisiteToIntegrationTable: Boolean)
    begin
        AddFollowUp(MappingName, SourceSystemId, PrerequisiteToIntegrationTable);
        TempFollowUpBuffer."Keep On Failure" := true;
        TempFollowUpBuffer.Modify(false);
    end;

    /// <summary>
    /// Removes the follow-ups of a record that failed, keeping its prerequisites.
    /// </summary>
    procedure DropFollowUpsAfterFailure()
    begin
        TempFollowUpBuffer.Reset();
        TempFollowUpBuffer.SetRange("Keep On Failure", false);
        TempFollowUpBuffer.DeleteAll(false);
        TempFollowUpBuffer.Reset();
    end;

    /// <summary>
    /// Copies the queued follow-ups.
    /// </summary>
    /// <param name="TempTargetFollowUpBuffer">Receives the queued follow-ups.</param>
    procedure GetFollowUps(var TempTargetFollowUpBuffer: Record "DVI Follow-up Buffer" temporary)
    var
        EntryNo: Integer;
    begin
        TempTargetFollowUpBuffer.Reset();
        if TempTargetFollowUpBuffer.FindLast() then
            EntryNo := TempTargetFollowUpBuffer."Entry No.";
        TempFollowUpBuffer.Reset();
        if TempFollowUpBuffer.FindSet() then
            repeat
                EntryNo += 1;
                TempTargetFollowUpBuffer := TempFollowUpBuffer;
                TempTargetFollowUpBuffer."Entry No." := EntryNo;
                TempTargetFollowUpBuffer.Insert(false);
            until TempFollowUpBuffer.Next() = 0;
    end;

    /// <summary>
    /// Removes all queued follow-ups.
    /// </summary>
    procedure ClearFollowUps()
    begin
        TempFollowUpBuffer.Reset();
        TempFollowUpBuffer.DeleteAll(false);
    end;
}
