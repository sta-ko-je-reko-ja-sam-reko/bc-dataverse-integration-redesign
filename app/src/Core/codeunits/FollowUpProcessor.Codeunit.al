namespace DataverseIntegration.Core;

using Microsoft.Integration.SyncEngine;

codeunit 80024 "DVI Follow-up Processor"
{
    Access = Internal;

    /// <summary>
    /// Synchronizes the dependent records queued by a step, one job per mapping and direction, after the queuing record's own transaction; then runs the queued completion steps.
    /// </summary>
    /// <param name="TempFollowUpBuffer">The queued follow-ups; processed and emptied.</param>
    internal procedure Process(var TempFollowUpBuffer: Record "DVI Follow-up Buffer" temporary)
    var
        TempGroupFollowUpBuffer: Record "DVI Follow-up Buffer" temporary;
    begin
        TempFollowUpBuffer.Reset();
        TempFollowUpBuffer.SetRange(Completion, false);
        while TempFollowUpBuffer.FindFirst() do begin
            TempGroupFollowUpBuffer.Copy(TempFollowUpBuffer, true);
            TempGroupFollowUpBuffer.SetRange("Mapping Name", TempFollowUpBuffer."Mapping Name");
            TempGroupFollowUpBuffer.SetRange("To Integration Table", TempFollowUpBuffer."To Integration Table");
            ProcessGroup(TempGroupFollowUpBuffer);
            TempGroupFollowUpBuffer.DeleteAll(false);
        end;
        ProcessCompletions(TempFollowUpBuffer);
    end;

    local procedure ProcessCompletions(var TempFollowUpBuffer: Record "DVI Follow-up Buffer" temporary)
    var
        CompletionRunner: Codeunit "DVI Completion Runner";
    begin
        TempFollowUpBuffer.Reset();
        TempFollowUpBuffer.SetRange(Completion, true);
        if TempFollowUpBuffer.FindSet() then
            repeat
                Clear(CompletionRunner);
                CompletionRunner.Process(TempFollowUpBuffer);
            until TempFollowUpBuffer.Next() = 0;
        TempFollowUpBuffer.DeleteAll(false);
        TempFollowUpBuffer.Reset();
    end;

    local procedure ProcessGroup(var TempGroupFollowUpBuffer: Record "DVI Follow-up Buffer" temporary)
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        IntegrationSynchJob: Record "Integration Synch. Job";
        RecordSynch: Codeunit "DVI Record Synch.";
        TableSynch: Codeunit "DVI Table Synch.";
        JobLog: Codeunit "DVI Synch. Job Log";
        SourceRecordRef: RecordRef;
        JobId: Guid;
        SynchDirection: Option Bidirectional,ToIntegrationTable,FromIntegrationTable;
    begin
        if not TempGroupFollowUpBuffer.FindSet() then
            exit;
        if not IntegrationTableMapping.Get(TempGroupFollowUpBuffer."Mapping Name") then
            exit;
        if TempGroupFollowUpBuffer."To Integration Table" then
            SynchDirection := SynchDirection::ToIntegrationTable
        else
            SynchDirection := SynchDirection::FromIntegrationTable;
        JobId := JobLog.StartJob(IntegrationTableMapping, SynchDirection, IntegrationSynchJob.Type::Synchronization);
        if RecordSynch.Initialize(IntegrationTableMapping, JobId, TempGroupFollowUpBuffer."To Integration Table") then
            repeat
                if FindSourceRecord(IntegrationTableMapping, TempGroupFollowUpBuffer, SourceRecordRef) then
                    TableSynch.SynchRecord(IntegrationTableMapping, RecordSynch, SourceRecordRef, JobId);
                SourceRecordRef.Close();
            until TempGroupFollowUpBuffer.Next() = 0;
        JobLog.FinishJob(JobId, '');
    end;

    local procedure FindSourceRecord(IntegrationTableMapping: Record "Integration Table Mapping"; var TempFollowUpBuffer: Record "DVI Follow-up Buffer" temporary; var SourceRecordRef: RecordRef): Boolean
    begin
        if TempFollowUpBuffer."To Integration Table" then begin
            SourceRecordRef.Open(IntegrationTableMapping."Table ID");
            exit(SourceRecordRef.GetBySystemId(TempFollowUpBuffer."Source System Id"));
        end;
        SourceRecordRef.Open(IntegrationTableMapping."Integration Table ID");
        SourceRecordRef.Field(IntegrationTableMapping."Integration Table UID Fld. No.").SetRange(TempFollowUpBuffer."Source System Id");
        exit(SourceRecordRef.FindFirst());
    end;
}
