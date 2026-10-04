namespace DataverseIntegration.Core;

using Microsoft.Integration.Dataverse;
using Microsoft.Integration.SyncEngine;

codeunit 80015 "DVI Coupling Runner" implements "DVI ICouplingRunner"
{
    Access = Public;

    var
        ModuleNotEnabledErr: Label 'The connection for %1 is not enabled, so the records of the integration table mapping %2 cannot be coupled or uncoupled.', Comment = '%1 = integration module, %2 = mapping name';
        NoMatchingCriteriaErr: Label 'The integration table mapping %1 has no field mappings marked for match-based coupling.', Comment = '%1 = mapping name';
        NoMatchFoundErr: Label '%1 records could not be coupled because no single uncoupled Dataverse record matched them.', Comment = '%1 = number of records';

    procedure CoupleMapping(var IntegrationTableMapping: Record "Integration Table Mapping")
    var
        IntegrationSynchJob: Record "Integration Synch. Job";
        JobLog: Codeunit "DVI Synch. Job Log";
        JobId: Guid;
        ConnectionName: Text;
    begin
        ConnectionName := OpenConnection(IntegrationTableMapping);
        JobId := JobLog.StartJob(IntegrationTableMapping, IntegrationTableMapping.Direction, IntegrationSynchJob.Type::Coupling);
        StartFullSynchReview(IntegrationTableMapping, JobId);
        CoupleRecords(IntegrationTableMapping, JobId);
        JobLog.FinishJob(JobId, '');
        FinishFullSynchReview(IntegrationTableMapping);
        CloseConnection(IntegrationTableMapping, ConnectionName);
    end;

    procedure UncoupleMapping(var IntegrationTableMapping: Record "Integration Table Mapping")
    var
        IntegrationSynchJob: Record "Integration Synch. Job";
        JobLog: Codeunit "DVI Synch. Job Log";
        JobId: Guid;
        ConnectionName: Text;
    begin
        ConnectionName := OpenConnection(IntegrationTableMapping);
        JobId := JobLog.StartJob(IntegrationTableMapping, IntegrationTableMapping.Direction, IntegrationSynchJob.Type::Uncoupling);
        UncoupleRecords(IntegrationTableMapping, JobId);
        JobLog.FinishJob(JobId, '');
        CloseConnection(IntegrationTableMapping, ConnectionName);
    end;

    local procedure CoupleRecords(var IntegrationTableMapping: Record "Integration Table Mapping"; JobId: Guid)
    var
        TempMatchingFieldMapping: Record "Integration Field Mapping" temporary;
        CRMIntegrationRecord: Record "CRM Integration Record";
        CouplingAction: Codeunit "DVI Coupling Action";
        JobLog: Codeunit "DVI Synch. Job Log";
        LocalRecordRef: RecordRef;
        EmptyRecordRef: RecordRef;
        MatchPriorities: List of [Integer];
        UnmatchedIds: List of [Guid];
        CoupledIds: List of [Guid];
        CoupledIntegrationIds: List of [Guid];
    begin
        if not LoadMatchingFieldMappings(IntegrationTableMapping, TempMatchingFieldMapping, MatchPriorities) then begin
            JobLog.LogError(JobId, EmptyRecordRef, EmptyRecordRef, StrSubstNo(NoMatchingCriteriaErr, IntegrationTableMapping.GetUserFriendlyMappingName()));
            exit;
        end;
        CouplingAction.Initialize(IntegrationTableMapping, JobId);
        LocalRecordRef.Open(IntegrationTableMapping."Table ID");
        IntegrationTableMapping.SetRecordRefFilter(LocalRecordRef);
        if LocalRecordRef.FindSet() then
            repeat
                if not CRMIntegrationRecord.IsIntegrationIdCoupled(LocalRecordRef.Field(LocalRecordRef.SystemIdNo()).Value(), LocalRecordRef.Number()) then
                    MatchAndCouple(IntegrationTableMapping, CouplingAction, TempMatchingFieldMapping, MatchPriorities, LocalRecordRef, JobId,
                      UnmatchedIds, CoupledIds, CoupledIntegrationIds);
            until LocalRecordRef.Next() = 0;
        HandleUnmatched(IntegrationTableMapping, UnmatchedIds, JobId);
        if IntegrationTableMapping."Synch. After Bulk Coupling" then
            SynchronizeCoupled(IntegrationTableMapping, CoupledIds, CoupledIntegrationIds);
    end;

    local procedure MatchAndCouple(IntegrationTableMapping: Record "Integration Table Mapping"; var CouplingAction: Codeunit "DVI Coupling Action"; var TempMatchingFieldMapping: Record "Integration Field Mapping" temporary; MatchPriorities: List of [Integer]; var LocalRecordRef: RecordRef; JobId: Guid; var UnmatchedIds: List of [Guid]; var CoupledIds: List of [Guid]; var CoupledIntegrationIds: List of [Guid])
    var
        IntegrationRecordRef: RecordRef;
        LocalSystemId: Guid;
        MatchPriority: Integer;
    begin
        LocalSystemId := LocalRecordRef.Field(LocalRecordRef.SystemIdNo()).Value();
        foreach MatchPriority in MatchPriorities do
            if FindSingleMatch(IntegrationTableMapping, TempMatchingFieldMapping, MatchPriority, LocalRecordRef, JobId, IntegrationRecordRef) then
                if CouplePair(CouplingAction, LocalRecordRef, IntegrationRecordRef, JobId) then begin
                    CoupledIds.Add(LocalSystemId);
                    CoupledIntegrationIds.Add(IntegrationRecordRef.Field(IntegrationTableMapping."Integration Table UID Fld. No.").Value());
                    exit;
                end;
        UnmatchedIds.Add(LocalSystemId);
    end;

    local procedure FindSingleMatch(IntegrationTableMapping: Record "Integration Table Mapping"; var TempMatchingFieldMapping: Record "Integration Field Mapping" temporary; MatchPriority: Integer; var LocalRecordRef: RecordRef; JobId: Guid; var IntegrationRecordRef: RecordRef): Boolean
    var
        CRMIntegrationRecord: Record "CRM Integration Record";
        Context: Codeunit "DVI Sync Context";
        MappingResolver: Codeunit "DVI Mapping Resolver";
        IntegrationFieldRef: FieldRef;
        LocalFieldRef: FieldRef;
        RecordCoupling: Interface "DVI IRecordCoupling";
        FilterCount: Integer;
    begin
        Context.SetMapping(IntegrationTableMapping);
        Context.SetJobId(JobId);
        RecordCoupling := MappingResolver.GetHandler(IntegrationTableMapping);
        IntegrationRecordRef.Close();
        IntegrationRecordRef.Open(IntegrationTableMapping."Integration Table ID");
        IntegrationTableMapping.SetIntRecordRefFilter(IntegrationRecordRef);
        TempMatchingFieldMapping.SetRange("Match Priority", MatchPriority);
        if TempMatchingFieldMapping.FindSet() then
            repeat
                IntegrationFieldRef := IntegrationRecordRef.Field(TempMatchingFieldMapping."Integration Table Field No.");
                LocalFieldRef := LocalRecordRef.Field(TempMatchingFieldMapping."Field No.");
                if RecordCoupling.SetMatchingFilter(Context, IntegrationRecordRef, IntegrationFieldRef, LocalRecordRef, LocalFieldRef) then
                    FilterCount += 1
                else
                    if SetStandardMatchingFilter(TempMatchingFieldMapping, IntegrationFieldRef, LocalFieldRef) then
                        FilterCount += 1;
            until TempMatchingFieldMapping.Next() = 0;
        if FilterCount = 0 then
            exit(false);
        if IntegrationRecordRef.Count() <> 1 then
            exit(false);
        IntegrationRecordRef.FindFirst();
        exit(not CRMIntegrationRecord.IsCRMRecordRefCoupled(IntegrationRecordRef));
    end;

    local procedure SetStandardMatchingFilter(var TempMatchingFieldMapping: Record "Integration Field Mapping" temporary; var IntegrationFieldRef: FieldRef; var LocalFieldRef: FieldRef): Boolean
    var
        MatchValue: Text;
    begin
        if not (LocalFieldRef.Type() in [FieldType::Code, FieldType::Text]) then begin
            IntegrationFieldRef.SetRange(LocalFieldRef.Value());
            exit(true);
        end;
        MatchValue := Format(LocalFieldRef.Value());
        if MatchValue = '' then
            exit(false);
        if TempMatchingFieldMapping."Case-Sensitive Matching" then
            IntegrationFieldRef.SetRange(LocalFieldRef.Value())
        else
            IntegrationFieldRef.SetFilter('''@' + MatchValue.Replace('''', '''''') + '''');
        exit(true);
    end;

    local procedure CouplePair(var CouplingAction: Codeunit "DVI Coupling Action"; var LocalRecordRef: RecordRef; var IntegrationRecordRef: RecordRef; JobId: Guid): Boolean
    var
        JobLog: Codeunit "DVI Synch. Job Log";
        SynchAction: Enum "DVI Synch Action";
    begin
        CouplingAction.SetPair(LocalRecordRef, IntegrationRecordRef, true);
        Commit();
        if not CouplingAction.Run() then
            CouplingAction.HandleRunError(GetLastErrorText());
        SynchAction := CouplingAction.GetAction();
        JobLog.Count(JobId, SynchAction);
        exit(SynchAction = SynchAction::DVICouple);
    end;

    local procedure HandleUnmatched(IntegrationTableMapping: Record "Integration Table Mapping"; UnmatchedIds: List of [Guid]; JobId: Guid)
    var
        CRMIntegrationManagement: Codeunit "CRM Integration Management";
        Context: Codeunit "DVI Sync Context";
        MappingResolver: Codeunit "DVI Mapping Resolver";
        JobLog: Codeunit "DVI Synch. Job Log";
        EmptyRecordRef: RecordRef;
        RecordCoupling: Interface "DVI IRecordCoupling";
        UnmatchedById: Dictionary of [Code[20], List of [Guid]];
        Counter: Integer;
    begin
        if UnmatchedIds.Count() = 0 then
            exit;
        Context.SetMapping(IntegrationTableMapping);
        Context.SetJobId(JobId);
        RecordCoupling := MappingResolver.GetHandler(IntegrationTableMapping);
        if RecordCoupling.CreateNewOnNoMatch(Context) then begin
            UnmatchedById.Add(IntegrationTableMapping.Name, UnmatchedIds);
            CRMIntegrationManagement.CreateNewRecordsInCRM(UnmatchedById);
            exit;
        end;
        for Counter := 1 to UnmatchedIds.Count() do
            JobLog.Count(JobId, Enum::"DVI Synch Action"::DVIFail);
        JobLog.LogError(JobId, EmptyRecordRef, EmptyRecordRef, StrSubstNo(NoMatchFoundErr, UnmatchedIds.Count()));
    end;

    local procedure SynchronizeCoupled(IntegrationTableMapping: Record "Integration Table Mapping"; CoupledIds: List of [Guid]; CoupledIntegrationIds: List of [Guid])
    var
        CRMIntegrationManagement: Codeunit "CRM Integration Management";
        Direction: Integer;
    begin
        if CoupledIds.Count() = 0 then
            exit;
        Direction := IntegrationTableMapping.Direction;
        if IntegrationTableMapping.Direction = IntegrationTableMapping.Direction::Bidirectional then
            case IntegrationTableMapping."Update-Conflict Resolution" of
                IntegrationTableMapping."Update-Conflict Resolution"::"Get Update from Integration":
                    Direction := IntegrationTableMapping.Direction::FromIntegrationTable;
                IntegrationTableMapping."Update-Conflict Resolution"::"Send Update to Integration":
                    Direction := IntegrationTableMapping.Direction::ToIntegrationTable;
            end;
        CRMIntegrationManagement.EnqueueSyncJob(IntegrationTableMapping, CoupledIds, CoupledIntegrationIds, Direction, true);
    end;

    local procedure UncoupleRecords(var IntegrationTableMapping: Record "Integration Table Mapping"; JobId: Guid)
    var
        CouplingAction: Codeunit "DVI Coupling Action";
        LocalRecordRef: RecordRef;
        IntegrationRecordRef: RecordRef;
    begin
        CouplingAction.Initialize(IntegrationTableMapping, JobId);
        if (IntegrationTableMapping.GetTableFilter() = '') and (IntegrationTableMapping.GetIntegrationTableFilter() = '') then begin
            UncoupleAll(IntegrationTableMapping, CouplingAction, JobId);
            exit;
        end;
        if IntegrationTableMapping.GetTableFilter() <> '' then begin
            LocalRecordRef.Open(IntegrationTableMapping."Table ID");
            IntegrationTableMapping.SetRecordRefFilter(LocalRecordRef);
            if LocalRecordRef.FindSet() then
                repeat
                    Clear(IntegrationRecordRef);
                    UncouplePair(CouplingAction, LocalRecordRef, IntegrationRecordRef, JobId);
                until LocalRecordRef.Next() = 0;
            exit;
        end;
        IntegrationRecordRef.Open(IntegrationTableMapping."Integration Table ID");
        IntegrationTableMapping.SetIntRecordRefFilter(IntegrationRecordRef);
        if IntegrationRecordRef.FindSet() then
            repeat
                Clear(LocalRecordRef);
                UncouplePair(CouplingAction, LocalRecordRef, IntegrationRecordRef, JobId);
            until IntegrationRecordRef.Next() = 0;
    end;

    /// <summary>
    /// Filters the couplings an uncoupling job of a mapping removes: those of its table that belong to the mapping or to no mapping, never those of another mapping on the same table.
    /// </summary>
    /// <param name="IntegrationTableMapping">The mapping being uncoupled.</param>
    /// <param name="CRMIntegrationRecord">Receives the filters.</param>
    internal procedure SetCouplingFilter(IntegrationTableMapping: Record "Integration Table Mapping"; var CRMIntegrationRecord: Record "CRM Integration Record")
    var
        MappingResolver: Codeunit "DVI Mapping Resolver";
    begin
        CRMIntegrationRecord.SetRange("Table ID", IntegrationTableMapping."Table ID");
        CRMIntegrationRecord.SetFilter("DVI Mapping Name", '%1|%2', '', MappingResolver.GetCouplingMappingName(IntegrationTableMapping));
    end;

    /// <summary>
    /// Deletes a coupling whose Business Central and Dataverse records both no longer exist, by its primary key (CRM ID, Integration ID).
    /// </summary>
    /// <param name="CRMIntegrationRecord">The orphan coupling.</param>
    internal procedure DeleteOrphanCoupling(CRMIntegrationRecord: Record "CRM Integration Record")
    var
        OrphanCRMIntegrationRecord: Record "CRM Integration Record";
    begin
        if OrphanCRMIntegrationRecord.Get(CRMIntegrationRecord."CRM ID", CRMIntegrationRecord."Integration ID") then
            OrphanCRMIntegrationRecord.Delete(true);
    end;

    local procedure UncoupleAll(IntegrationTableMapping: Record "Integration Table Mapping"; var CouplingAction: Codeunit "DVI Coupling Action"; JobId: Guid)
    var
        CRMIntegrationRecord: Record "CRM Integration Record";
        LocalRecordRef: RecordRef;
        IntegrationRecordRef: RecordRef;
    begin
        SetCouplingFilter(IntegrationTableMapping, CRMIntegrationRecord);
        if not CRMIntegrationRecord.FindSet() then
            exit;
        repeat
            Clear(LocalRecordRef);
            Clear(IntegrationRecordRef);
            LocalRecordRef.Open(IntegrationTableMapping."Table ID");
            if LocalRecordRef.GetBySystemId(CRMIntegrationRecord."Integration ID") then
                UncouplePair(CouplingAction, LocalRecordRef, IntegrationRecordRef, JobId)
            else begin
                LocalRecordRef.Close();
                if IntegrationTableMapping.GetRecordRef(CRMIntegrationRecord."CRM ID", IntegrationRecordRef) then
                    UncouplePair(CouplingAction, LocalRecordRef, IntegrationRecordRef, JobId)
                else
                    DeleteOrphanCoupling(CRMIntegrationRecord);
            end;
        until CRMIntegrationRecord.Next() = 0;
    end;

    local procedure UncouplePair(var CouplingAction: Codeunit "DVI Coupling Action"; var LocalRecordRef: RecordRef; var IntegrationRecordRef: RecordRef; JobId: Guid)
    var
        JobLog: Codeunit "DVI Synch. Job Log";
    begin
        CouplingAction.SetPair(LocalRecordRef, IntegrationRecordRef, false);
        Commit();
        if not CouplingAction.Run() then
            CouplingAction.HandleRunError(GetLastErrorText());
        if CouplingAction.WereRecordsModified() then
            JobLog.Count(JobId, Enum::"DVI Synch Action"::DVIModify);
        if CouplingAction.GetAction() <> Enum::"DVI Synch Action"::DVISkip then
            JobLog.Count(JobId, CouplingAction.GetAction());
    end;

    local procedure LoadMatchingFieldMappings(IntegrationTableMapping: Record "Integration Table Mapping"; var TempMatchingFieldMapping: Record "Integration Field Mapping" temporary; var MatchPriorities: List of [Integer]): Boolean
    var
        IntegrationFieldMapping: Record "Integration Field Mapping";
    begin
        IntegrationFieldMapping.SetRange("Integration Table Mapping Name", IntegrationTableMapping.Name);
        IntegrationFieldMapping.SetRange("Use For Match-Based Coupling", true);
        IntegrationFieldMapping.SetCurrentKey("Match Priority");
        IntegrationFieldMapping.SetAscending("Match Priority", true);
        if not IntegrationFieldMapping.FindSet() then
            exit(false);
        repeat
            TempMatchingFieldMapping := IntegrationFieldMapping;
            TempMatchingFieldMapping.Insert(false);
            if not MatchPriorities.Contains(IntegrationFieldMapping."Match Priority") then
                MatchPriorities.Add(IntegrationFieldMapping."Match Priority");
        until IntegrationFieldMapping.Next() = 0;
        exit(true);
    end;

    local procedure StartFullSynchReview(IntegrationTableMapping: Record "Integration Table Mapping"; JobId: Guid)
    var
        CRMFullSynchReviewLine: Record "CRM Full Synch. Review Line";
    begin
        if IntegrationTableMapping.Direction in [IntegrationTableMapping.Direction::Bidirectional, IntegrationTableMapping.Direction::FromIntegrationTable] then
            CRMFullSynchReviewLine.FullSynchStarted(IntegrationTableMapping, JobId, IntegrationTableMapping.Direction::FromIntegrationTable);
        if IntegrationTableMapping.Direction in [IntegrationTableMapping.Direction::Bidirectional, IntegrationTableMapping.Direction::ToIntegrationTable] then
            CRMFullSynchReviewLine.FullSynchStarted(IntegrationTableMapping, JobId, IntegrationTableMapping.Direction::ToIntegrationTable);
    end;

    local procedure FinishFullSynchReview(IntegrationTableMapping: Record "Integration Table Mapping")
    var
        CRMFullSynchReviewLine: Record "CRM Full Synch. Review Line";
    begin
        if IntegrationTableMapping.Direction in [IntegrationTableMapping.Direction::Bidirectional, IntegrationTableMapping.Direction::FromIntegrationTable] then
            CRMFullSynchReviewLine.FullSynchFinished(IntegrationTableMapping, IntegrationTableMapping.Direction::FromIntegrationTable);
        if IntegrationTableMapping.Direction in [IntegrationTableMapping.Direction::Bidirectional, IntegrationTableMapping.Direction::ToIntegrationTable] then
            CRMFullSynchReviewLine.FullSynchFinished(IntegrationTableMapping, IntegrationTableMapping.Direction::ToIntegrationTable);
    end;

    local procedure OpenConnection(IntegrationTableMapping: Record "Integration Table Mapping"): Text
    var
        MappingResolver: Codeunit "DVI Mapping Resolver";
        Connection: Interface "DVI IConnection";
    begin
        Connection := MappingResolver.GetModule(IntegrationTableMapping);
        if not Connection.IsEnabled() then
            Error(ModuleNotEnabledErr, MappingResolver.GetModule(IntegrationTableMapping), IntegrationTableMapping.Name);
        exit(Connection.Open());
    end;

    local procedure CloseConnection(IntegrationTableMapping: Record "Integration Table Mapping"; ConnectionName: Text)
    var
        MappingResolver: Codeunit "DVI Mapping Resolver";
        Connection: Interface "DVI IConnection";
    begin
        Connection := MappingResolver.GetModule(IntegrationTableMapping);
        Connection.Close(ConnectionName);
    end;
}
