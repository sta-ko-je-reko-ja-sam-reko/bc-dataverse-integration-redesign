namespace DataverseIntegration.Core;

using Microsoft.Integration.Dataverse;
using Microsoft.Integration.SyncEngine;
using System.Threading;

codeunit 80014 "DVI Option Synch."
{
    Access = Internal;

    var
        OptionMappingCannotBeBidirectionalErr: Label 'Option mappings can only synchronize from Business Central to Dataverse or the other way, not in both directions.';
        NoFieldMappingsErr: Label 'There is no field mapping for the option mapping %1.', Comment = '%1 = mapping name';

    /// <summary>
    /// Runs the scheduled synchronization of an option mapping, such as Payment Terms, Shipment Method or Shipping Agent.
    /// </summary>
    /// <param name="IntegrationTableMapping">The option mapping.</param>
    internal procedure SynchronizeMapping(var IntegrationTableMapping: Record "Integration Table Mapping")
    var
        OriginalJobQueueEntry: Record "Job Queue Entry";
        LatestModifiedOn: array[2] of DateTime;
        PrevStatus: Option;
    begin
        if IntegrationTableMapping.Direction = IntegrationTableMapping.Direction::Bidirectional then
            Error(OptionMappingCannotBeBidirectionalErr);
        IntegrationTableMapping.SetOriginalJobQueueEntryOnHold(OriginalJobQueueEntry, PrevStatus);
        if IntegrationTableMapping.Direction = IntegrationTableMapping.Direction::ToIntegrationTable then
            LatestModifiedOn[2] := SynchToIntegrationTable(IntegrationTableMapping)
        else
            LatestModifiedOn[1] := SynchFromIntegrationTable(IntegrationTableMapping);
        if IntegrationTableMapping.Find() then begin
            IntegrationTableMapping.UpdateTableMappingModifiedOn(LatestModifiedOn);
            IntegrationTableMapping.SetOriginalJobQueueEntryStatus(OriginalJobQueueEntry, PrevStatus);
        end;
    end;

    local procedure SynchFromIntegrationTable(var IntegrationTableMapping: Record "Integration Table Mapping") LatestModifiedOn: DateTime
    var
        CRMOptionMapping: Record "CRM Option Mapping";
        CRMFullSynchReviewLine: Record "CRM Full Synch. Review Line";
        TempOptionValue: Record "DVI Option Value" temporary;
        OptionRecordSynch: Codeunit "DVI Option Record Synch.";
        OptionCouplingStore: Codeunit "DVI Option Coupling Store";
        JobLog: Codeunit "DVI Synch. Job Log";
        JobId: Guid;
        JobStartedAt: DateTime;
    begin
        JobStartedAt := CurrentDateTime();
        JobId := StartJob(IntegrationTableMapping, IntegrationTableMapping.Direction::FromIntegrationTable);
        if not OptionRecordSynch.Initialize(IntegrationTableMapping, JobId) then begin
            JobLog.FinishJob(JobId, StrSubstNo(NoFieldMappingsErr, IntegrationTableMapping.Name));
            exit(0DT);
        end;
        CRMFullSynchReviewLine.FullSynchStarted(IntegrationTableMapping, JobId, IntegrationTableMapping.Direction::FromIntegrationTable);
        OptionRecordSynch.GetOptions(TempOptionValue);
        TempOptionValue.SetFilter("Option Id", OptionIdFilterFromMapping(IntegrationTableMapping));
        if TempOptionValue.FindSet() then
            repeat
                if OptionCouplingStore.FindByOption(IntegrationTableMapping, TempOptionValue."Option Id", CRMOptionMapping) or not IntegrationTableMapping."Synch. Only Coupled Records" then begin
                    OptionRecordSynch.SetOption(TempOptionValue."Option Id", IntegrationTableMapping."Delete After Synchronization");
                    RunOption(OptionRecordSynch, JobId);
                    LatestModifiedOn := CurrentDateTime();
                end;
            until TempOptionValue.Next() = 0;
        JobLog.FinishJob(JobId, '');
        CRMFullSynchReviewLine.FullSynchFinished(IntegrationTableMapping, IntegrationTableMapping.Direction::FromIntegrationTable);
        if LatestModifiedOn > JobStartedAt then
            LatestModifiedOn := JobStartedAt;
    end;

    local procedure SynchToIntegrationTable(var IntegrationTableMapping: Record "Integration Table Mapping") LatestModifiedOn: DateTime
    var
        CRMOptionMapping: Record "CRM Option Mapping";
        CRMFullSynchReviewLine: Record "CRM Full Synch. Review Line";
        OptionRecordSynch: Codeunit "DVI Option Record Synch.";
        OptionCouplingStore: Codeunit "DVI Option Coupling Store";
        JobLog: Codeunit "DVI Synch. Job Log";
        IntegrationRecordSynch: Codeunit "Integration Record Synch.";
        SourceRecordRef: RecordRef;
        RecordModifiedOn: DateTime;
        JobId: Guid;
        JobStartedAt: DateTime;
    begin
        JobStartedAt := CurrentDateTime();
        JobId := StartJob(IntegrationTableMapping, IntegrationTableMapping.Direction::ToIntegrationTable);
        if not OptionRecordSynch.Initialize(IntegrationTableMapping, JobId) then begin
            JobLog.FinishJob(JobId, StrSubstNo(NoFieldMappingsErr, IntegrationTableMapping.Name));
            exit(0DT);
        end;
        CRMFullSynchReviewLine.FullSynchStarted(IntegrationTableMapping, JobId, IntegrationTableMapping.Direction::ToIntegrationTable);
        SourceRecordRef.Open(IntegrationTableMapping."Table ID");
        if IntegrationRecordSynch.FindModifiedLocalRecords(SourceRecordRef, IntegrationTableMapping.GetTableFilter(), IntegrationTableMapping) then
            repeat
                if OptionCouplingStore.FindByRecord(SourceRecordRef.RecordId(), CRMOptionMapping) or not IntegrationTableMapping."Synch. Only Coupled Records" then begin
                    OptionRecordSynch.SetLocalRecord(SourceRecordRef, IntegrationTableMapping."Delete After Synchronization");
                    RunOption(OptionRecordSynch, JobId);
                end;
                RecordModifiedOn := SourceRecordRef.Field(SourceRecordRef.SystemModifiedAtNo()).Value();
                if RecordModifiedOn > LatestModifiedOn then
                    LatestModifiedOn := RecordModifiedOn;
            until SourceRecordRef.Next() = 0;
        SourceRecordRef.Close();
        JobLog.FinishJob(JobId, '');
        CRMFullSynchReviewLine.FullSynchFinished(IntegrationTableMapping, IntegrationTableMapping.Direction::ToIntegrationTable);
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

    local procedure RunOption(var OptionRecordSynch: Codeunit "DVI Option Record Synch."; JobId: Guid)
    var
        JobLog: Codeunit "DVI Synch. Job Log";
        SynchAction: Enum "DVI Synch Action";
    begin
        Commit();
        if OptionRecordSynch.Run() then
            SynchAction := OptionRecordSynch.GetAction()
        else
            SynchAction := OptionRecordSynch.HandleRunError(GetLastErrorText());
        JobLog.Count(JobId, SynchAction);
    end;

    local procedure OptionIdFilterFromMapping(IntegrationTableMapping: Record "Integration Table Mapping"): Text
    var
        IntegrationRecordRef: RecordRef;
        OptionFieldRef: FieldRef;
        OptionIdFilter: Text;
        OptionCaption: Text;
        OptionOrdinals: Dictionary of [Text, Integer];
        ValueIndex: Integer;
    begin
        IntegrationRecordRef.Open(IntegrationTableMapping."Integration Table ID");
        IntegrationRecordRef.SetView(IntegrationTableMapping.GetIntegrationTableFilter());
        OptionFieldRef := IntegrationRecordRef.Field(IntegrationTableMapping."Integration Table UID Fld. No.");
        OptionIdFilter := OptionFieldRef.GetFilter();
        if OptionIdFilter = '' then
            exit('');
        for ValueIndex := 1 to OptionFieldRef.EnumValueCount() do
            if not OptionOrdinals.ContainsKey(OptionFieldRef.GetEnumValueCaption(ValueIndex)) then
                OptionOrdinals.Add(OptionFieldRef.GetEnumValueCaption(ValueIndex), OptionFieldRef.GetEnumValueOrdinal(ValueIndex));
        foreach OptionCaption in OptionIdFilter.Replace('(', '').Replace(')', '').Split('|') do
            if OptionOrdinals.ContainsKey(OptionCaption) then
                OptionIdFilter := OptionIdFilter.Replace(OptionCaption, Format(OptionOrdinals.Get(OptionCaption)));
        exit(OptionIdFilter);
    end;
}
