namespace DataverseIntegration.Core;

using Microsoft.Integration.Dataverse;
using Microsoft.Integration.SyncEngine;

codeunit 80026 "DVI Option Record Synch."
{
    Access = Internal;

    trigger OnRun()
    begin
        if not Initialized then
            Error(NotInitializedErr);
        if ToIntegrationTable then
            SynchToOption()
        else
            SynchFromOption();
    end;

    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        IntegrationFieldMapping: Record "Integration Field Mapping";
        TempAllOptionValue: Record "DVI Option Value" temporary;
        TempOptionValue: Record "DVI Option Value" temporary;
        Context: Codeunit "DVI Sync Context";
        JobLog: Codeunit "DVI Synch. Job Log";
        OptionCouplingStore: Codeunit "DVI Option Coupling Store";
        LocalRecordRef: RecordRef;
        OptionRecordRef: RecordRef;
        RecordSync: Interface "DVI IRecordSync";
        ConflictPolicy: Interface "DVI IConflictPolicy";
        OptionSource: Interface "DVI IOptionSource";
        SynchAction: Enum "DVI Synch Action";
        ToIntegrationTable: Boolean;
        ForceModify: Boolean;
        Initialized: Boolean;
        NotInitializedErr: Label 'The option synchronization was started before it was initialized.';
        CoupledRecordIsDeletedErr: Label 'The %1 record cannot be updated because it is coupled to a deleted record.', Comment = '%1 = source table caption';

    /// <summary>
    /// Prepares the synchronization of one option mapping: resolves its handler and loads the option values from Dataverse.
    /// </summary>
    /// <param name="NewIntegrationTableMapping">The option mapping.</param>
    /// <param name="JobId">The synchronization job.</param>
    /// <returns>False when the mapping has no field mapping.</returns>
    internal procedure Initialize(NewIntegrationTableMapping: Record "Integration Table Mapping"; JobId: Guid): Boolean
    var
        MappingResolver: Codeunit "DVI Mapping Resolver";
        Handler: Enum "DVI Sync Handler";
    begin
        IntegrationTableMapping := NewIntegrationTableMapping;
        ToIntegrationTable := IntegrationTableMapping.Direction = IntegrationTableMapping.Direction::ToIntegrationTable;
        Context.SetMapping(IntegrationTableMapping);
        Context.SetJobId(JobId);
        Context.SetToIntegrationTable(ToIntegrationTable);
        Handler := MappingResolver.GetHandler(IntegrationTableMapping);
        RecordSync := Handler;
        ConflictPolicy := Handler;
        OptionSource := Handler;
        IntegrationFieldMapping.SetRange("Integration Table Mapping Name", IntegrationTableMapping.Name);
        if not IntegrationFieldMapping.FindFirst() then
            exit(false);
        OptionSource.LoadOptions(Context, TempAllOptionValue);
        Initialized := true;
        exit(true);
    end;

    /// <summary>
    /// Copies the option values loaded from Dataverse.
    /// </summary>
    /// <param name="TempTargetOptionValue">Receives the option values.</param>
    internal procedure GetOptions(var TempTargetOptionValue: Record "DVI Option Value" temporary)
    begin
        TempTargetOptionValue.Copy(TempAllOptionValue, true);
    end;

    /// <summary>
    /// Sets the Business Central record the next Run synchronizes to Dataverse.
    /// </summary>
    /// <param name="NewLocalRecordRef">The Business Central record.</param>
    /// <param name="NewForceModify">True to write the value even when it did not change.</param>
    internal procedure SetLocalRecord(var NewLocalRecordRef: RecordRef; NewForceModify: Boolean)
    begin
        LocalRecordRef := NewLocalRecordRef;
        ForceModify := NewForceModify;
        SynchAction := SynchAction::DVINone;
    end;

    /// <summary>
    /// Sets the Dataverse option value the next Run synchronizes to Business Central.
    /// </summary>
    /// <param name="OptionId">The option value.</param>
    /// <param name="NewForceModify">True to write the value even when it did not change.</param>
    internal procedure SetOption(OptionId: Integer; NewForceModify: Boolean)
    begin
        TempOptionValue.Copy(TempAllOptionValue, true);
        TempOptionValue.Get(OptionId);
        Clear(LocalRecordRef);
        ForceModify := NewForceModify;
        SynchAction := SynchAction::DVINone;
    end;

    /// <summary>
    /// Returns the action the last Run took.
    /// </summary>
    /// <returns>The action, used for the job counters.</returns>
    internal procedure GetAction(): Enum "DVI Synch Action"
    begin
        exit(SynchAction);
    end;

    /// <summary>
    /// Records an error that stopped the last Run.
    /// </summary>
    /// <param name="ErrorText">The error raised by the Run.</param>
    /// <returns>Fail, or Skip when the option failed often enough to be skipped from now on.</returns>
    internal procedure HandleRunError(ErrorText: Text): Enum "DVI Synch Action"
    begin
        LogFailure(ErrorText);
        exit(SynchAction);
    end;

    local procedure SynchFromOption()
    var
        CRMOptionMapping: Record "CRM Option Mapping";
    begin
        OptionRecordRef.GetTable(TempOptionValue);
        if OptionCouplingStore.FindByOption(IntegrationTableMapping, TempOptionValue."Option Id", CRMOptionMapping) then begin
            if not LocalRecordRef.Get(CRMOptionMapping."Record ID") then begin
                if not ResolveDeletion(CRMOptionMapping, OptionRecordRef) then
                    exit;
            end else begin
                ModifyLocalRecord();
                exit;
            end;
        end else
            if IntegrationTableMapping."Synch. Only Coupled Records" then begin
                SynchAction := SynchAction::DVISkip;
                exit;
            end;
        InsertLocalRecord();
    end;

    local procedure InsertLocalRecord()
    var
        LabelFieldRef: FieldRef;
    begin
        SynchAction := SynchAction::DVIInsert;
        LocalRecordRef.Close();
        LocalRecordRef.Open(IntegrationTableMapping."Table ID");
        LocalRecordRef.Init();
        Context.SetDestinationInserted(true);
        RecordSync.BeforeTransferFields(Context, OptionRecordRef, LocalRecordRef);
        LabelFieldRef := LocalRecordRef.Field(IntegrationFieldMapping."Field No.");
        LabelFieldRef.Value(CopyStr(TempOptionValue."Code", 1, LabelFieldRef.Length()));
        if IntegrationFieldMapping."Validate Field" then
            LabelFieldRef.Validate();
        RecordSync.BeforeInsert(Context, OptionRecordRef, LocalRecordRef);
        LocalRecordRef.Insert(true);
        OptionCouplingStore.UpdateCoupling(IntegrationTableMapping, LocalRecordRef, TempOptionValue, Context.GetJobId());
        Commit();
        RecordSync.AfterInsert(Context, OptionRecordRef, LocalRecordRef);
    end;

    local procedure ModifyLocalRecord()
    var
        LabelFieldRef: FieldRef;
        NewLabel: Text;
    begin
        LabelFieldRef := LocalRecordRef.Field(IntegrationFieldMapping."Field No.");
        NewLabel := CopyStr(TempOptionValue."Code", 1, LabelFieldRef.Length());
        if (UpperCase(Format(LabelFieldRef.Value())) = UpperCase(NewLabel)) and not ForceModify then begin
            SynchAction := SynchAction::DVIIgnoreUnchanged;
            RecordSync.Unchanged(Context, OptionRecordRef, LocalRecordRef);
            exit;
        end;
        SynchAction := SynchAction::DVIModify;
        Context.SetDestinationInserted(false);
        RecordSync.BeforeTransferFields(Context, OptionRecordRef, LocalRecordRef);
        RecordSync.BeforeModify(Context, OptionRecordRef, LocalRecordRef);
        if UpperCase(Format(LabelFieldRef.Value())) <> UpperCase(NewLabel) then
            LocalRecordRef.Rename(NewLabel);
        OptionCouplingStore.UpdateCoupling(IntegrationTableMapping, LocalRecordRef, TempOptionValue, Context.GetJobId());
        RecordSync.AfterModify(Context, OptionRecordRef, LocalRecordRef);
    end;

    local procedure SynchToOption()
    var
        CRMOptionMapping: Record "CRM Option Mapping";
    begin
        TempOptionValue.Copy(TempAllOptionValue, true);
        if OptionCouplingStore.FindByRecord(LocalRecordRef.RecordId(), CRMOptionMapping) then begin
            if not TempOptionValue.Get(CRMOptionMapping."Option Value") then begin
                if not ResolveDeletion(CRMOptionMapping, LocalRecordRef) then
                    exit;
            end else begin
                ModifyOption(CRMOptionMapping);
                exit;
            end;
        end else
            if IntegrationTableMapping."Synch. Only Coupled Records" then begin
                SynchAction := SynchAction::DVISkip;
                exit;
            end;
        InsertOption();
    end;

    local procedure InsertOption()
    var
        CDSIntegrationMgt: Codeunit "CDS Integration Mgt.";
        EntityName: Text;
        FieldName: Text;
    begin
        SynchAction := SynchAction::DVIInsert;
        TempOptionValue.Init();
        TempOptionValue."Code" := CopyStr(Format(LocalRecordRef.Field(IntegrationFieldMapping."Field No.").Value()), 1, MaxStrLen(TempOptionValue."Code"));
        OptionRecordRef.GetTable(TempOptionValue);
        Context.SetDestinationInserted(true);
        RecordSync.BeforeTransferFields(Context, LocalRecordRef, OptionRecordRef);
        RecordSync.BeforeInsert(Context, LocalRecordRef, OptionRecordRef);
        OptionSource.GetOptionSetField(Context, EntityName, FieldName);
        TempOptionValue."Option Id" := CDSIntegrationMgt.InsertOptionSetMetadata(EntityName, FieldName, TempOptionValue."Code");
        TempOptionValue.Insert(false);
        OptionCouplingStore.UpdateCoupling(IntegrationTableMapping, LocalRecordRef, TempOptionValue, Context.GetJobId());
        Commit();
        OptionRecordRef.GetTable(TempOptionValue);
        RecordSync.AfterInsert(Context, LocalRecordRef, OptionRecordRef);
    end;

    local procedure ModifyOption(CRMOptionMapping: Record "CRM Option Mapping")
    var
        CDSIntegrationMgt: Codeunit "CDS Integration Mgt.";
        EntityName: Text;
        FieldName: Text;
        LocalModifiedAt: DateTime;
    begin
        OptionRecordRef.GetTable(TempOptionValue);
        LocalModifiedAt := LocalRecordRef.Field(LocalRecordRef.SystemModifiedAtNo()).Value();
        if not ForceModify then
            if LocalModifiedAt <= CRMOptionMapping."Last Synch. Modified On" then begin
                SynchAction := SynchAction::DVIIgnoreUnchanged;
                RecordSync.Unchanged(Context, LocalRecordRef, OptionRecordRef);
                exit;
            end;
        SynchAction := SynchAction::DVIModify;
        Context.SetDestinationInserted(false);
        RecordSync.BeforeTransferFields(Context, LocalRecordRef, OptionRecordRef);
        TempOptionValue."Code" := CopyStr(Format(LocalRecordRef.Field(IntegrationFieldMapping."Field No.").Value()), 1, MaxStrLen(TempOptionValue."Code"));
        RecordSync.BeforeModify(Context, LocalRecordRef, OptionRecordRef);
        OptionSource.GetOptionSetField(Context, EntityName, FieldName);
        CDSIntegrationMgt.UpdateOptionSetMetadata(EntityName, FieldName, TempOptionValue."Option Id", TempOptionValue."Code");
        TempOptionValue.Modify(false);
        OptionCouplingStore.UpdateCoupling(IntegrationTableMapping, LocalRecordRef, TempOptionValue, Context.GetJobId());
        OptionRecordRef.GetTable(TempOptionValue);
        RecordSync.AfterModify(Context, LocalRecordRef, OptionRecordRef);
    end;

    local procedure ResolveDeletion(var CRMOptionMapping: Record "CRM Option Mapping"; var SourceRecordRef: RecordRef): Boolean
    begin
        case ConflictPolicy.ResolveDeletionConflict(Context, SourceRecordRef) of
            Enum::"DVI Deletion Outcome"::DVIRestoreRecord:
                begin
                    CRMOptionMapping.Delete(true);
                    exit(true);
                end;
            Enum::"DVI Deletion Outcome"::DVIRemoveCoupling:
                begin
                    CRMOptionMapping.Delete(true);
                    SynchAction := SynchAction::DVINone;
                end;
            Enum::"DVI Deletion Outcome"::DVISkip:
                SynchAction := SynchAction::DVISkip;
            else
                LogFailure(StrSubstNo(CoupledRecordIsDeletedErr, SourceRecordRef.Caption()));
        end;
        exit(false);
    end;

    local procedure LogFailure(ErrorText: Text)
    begin
        SynchAction := SynchAction::DVIFail;
        if ToIntegrationTable then begin
            JobLog.LogError(Context.GetJobId(), LocalRecordRef, OptionRecordRef, ErrorText);
            if OptionCouplingStore.MarkFailed(IntegrationTableMapping, LocalRecordRef, Context.GetJobId()) then
                SynchAction := SynchAction::DVISkip;
        end else begin
            OptionRecordRef.GetTable(TempOptionValue);
            JobLog.LogError(Context.GetJobId(), OptionRecordRef, LocalRecordRef, ErrorText);
            if OptionCouplingStore.MarkFailed(IntegrationTableMapping, OptionRecordRef, Context.GetJobId()) then
                SynchAction := SynchAction::DVISkip;
        end;
    end;
}
