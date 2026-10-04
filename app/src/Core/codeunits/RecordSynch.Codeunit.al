namespace DataverseIntegration.Core;

using Microsoft.Integration.Dataverse;
using Microsoft.Integration.SyncEngine;

codeunit 80007 "DVI Record Synch."
{
    Access = Internal;

    trigger OnRun()
    begin
        if not Initialized then
            Error(NotInitializedErr);
        SynchRecord();
    end;

    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        Context: Codeunit "DVI Sync Context";
        FieldTransfer: Codeunit "DVI Field Transfer";
        CouplingStore: Codeunit "DVI Coupling Store";
        JobLog: Codeunit "DVI Synch. Job Log";
        ConfigTemplateApplier: Codeunit "DVI Config. Template Applier";
        SourceRecordRef: RecordRef;
        DestinationRecordRef: RecordRef;
        RecordSync: Interface "DVI IRecordSync";
        RecordCoupling: Interface "DVI IRecordCoupling";
        ConflictPolicy: Interface "DVI IConflictPolicy";
        SynchAction: Enum "DVI Synch Action";
        ForceModify: Boolean;
        IgnoreSynchOnlyCoupledRecords: Boolean;
        Initialized: Boolean;
        NotInitializedErr: Label 'The record synchronization was started before it was initialized.';
        CoupledRecordIsDeletedErr: Label 'The %1 record cannot be updated because it is coupled to a deleted record.', Comment = '%1 = source table caption';
        UpdateConflictErr: Label 'Cannot update a record in the %2 table. The mapping between the %3 field on the %1 table and the %4 field on the %2 table is bidirectional, and one or both values have changed since the last synchronization.', Comment = '%1 = source table caption, %2 = destination table caption, %3 = source field caption, %4 = destination field caption';
        ModifyFailedErr: Label 'Modifying %1 failed.', Comment = '%1 = table caption';

    /// <summary>
    /// Prepares the synchronization of one direction of one mapping: resolves the mapping's handler and loads its field mappings.
    /// </summary>
    /// <param name="NewIntegrationTableMapping">The mapping being run.</param>
    /// <param name="JobId">The synchronization job that logs this direction.</param>
    /// <param name="ToIntegrationTable">True for Business Central to Dataverse.</param>
    /// <returns>False when the mapping has no enabled field mappings in this direction.</returns>
    internal procedure Initialize(NewIntegrationTableMapping: Record "Integration Table Mapping"; JobId: Guid; ToIntegrationTable: Boolean): Boolean
    var
        MappingResolver: Codeunit "DVI Mapping Resolver";
        Handler: Enum "DVI Sync Handler";
    begin
        IntegrationTableMapping := NewIntegrationTableMapping;
        Context.SetMapping(IntegrationTableMapping);
        Context.SetJobId(JobId);
        Context.SetToIntegrationTable(ToIntegrationTable);
        Handler := MappingResolver.GetHandler(IntegrationTableMapping);
        RecordSync := Handler;
        RecordCoupling := Handler;
        ConflictPolicy := Handler;
        Initialized := FieldTransfer.LoadFieldMappings(IntegrationTableMapping, ToIntegrationTable);
        exit(Initialized);
    end;

    /// <summary>
    /// Sets the record to synchronize with the next Run.
    /// </summary>
    /// <param name="NewSourceRecordRef">The record being synchronized.</param>
    /// <param name="NewForceModify">True to write all mapped fields even when the record did not change.</param>
    /// <param name="NewIgnoreSynchOnlyCoupledRecords">True to create an uncoupled record even when the mapping synchronizes only coupled records.</param>
    internal procedure SetRecord(var NewSourceRecordRef: RecordRef; NewForceModify: Boolean; NewIgnoreSynchOnlyCoupledRecords: Boolean)
    begin
        SourceRecordRef := NewSourceRecordRef;
        Clear(DestinationRecordRef);
        ForceModify := NewForceModify;
        IgnoreSynchOnlyCoupledRecords := NewIgnoreSynchOnlyCoupledRecords;
        SynchAction := SynchAction::DVINone;
    end;

    /// <summary>
    /// Returns the action the last Run took for its record.
    /// </summary>
    /// <returns>The action, used for the job counters.</returns>
    internal procedure GetAction(): Enum "DVI Synch Action"
    begin
        exit(SynchAction);
    end;

    /// <summary>
    /// Records an error that stopped the last Run: logs it, marks the coupling as failed and drops the record's follow-ups.
    /// </summary>
    /// <param name="ErrorText">The error raised by the Run.</param>
    /// <returns>Fail, or Skip when the record failed often enough to be skipped from now on.</returns>
    internal procedure HandleRunError(ErrorText: Text): Enum "DVI Synch Action"
    begin
        Context.ClearFollowUps();
        LogFailure(ErrorText);
        exit(SynchAction);
    end;

    /// <summary>
    /// Moves the follow-ups queued by the last Run into a buffer and clears them from the context.
    /// </summary>
    /// <param name="TempFollowUpBuffer">Receives the follow-ups.</param>
    internal procedure TakeFollowUps(var TempFollowUpBuffer: Record "DVI Follow-up Buffer" temporary)
    begin
        Context.GetFollowUps(TempFollowUpBuffer);
        Context.ClearFollowUps();
    end;

    local procedure SynchRecord()
    var
        BothModified: Boolean;
    begin
        if not FindDestination() then
            exit;
        if not DecideChanges(BothModified) then
            exit;
        if not TransferFields(BothModified) then
            exit;
        case SynchAction of
            SynchAction::DVIInsert:
                InsertDestination();
            SynchAction::DVIModify, SynchAction::DVIForceModify:
                ModifyDestination(BothModified);
            SynchAction::DVIIgnoreUnchanged:
                HandleUnchanged();
        end;
    end;

    local procedure FindDestination(): Boolean
    var
        DestinationIsDeleted: Boolean;
    begin
        if CouplingStore.FindCoupledRecord(IntegrationTableMapping, SourceRecordRef, DestinationRecordRef, DestinationIsDeleted) then begin
            if DestinationIsDeleted then
                exit(ResolveDeletion());
            if ForceModify then
                SynchAction := SynchAction::DVIForceModify
            else
                SynchAction := SynchAction::DVIModify;
            exit(true);
        end;
        if RecordCoupling.FindUncoupledDestination(Context, SourceRecordRef, DestinationRecordRef, DestinationIsDeleted) then
            if not DestinationIsDeleted then begin
                CouplingStore.UpdateCoupling(IntegrationTableMapping, SourceRecordRef, DestinationRecordRef);
                CouplingStore.UpdateTimestamp(IntegrationTableMapping, SourceRecordRef, DestinationRecordRef, Context.GetJobId(), false);
                SynchAction := SynchAction::DVIForceModify;
                exit(true);
            end;
        if DestinationIsDeleted or (IntegrationTableMapping."Synch. Only Coupled Records" and not IgnoreSynchOnlyCoupledRecords) then begin
            SynchAction := SynchAction::DVISkip;
            exit(false);
        end;
        PrepareNewDestination();
        exit(true);
    end;

    local procedure ResolveDeletion(): Boolean
    begin
        case ConflictPolicy.ResolveDeletionConflict(Context, SourceRecordRef) of
            Enum::"DVI Deletion Outcome"::DVIRestoreRecord:
                begin
                    CouplingStore.DeleteCoupling(IntegrationTableMapping, SourceRecordRef);
                    PrepareNewDestination();
                    exit(true);
                end;
            Enum::"DVI Deletion Outcome"::DVIRemoveCoupling:
                begin
                    CouplingStore.DeleteCoupling(IntegrationTableMapping, SourceRecordRef);
                    SynchAction := SynchAction::DVINone;
                end;
            Enum::"DVI Deletion Outcome"::DVISkip:
                SynchAction := SynchAction::DVISkip;
            else begin
                Clear(DestinationRecordRef);
                LogFailure(StrSubstNo(CoupledRecordIsDeletedErr, SourceRecordRef.Caption()));
            end;
        end;
        exit(false);
    end;

    local procedure PrepareNewDestination()
    begin
        DestinationRecordRef.Close();
        if SourceRecordRef.Number() = IntegrationTableMapping."Table ID" then
            DestinationRecordRef.Open(IntegrationTableMapping."Integration Table ID")
        else
            DestinationRecordRef.Open(IntegrationTableMapping."Table ID");
        DestinationRecordRef.Init();
        SynchAction := SynchAction::DVIInsert;
    end;

    local procedure DecideChanges(var BothModified: Boolean): Boolean
    var
        SourceWasChanged: Boolean;
    begin
        BothModified := false;
        if SynchAction = SynchAction::DVIInsert then
            exit(true);
        SourceWasChanged := CouplingStore.WasModifiedAfterLastSynch(IntegrationTableMapping, SourceRecordRef);
        if SynchAction = SynchAction::DVIForceModify then
            exit(true);
        if not SourceWasChanged then begin
            SynchAction := SynchAction::DVIIgnoreUnchanged;
            exit(false);
        end;
        if IntegrationTableMapping.GetDirection() = IntegrationTableMapping.Direction::Bidirectional then
            BothModified := CouplingStore.WasModifiedAfterLastSynch(IntegrationTableMapping, DestinationRecordRef);
        exit(true);
    end;

    local procedure TransferFields(BothModified: Boolean): Boolean
    var
        CDSTransformationRuleMgt: Codeunit "CDS Transformation Rule Mgt.";
        AdditionalFieldsModified: Boolean;
    begin
        Context.SetDestinationInserted(SynchAction = SynchAction::DVIInsert);
        RecordSync.BeforeTransferFields(Context, SourceRecordRef, DestinationRecordRef);
        CDSTransformationRuleMgt.ApplyTransformations(SourceRecordRef, DestinationRecordRef, IntegrationTableMapping);
        FieldTransfer.TransferFields(SourceRecordRef, DestinationRecordRef, SynchAction <> SynchAction::DVIInsert);
        if BothModified and FieldTransfer.WasBidirectionalFieldModified() then
            exit(ResolveUpdateConflict());
        RecordSync.AfterTransferFields(Context, SourceRecordRef, DestinationRecordRef, AdditionalFieldsModified);
        if (SynchAction = SynchAction::DVIModify) and not (FieldTransfer.WasModified() or AdditionalFieldsModified) then
            SynchAction := SynchAction::DVIIgnoreUnchanged;
        exit(true);
    end;

    local procedure ResolveUpdateConflict(): Boolean
    var
        SkipRecord: Boolean;
    begin
        if not ConflictPolicy.ResolveUpdateConflict(Context, SourceRecordRef, DestinationRecordRef, SkipRecord) then begin
            LogFailure(ConflictMessage());
            exit(false);
        end;
        if SkipRecord then begin
            SynchAction := SynchAction::DVISkip;
            exit(false);
        end;
        SynchAction := SynchAction::DVIForceModify;
        exit(true);
    end;

    local procedure ConflictMessage(): Text
    var
        SourceFieldNo: Integer;
        DestinationFieldNo: Integer;
    begin
        FieldTransfer.GetConflictFields(SourceFieldNo, DestinationFieldNo);
        exit(StrSubstNo(UpdateConflictErr, SourceRecordRef.Caption(), DestinationRecordRef.Caption(),
          FieldCaptionOrNumber(SourceRecordRef, SourceFieldNo), FieldCaptionOrNumber(DestinationRecordRef, DestinationFieldNo)));
    end;

    local procedure FieldCaptionOrNumber(var RecordRef: RecordRef; FieldNo: Integer): Text
    begin
        if RecordRef.FieldExist(FieldNo) then
            exit(RecordRef.Field(FieldNo).Caption());
        exit(Format(FieldNo));
    end;

    local procedure InsertDestination()
    begin
        RecordSync.BeforeInsert(Context, SourceRecordRef, DestinationRecordRef);
        DestinationRecordRef.Insert(true);
        if not ConfigTemplateApplier.Apply(IntegrationTableMapping, SourceRecordRef, DestinationRecordRef) then begin
            LogFailure(ConfigTemplateApplier.GetLastError());
            exit;
        end;
        CouplingStore.UpdateCoupling(IntegrationTableMapping, SourceRecordRef, DestinationRecordRef);
        Commit();
        RecordSync.AfterInsert(Context, SourceRecordRef, DestinationRecordRef);
        RefreshLocalDestination();
        CouplingStore.UpdateTimestamp(IntegrationTableMapping, SourceRecordRef, DestinationRecordRef, Context.GetJobId(), false);
    end;

    local procedure ModifyDestination(BothModified: Boolean)
    begin
        RecordSync.BeforeModify(Context, SourceRecordRef, DestinationRecordRef);
        if not DestinationRecordRef.Modify(true) then begin
            LogFailure(StrSubstNo(ModifyFailedErr, DestinationRecordRef.Caption()));
            exit;
        end;
        CouplingStore.UpdateCoupling(IntegrationTableMapping, SourceRecordRef, DestinationRecordRef);
        RecordSync.AfterModify(Context, SourceRecordRef, DestinationRecordRef);
        RefreshLocalDestination();
        CouplingStore.UpdateTimestamp(IntegrationTableMapping, SourceRecordRef, DestinationRecordRef, Context.GetJobId(), BothModified);
    end;

    local procedure HandleUnchanged()
    begin
        CouplingStore.UpdateCoupling(IntegrationTableMapping, SourceRecordRef, DestinationRecordRef);
        RecordSync.Unchanged(Context, SourceRecordRef, DestinationRecordRef);
        CouplingStore.UpdateTimestamp(IntegrationTableMapping, SourceRecordRef, DestinationRecordRef, Context.GetJobId(), false);
    end;

    local procedure RefreshLocalDestination()
    begin
        if DestinationRecordRef.Number() <> IntegrationTableMapping."Table ID" then
            exit;
        if DestinationRecordRef.GetBySystemId(DestinationRecordRef.Field(DestinationRecordRef.SystemIdNo()).Value()) then;
    end;

    local procedure LogFailure(ErrorText: Text)
    begin
        SynchAction := SynchAction::DVIFail;
        JobLog.LogError(Context.GetJobId(), SourceRecordRef, DestinationRecordRef, ErrorText);
        if CouplingStore.MarkFailed(IntegrationTableMapping, SourceRecordRef, Context.GetJobId()) then
            SynchAction := SynchAction::DVISkip;
    end;
}
