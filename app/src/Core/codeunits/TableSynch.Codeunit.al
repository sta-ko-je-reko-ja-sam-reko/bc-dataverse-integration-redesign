namespace DataverseIntegration.Core;

using Microsoft.Integration.Dataverse;
using Microsoft.Integration.SyncEngine;
using System.Reflection;
using System.Threading;

codeunit 80006 "DVI Table Synch." implements "DVI ITableSynch"
{
    Access = Public;

    var
        ModuleNotEnabledErr: Label 'The connection for %1 is not enabled, so the integration table mapping %2 cannot be synchronized.', Comment = '%1 = integration module, %2 = mapping name';
        NoFieldMappingsErr: Label 'There are no enabled field mappings for the integration table mapping %1 in this direction.', Comment = '%1 = mapping name';

    procedure SynchronizeMapping(var IntegrationTableMapping: Record "Integration Table Mapping")
    var
        OriginalJobQueueEntry: Record "Job Queue Entry";
        "Field": Record "Field";
        MappingResolver: Codeunit "DVI Mapping Resolver";
        OptionSynch: Codeunit "DVI Option Synch.";
        Connection: Interface "DVI IConnection";
        ConnectionName: Text;
        LatestModifiedOn: array[2] of DateTime;
        PrevStatus: Option;
    begin
        Connection := MappingResolver.GetModule(IntegrationTableMapping);
        if not Connection.IsEnabled() then
            Error(ModuleNotEnabledErr, MappingResolver.GetModule(IntegrationTableMapping), IntegrationTableMapping.Name);
        ConnectionName := Connection.Open();
        if IntegrationTableMapping."Int. Table UID Field Type" = Field.Type::Option then
            OptionSynch.SynchronizeMapping(IntegrationTableMapping)
        else begin
            IntegrationTableMapping.SetOriginalJobQueueEntryOnHold(OriginalJobQueueEntry, PrevStatus);
            if IntegrationTableMapping.Direction in [IntegrationTableMapping.Direction::ToIntegrationTable, IntegrationTableMapping.Direction::Bidirectional] then
                LatestModifiedOn[2] := SynchToIntegrationTable(IntegrationTableMapping);
            if IntegrationTableMapping.Direction in [IntegrationTableMapping.Direction::FromIntegrationTable, IntegrationTableMapping.Direction::Bidirectional] then
                LatestModifiedOn[1] := SynchFromIntegrationTable(IntegrationTableMapping);
            if IntegrationTableMapping.Find() then begin
                IntegrationTableMapping.UpdateTableMappingModifiedOn(LatestModifiedOn);
                IntegrationTableMapping.SetOriginalJobQueueEntryStatus(OriginalJobQueueEntry, PrevStatus);
            end;
        end;
        Connection.Close(ConnectionName);
    end;

    /// <summary>
    /// Synchronizes one Dataverse record into Business Central through a switched mapping, outside the scheduled run.
    /// </summary>
    /// <param name="IntegrationTableMapping">The switched mapping.</param>
    /// <param name="IntegrationId">The ID of the Dataverse record.</param>
    internal procedure SynchronizeIntegrationRecord(IntegrationTableMapping: Record "Integration Table Mapping"; IntegrationId: Guid)
    var
        RecordSynch: Codeunit "DVI Record Synch.";
        JobLog: Codeunit "DVI Synch. Job Log";
        MappingResolver: Codeunit "DVI Mapping Resolver";
        SourceRecordRef: RecordRef;
        Connection: Interface "DVI IConnection";
        ConnectionName: Text;
        JobId: Guid;
    begin
        Connection := MappingResolver.GetModule(IntegrationTableMapping);
        if not Connection.IsEnabled() then
            Error(ModuleNotEnabledErr, MappingResolver.GetModule(IntegrationTableMapping), IntegrationTableMapping.Name);
        ConnectionName := Connection.Open();
        JobId := StartJob(IntegrationTableMapping, IntegrationTableMapping.Direction::FromIntegrationTable);
        if RecordSynch.Initialize(IntegrationTableMapping, JobId, false) then begin
            SourceRecordRef.Open(IntegrationTableMapping."Integration Table ID");
            SourceRecordRef.Field(IntegrationTableMapping."Integration Table UID Fld. No.").SetRange(IntegrationId);
            if SourceRecordRef.FindFirst() then
                SynchRecord(IntegrationTableMapping, RecordSynch, SourceRecordRef, JobId);
            JobLog.FinishJob(JobId, '');
        end else
            JobLog.FinishJob(JobId, StrSubstNo(NoFieldMappingsErr, IntegrationTableMapping.Name));
        Connection.Close(ConnectionName);
    end;

    local procedure SynchToIntegrationTable(var IntegrationTableMapping: Record "Integration Table Mapping") LatestModifiedOn: DateTime
    var
        CRMFullSynchReviewLine: Record "CRM Full Synch. Review Line";
        RecordSynch: Codeunit "DVI Record Synch.";
        JobLog: Codeunit "DVI Synch. Job Log";
        SourceRecordRef: RecordRef;
        FailedIds: Dictionary of [Guid, Boolean];
        ProcessedIds: Dictionary of [Guid, Boolean];
        SystemId: Guid;
        JobId: Guid;
        JobStartedAt: DateTime;
    begin
        JobStartedAt := CurrentDateTime();
        JobId := StartJob(IntegrationTableMapping, IntegrationTableMapping.Direction::ToIntegrationTable);
        if not RecordSynch.Initialize(IntegrationTableMapping, JobId, true) then begin
            JobLog.FinishJob(JobId, StrSubstNo(NoFieldMappingsErr, IntegrationTableMapping.Name));
            exit(0DT);
        end;
        CRMFullSynchReviewLine.FullSynchStarted(IntegrationTableMapping, JobId, IntegrationTableMapping.Direction::ToIntegrationTable);
        SourceRecordRef.Open(IntegrationTableMapping."Table ID");
        if FindFailedLocalRecords(IntegrationTableMapping, FailedIds) then
            foreach SystemId in FailedIds.Keys() do
                if SourceRecordRef.GetBySystemId(SystemId) then begin
                    ProcessedIds.Set(SystemId, true);
                    SynchSourceRecord(IntegrationTableMapping, RecordSynch, SourceRecordRef, JobId, LatestModifiedOn);
                end;
        if FindModifiedLocalRecords(IntegrationTableMapping, SourceRecordRef) then
            repeat
                SystemId := SourceRecordRef.Field(SourceRecordRef.SystemIdNo()).Value();
                if not ProcessedIds.ContainsKey(SystemId) then begin
                    ProcessedIds.Set(SystemId, true);
                    SynchSourceRecord(IntegrationTableMapping, RecordSynch, SourceRecordRef, JobId, LatestModifiedOn);
                end;
            until SourceRecordRef.Next() = 0;
        SynchIndirectlyChanged(IntegrationTableMapping, RecordSynch, JobId, ProcessedIds, LatestModifiedOn);
        SourceRecordRef.Close();
        JobLog.FinishJob(JobId, '');
        CRMFullSynchReviewLine.FullSynchFinished(IntegrationTableMapping, IntegrationTableMapping.Direction::ToIntegrationTable);
        if LatestModifiedOn > JobStartedAt then
            LatestModifiedOn := JobStartedAt;
    end;

    local procedure SynchFromIntegrationTable(var IntegrationTableMapping: Record "Integration Table Mapping") LatestModifiedOn: DateTime
    var
        CRMFullSynchReviewLine: Record "CRM Full Synch. Review Line";
        RecordSynch: Codeunit "DVI Record Synch.";
        JobLog: Codeunit "DVI Synch. Job Log";
        IntegrationRecordReader: Codeunit "DVI Integration Record Reader";
        TempSourceRecordRef: RecordRef;
        JobId: Guid;
        JobStartedAt: DateTime;
    begin
        JobStartedAt := CurrentDateTime();
        JobId := StartJob(IntegrationTableMapping, IntegrationTableMapping.Direction::FromIntegrationTable);
        if not RecordSynch.Initialize(IntegrationTableMapping, JobId, false) then begin
            JobLog.FinishJob(JobId, StrSubstNo(NoFieldMappingsErr, IntegrationTableMapping.Name));
            exit(0DT);
        end;
        CRMFullSynchReviewLine.FullSynchStarted(IntegrationTableMapping, JobId, IntegrationTableMapping.Direction::FromIntegrationTable);
        IntegrationRecordReader.LoadRecords(IntegrationTableMapping, TempSourceRecordRef);
        if TempSourceRecordRef.FindSet() then
            repeat
                SynchSourceRecord(IntegrationTableMapping, RecordSynch, TempSourceRecordRef, JobId, LatestModifiedOn);
            until TempSourceRecordRef.Next() = 0;
        TempSourceRecordRef.Close();
        JobLog.FinishJob(JobId, '');
        CRMFullSynchReviewLine.FullSynchFinished(IntegrationTableMapping, IntegrationTableMapping.Direction::FromIntegrationTable);
        if LatestModifiedOn > JobStartedAt then
            LatestModifiedOn := JobStartedAt;
    end;

    local procedure StartJob(IntegrationTableMapping: Record "Integration Table Mapping"; SynchDirection: Option): Guid
    var
        IntegrationSynchJob: Record "Integration Synch. Job";
        JobLog: Codeunit "DVI Synch. Job Log";
    begin
        exit(JobLog.StartJob(IntegrationTableMapping, SynchDirection, IntegrationSynchJob.Type::Synchronization));
    end;

    local procedure SynchSourceRecord(var IntegrationTableMapping: Record "Integration Table Mapping"; var RecordSynch: Codeunit "DVI Record Synch."; var SourceRecordRef: RecordRef; JobId: Guid; var LatestModifiedOn: DateTime)
    var
        RecordModifiedOn: DateTime;
    begin
        if not IsRecordFiltered(IntegrationTableMapping, SourceRecordRef, JobId) then
            SynchRecord(IntegrationTableMapping, RecordSynch, SourceRecordRef, JobId);
        RecordModifiedOn := GetModifiedOn(IntegrationTableMapping, SourceRecordRef);
        if RecordModifiedOn > LatestModifiedOn then
            LatestModifiedOn := RecordModifiedOn;
    end;

    local procedure IsRecordFiltered(var IntegrationTableMapping: Record "Integration Table Mapping"; var SourceRecordRef: RecordRef; JobId: Guid): Boolean
    var
        Context: Codeunit "DVI Sync Context";
        MappingResolver: Codeunit "DVI Mapping Resolver";
        RecordFilter: Interface "DVI IRecordFilter";
    begin
        Context.SetMapping(IntegrationTableMapping);
        Context.SetJobId(JobId);
        Context.SetToIntegrationTable(SourceRecordRef.Number() = IntegrationTableMapping."Table ID");
        RecordFilter := MappingResolver.GetHandler(IntegrationTableMapping);
        if RecordFilter.IgnoreRecord(Context, SourceRecordRef) then
            exit(true);
        if not IntegrationTableMapping."Synch. Only Coupled Records" then
            exit(false);
        exit(not IsCoupled(IntegrationTableMapping, SourceRecordRef));
    end;

    local procedure IsCoupled(IntegrationTableMapping: Record "Integration Table Mapping"; var SourceRecordRef: RecordRef): Boolean
    var
        CRMIntegrationRecord: Record "CRM Integration Record";
    begin
        if SourceRecordRef.Number() = IntegrationTableMapping."Table ID" then
            exit(CRMIntegrationRecord.IsIntegrationIdCoupled(SourceRecordRef.Field(SourceRecordRef.SystemIdNo()).Value(), SourceRecordRef.Number()));
        exit(CRMIntegrationRecord.IsCRMRecordRefCoupled(SourceRecordRef));
    end;

    /// <summary>
    /// Synchronizes one record through the record pipeline, counts the result on the job and processes the follow-ups the record queued.
    /// </summary>
    /// <param name="IntegrationTableMapping">The mapping being run.</param>
    /// <param name="RecordSynch">The record pipeline, initialized for the mapping and direction.</param>
    /// <param name="SourceRecordRef">The record to synchronize.</param>
    /// <param name="JobId">The synchronization job.</param>
    internal procedure SynchRecord(var IntegrationTableMapping: Record "Integration Table Mapping"; var RecordSynch: Codeunit "DVI Record Synch."; var SourceRecordRef: RecordRef; JobId: Guid)
    var
        TempFollowUpBuffer: Record "DVI Follow-up Buffer" temporary;
        CouplingStore: Codeunit "DVI Coupling Store";
        JobLog: Codeunit "DVI Synch. Job Log";
        SynchAction: Enum "DVI Synch Action";
    begin
        if CouplingStore.IsSkipped(IntegrationTableMapping, SourceRecordRef) then begin
            JobLog.Count(JobId, SynchAction::DVISkip);
            exit;
        end;
        RecordSynch.SetRecord(SourceRecordRef, IntegrationTableMapping."Delete After Synchronization", false);
        Commit();
        if RecordSynch.Run() then
            SynchAction := RecordSynch.GetAction()
        else
            SynchAction := RecordSynch.HandleRunError(GetLastErrorText());
        JobLog.Count(JobId, SynchAction);
        RecordSynch.TakeFollowUps(TempFollowUpBuffer);
        ProcessFollowUps(TempFollowUpBuffer);
    end;

    local procedure ProcessFollowUps(var TempFollowUpBuffer: Record "DVI Follow-up Buffer" temporary)
    var
        FollowUpProcessor: Codeunit "DVI Follow-up Processor";
    begin
        if TempFollowUpBuffer.IsEmpty() then
            exit;
        FollowUpProcessor.Process(TempFollowUpBuffer);
    end;

    local procedure FindFailedLocalRecords(IntegrationTableMapping: Record "Integration Table Mapping"; var FailedIds: Dictionary of [Guid, Boolean]): Boolean
    var
        CRMIntegrationRecord: Record "CRM Integration Record";
    begin
        if not FiltersAllLocalRecords(IntegrationTableMapping) then
            exit(false);
        CRMIntegrationRecord.SetLoadFields("Integration ID");
        CRMIntegrationRecord.SetRange("Table ID", IntegrationTableMapping."Table ID");
        CRMIntegrationRecord.SetRange(Skipped, false);
        CRMIntegrationRecord.SetRange("Last Synch. CRM Result", CRMIntegrationRecord."Last Synch. CRM Result"::Failure);
        if CRMIntegrationRecord.FindSet() then
            repeat
                if not FailedIds.ContainsKey(CRMIntegrationRecord."Integration ID") then
                    FailedIds.Add(CRMIntegrationRecord."Integration ID", true);
            until CRMIntegrationRecord.Next() = 0;
        exit(FailedIds.Count() > 0);
    end;

    local procedure FiltersAllLocalRecords(IntegrationTableMapping: Record "Integration Table Mapping"): Boolean
    var
        LocalRecordRef: RecordRef;
        PrimaryKeyRef: KeyRef;
        FieldIndex: Integer;
    begin
        LocalRecordRef.Open(IntegrationTableMapping."Table ID");
        LocalRecordRef.SetView(IntegrationTableMapping.GetTableFilter());
        if LocalRecordRef.Field(LocalRecordRef.SystemIdNo()).GetFilter() <> '' then
            exit(false);
        PrimaryKeyRef := LocalRecordRef.KeyIndex(1);
        for FieldIndex := 1 to PrimaryKeyRef.FieldCount() do
            if LocalRecordRef.Field(PrimaryKeyRef.FieldIndex(FieldIndex).Number()).GetFilter() = '' then
                exit(true);
        exit(false);
    end;

    local procedure SynchIndirectlyChanged(var IntegrationTableMapping: Record "Integration Table Mapping"; var RecordSynch: Codeunit "DVI Record Synch."; JobId: Guid; var ProcessedIds: Dictionary of [Guid, Boolean]; var LatestModifiedOn: DateTime)
    var
        Context: Codeunit "DVI Sync Context";
        MappingResolver: Codeunit "DVI Mapping Resolver";
        SourceRecordRef: RecordRef;
        ChangeDetection: Interface "DVI IChangeDetection";
        ChangedIds: List of [Guid];
        SystemId: Guid;
    begin
        Context.SetMapping(IntegrationTableMapping);
        Context.SetJobId(JobId);
        Context.SetToIntegrationTable(true);
        ChangeDetection := MappingResolver.GetHandler(IntegrationTableMapping);
        ChangeDetection.FindIndirectlyChanged(Context, IntegrationTableMapping."Synch. Modified On Filter", ChangedIds);
        if ChangedIds.Count() = 0 then
            exit;
        SourceRecordRef.Open(IntegrationTableMapping."Table ID");
        foreach SystemId in ChangedIds do
            if not ProcessedIds.ContainsKey(SystemId) then
                if SourceRecordRef.GetBySystemId(SystemId) then begin
                    ProcessedIds.Set(SystemId, true);
                    SynchSourceRecord(IntegrationTableMapping, RecordSynch, SourceRecordRef, JobId, LatestModifiedOn);
                end;
        SourceRecordRef.Close();
    end;

    local procedure FindModifiedLocalRecords(IntegrationTableMapping: Record "Integration Table Mapping"; var SourceRecordRef: RecordRef): Boolean
    var
        IntegrationRecordSynch: Codeunit "Integration Record Synch.";
    begin
        exit(IntegrationRecordSynch.FindModifiedLocalRecords(SourceRecordRef, IntegrationTableMapping.GetTableFilter(), IntegrationTableMapping));
    end;

    local procedure GetModifiedOn(IntegrationTableMapping: Record "Integration Table Mapping"; var RecordRef: RecordRef): DateTime
    begin
        if RecordRef.Number() = IntegrationTableMapping."Integration Table ID" then
            exit(RecordRef.Field(IntegrationTableMapping."Int. Tbl. Modified On Fld. No.").Value());
        exit(RecordRef.Field(RecordRef.SystemModifiedAtNo()).Value());
    end;
}
