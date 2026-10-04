namespace DataverseIntegration.Core;

using Microsoft.Integration.SyncEngine;

codeunit 80016 "DVI Coupling Action"
{
    Access = Internal;

    trigger OnRun()
    begin
        if not Initialized then
            Error(NotInitializedErr);
        if CoupleMode then
            CouplePair()
        else
            UncouplePair();
    end;

    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        Context: Codeunit "DVI Sync Context";
        CouplingStore: Codeunit "DVI Coupling Store";
        JobLog: Codeunit "DVI Synch. Job Log";
        LocalRecordRef: RecordRef;
        IntegrationRecordRef: RecordRef;
        RecordCoupling: Interface "DVI IRecordCoupling";
        SynchAction: Enum "DVI Synch Action";
        CoupleMode: Boolean;
        RecordsModified: Boolean;
        Initialized: Boolean;
        NotInitializedErr: Label 'The coupling action was started before it was initialized.';
        ModifyFailedErr: Label 'Saving %1 before removing its coupling failed.', Comment = '%1 = table caption';

    /// <summary>
    /// Prepares coupling or uncoupling for the records of one mapping.
    /// </summary>
    /// <param name="NewIntegrationTableMapping">The mapping.</param>
    /// <param name="JobId">The coupling or uncoupling job.</param>
    internal procedure Initialize(NewIntegrationTableMapping: Record "Integration Table Mapping"; JobId: Guid)
    var
        MappingResolver: Codeunit "DVI Mapping Resolver";
    begin
        IntegrationTableMapping := NewIntegrationTableMapping;
        Context.SetMapping(IntegrationTableMapping);
        Context.SetJobId(JobId);
        RecordCoupling := MappingResolver.GetHandler(IntegrationTableMapping);
        Initialized := true;
    end;

    /// <summary>
    /// Sets the pair the next Run couples or uncouples. Either record may be closed when only one side is known for an uncoupling.
    /// </summary>
    /// <param name="NewLocalRecordRef">The Business Central record, or a closed RecordRef.</param>
    /// <param name="NewIntegrationRecordRef">The Dataverse record, or a closed RecordRef.</param>
    /// <param name="NewCoupleMode">True to couple, false to uncouple.</param>
    internal procedure SetPair(var NewLocalRecordRef: RecordRef; var NewIntegrationRecordRef: RecordRef; NewCoupleMode: Boolean)
    begin
        LocalRecordRef := NewLocalRecordRef;
        IntegrationRecordRef := NewIntegrationRecordRef;
        CoupleMode := NewCoupleMode;
        RecordsModified := false;
        SynchAction := SynchAction::DVINone;
    end;

    /// <summary>
    /// Returns the action the last Run took.
    /// </summary>
    /// <returns>Couple, Uncouple, Skip or Fail.</returns>
    internal procedure GetAction(): Enum "DVI Synch Action"
    begin
        exit(SynchAction);
    end;

    /// <summary>
    /// Returns whether the last Run saved a change to either record before uncoupling.
    /// </summary>
    /// <returns>True when a record was modified.</returns>
    internal procedure WereRecordsModified(): Boolean
    begin
        exit(RecordsModified);
    end;

    /// <summary>
    /// Logs an error that stopped the last Run.
    /// </summary>
    /// <param name="ErrorText">The error raised by the Run.</param>
    internal procedure HandleRunError(ErrorText: Text)
    begin
        SynchAction := SynchAction::DVIFail;
        JobLog.LogError(Context.GetJobId(), LocalRecordRef, IntegrationRecordRef, ErrorText);
    end;

    local procedure CouplePair()
    var
        CoupledRecordRef: RecordRef;
        DestinationIsDeleted: Boolean;
    begin
        if CouplingStore.FindCoupledRecord(IntegrationTableMapping, LocalRecordRef, CoupledRecordRef, DestinationIsDeleted) then begin
            SynchAction := SynchAction::DVISkip;
            exit;
        end;
        CouplingStore.UpdateCoupling(IntegrationTableMapping, LocalRecordRef, IntegrationRecordRef);
        RecordCoupling.AfterCouple(Context, LocalRecordRef, IntegrationRecordRef);
        SynchAction := SynchAction::DVICouple;
    end;

    local procedure UncouplePair()
    var
        DestinationIsDeleted: Boolean;
    begin
        if not FindOtherSide(DestinationIsDeleted) then begin
            SynchAction := SynchAction::DVISkip;
            exit;
        end;
        RecordCoupling.BeforeUncouple(Context, LocalRecordRef, IntegrationRecordRef);
        if not SaveChangedRecords() then
            exit;
        if LocalRecordRef.Number() <> 0 then
            CouplingStore.DeleteCoupling(IntegrationTableMapping, LocalRecordRef)
        else
            CouplingStore.DeleteCoupling(IntegrationTableMapping, IntegrationRecordRef);
        RecordCoupling.AfterUncouple(Context, LocalRecordRef, IntegrationRecordRef);
        SynchAction := SynchAction::DVIUncouple;
    end;

    local procedure FindOtherSide(var DestinationIsDeleted: Boolean): Boolean
    begin
        if LocalRecordRef.Number() <> 0 then
            exit(CouplingStore.FindCoupledRecord(IntegrationTableMapping, LocalRecordRef, IntegrationRecordRef, DestinationIsDeleted));
        exit(CouplingStore.FindCoupledRecord(IntegrationTableMapping, IntegrationRecordRef, LocalRecordRef, DestinationIsDeleted));
    end;

    local procedure SaveChangedRecords(): Boolean
    begin
        if not SaveIfDirty(LocalRecordRef) then
            exit(false);
        exit(SaveIfDirty(IntegrationRecordRef));
    end;

    local procedure SaveIfDirty(var RecordRef: RecordRef): Boolean
    begin
        if RecordRef.Number() = 0 then
            exit(true);
        if not RecordRef.IsDirty() then
            exit(true);
        if not RecordRef.Modify(true) then begin
            HandleRunError(StrSubstNo(ModifyFailedErr, RecordRef.Caption()));
            exit(false);
        end;
        RecordsModified := true;
        exit(true);
    end;
}
