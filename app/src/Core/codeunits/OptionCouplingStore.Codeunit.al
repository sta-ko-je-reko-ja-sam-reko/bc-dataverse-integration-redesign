namespace DataverseIntegration.Core;

using Microsoft.Integration.Dataverse;
using Microsoft.Integration.SyncEngine;

codeunit 80027 "DVI Option Coupling Store"
{
    Access = Internal;

    var
        AlreadyCoupledErr: Label 'The option value %1 is already coupled to another record.', Comment = '%1 = option label';

    /// <summary>
    /// Finds the option coupling of a Business Central record.
    /// </summary>
    /// <param name="LocalRecordId">The Business Central record.</param>
    /// <param name="CRMOptionMapping">Receives the coupling.</param>
    /// <returns>True when the record is coupled to an option value.</returns>
    internal procedure FindByRecord(LocalRecordId: RecordId; var CRMOptionMapping: Record "CRM Option Mapping"): Boolean
    begin
        CRMOptionMapping.Reset();
        CRMOptionMapping.SetRange("Record ID", LocalRecordId);
        exit(CRMOptionMapping.FindFirst());
    end;

    /// <summary>
    /// Finds the option coupling of a Dataverse option value, by the mapping's option field.
    /// </summary>
    /// <param name="IntegrationTableMapping">The option mapping.</param>
    /// <param name="OptionId">The Dataverse option value.</param>
    /// <param name="CRMOptionMapping">Receives the coupling.</param>
    /// <returns>True when the option value is coupled.</returns>
    internal procedure FindByOption(IntegrationTableMapping: Record "Integration Table Mapping"; OptionId: Integer; var CRMOptionMapping: Record "CRM Option Mapping"): Boolean
    begin
        CRMOptionMapping.Reset();
        CRMOptionMapping.SetRange("Integration Table ID", IntegrationTableMapping."Integration Table ID");
        CRMOptionMapping.SetRange("Integration Field ID", IntegrationTableMapping."Integration Table UID Fld. No.");
        CRMOptionMapping.SetRange("Option Value", OptionId);
        exit(CRMOptionMapping.FindFirst());
    end;

    /// <summary>
    /// Creates or refreshes the coupling between a Business Central record and an option value after a successful synchronization.
    /// </summary>
    /// <param name="IntegrationTableMapping">The option mapping.</param>
    /// <param name="LocalRecordRef">The Business Central record.</param>
    /// <param name="TempOptionValue">The option value.</param>
    /// <param name="JobId">The synchronization job.</param>
    internal procedure UpdateCoupling(IntegrationTableMapping: Record "Integration Table Mapping"; var LocalRecordRef: RecordRef; TempOptionValue: Record "DVI Option Value" temporary; JobId: Guid)
    var
        CRMOptionMapping: Record "CRM Option Mapping";
        ToIntegrationTable: Boolean;
        ModifiedAt: DateTime;
    begin
        ToIntegrationTable := IntegrationTableMapping.Direction = IntegrationTableMapping.Direction::ToIntegrationTable;
        if FindByRecord(LocalRecordRef.RecordId(), CRMOptionMapping) then begin
            if CRMOptionMapping."Option Value" <> TempOptionValue."Option Id" then
                Error(AlreadyCoupledErr, TempOptionValue."Code");
        end else
            InsertCoupling(IntegrationTableMapping, LocalRecordRef.RecordId(), TempOptionValue, CRMOptionMapping);
        CRMOptionMapping."Option Value Caption" := TempOptionValue."Code";
        if ToIntegrationTable then begin
            CRMOptionMapping."Last Synch. CRM Job ID" := JobId;
            CRMOptionMapping."Last Synch. CRM Result" := CRMOptionMapping."Last Synch. CRM Result"::Success;
            ModifiedAt := LocalRecordRef.Field(LocalRecordRef.SystemModifiedAtNo()).Value();
            if ModifiedAt > CRMOptionMapping."Last Synch. Modified On" then
                CRMOptionMapping."Last Synch. Modified On" := ModifiedAt;
        end else begin
            CRMOptionMapping."Last Synch. Job ID" := JobId;
            CRMOptionMapping."Last Synch. Result" := CRMOptionMapping."Last Synch. Result"::Success;
        end;
        CRMOptionMapping.Modify(true);
    end;

    /// <summary>
    /// Marks the option coupling of a source record as failed; after the same failure twice it is skipped.
    /// </summary>
    /// <param name="IntegrationTableMapping">The option mapping.</param>
    /// <param name="SourceRecordRef">The Business Central record or the option value that failed.</param>
    /// <param name="JobId">The synchronization job.</param>
    /// <returns>True when the coupling is now skipped.</returns>
    internal procedure MarkFailed(IntegrationTableMapping: Record "Integration Table Mapping"; var SourceRecordRef: RecordRef; JobId: Guid): Boolean
    var
        CRMOptionMapping: Record "CRM Option Mapping";
        ToIntegrationTable: Boolean;
    begin
        ToIntegrationTable := IntegrationTableMapping.Direction = IntegrationTableMapping.Direction::ToIntegrationTable;
        if ToIntegrationTable then begin
            if not FindByRecord(SourceRecordRef.RecordId(), CRMOptionMapping) then
                exit(false);
            if CRMOptionMapping."Last Synch. CRM Result" = CRMOptionMapping."Last Synch. CRM Result"::Failure then
                CRMOptionMapping.Skipped := IsSameFailureRepeatedTwice(SourceRecordRef, CRMOptionMapping."Last Synch. CRM Job ID", JobId);
            CRMOptionMapping."Last Synch. CRM Job ID" := JobId;
            CRMOptionMapping."Last Synch. CRM Result" := CRMOptionMapping."Last Synch. CRM Result"::Failure;
        end else begin
            if not FindByOption(IntegrationTableMapping, SourceRecordRef.Field(1).Value(), CRMOptionMapping) then
                exit(false);
            if CRMOptionMapping."Last Synch. Result" = CRMOptionMapping."Last Synch. Result"::Failure then
                CRMOptionMapping.Skipped := IsSameFailureRepeatedTwice(SourceRecordRef, CRMOptionMapping."Last Synch. Job ID", JobId);
            CRMOptionMapping."Last Synch. Job ID" := JobId;
            CRMOptionMapping."Last Synch. Result" := CRMOptionMapping."Last Synch. Result"::Failure;
        end;
        CRMOptionMapping.Modify(true);
        exit(CRMOptionMapping.Skipped);
    end;

    /// <summary>
    /// Returns whether a Business Central option record is unchanged since its last synchronization, compared with the option coupling's own time; option couplings never use CRM Integration Record.
    /// </summary>
    /// <param name="LocalRecordRef">The Business Central record.</param>
    /// <param name="CRMOptionMapping">Its option coupling.</param>
    /// <returns>True when the record was not modified after the last synchronization.</returns>
    internal procedure IsUnchangedSinceLastSynch(var LocalRecordRef: RecordRef; CRMOptionMapping: Record "CRM Option Mapping"): Boolean
    var
        LocalModifiedAt: DateTime;
    begin
        LocalModifiedAt := LocalRecordRef.Field(LocalRecordRef.SystemModifiedAtNo()).Value();
        exit(LocalModifiedAt <= CRMOptionMapping."Last Synch. Modified On");
    end;

    local procedure InsertCoupling(IntegrationTableMapping: Record "Integration Table Mapping"; LocalRecordId: RecordId; TempOptionValue: Record "DVI Option Value" temporary; var CRMOptionMapping: Record "CRM Option Mapping")
    begin
        CRMOptionMapping.Init();
        CRMOptionMapping."Record ID" := LocalRecordId;
        CRMOptionMapping."Option Value" := TempOptionValue."Option Id";
        CRMOptionMapping."Option Value Caption" := TempOptionValue."Code";
        CRMOptionMapping."Table ID" := LocalRecordId.TableNo();
        CRMOptionMapping."Integration Table ID" := IntegrationTableMapping."Integration Table ID";
        CRMOptionMapping."Integration Field ID" := IntegrationTableMapping."Integration Table UID Fld. No.";
        CRMOptionMapping.Insert(true);
    end;

    local procedure IsSameFailureRepeatedTwice(var SourceRecordRef: RecordRef; LastJobId: Guid; NewJobId: Guid): Boolean
    var
        LastError: Text;
        NewError: Text;
    begin
        if IsNullGuid(LastJobId) or IsNullGuid(NewJobId) then
            exit(false);
        LastError := GetJobError(LastJobId, SourceRecordRef.RecordId());
        NewError := GetJobError(NewJobId, SourceRecordRef.RecordId());
        exit((NewError <> '') and (LastError = NewError));
    end;

    local procedure GetJobError(JobId: Guid; SourceRecordId: RecordId): Text
    var
        IntegrationSynchJob: Record "Integration Synch. Job";
        IntegrationSynchJobErrors: Record "Integration Synch. Job Errors";
    begin
        if not IntegrationSynchJob.Get(JobId) then
            exit('');
        if not IntegrationSynchJob.GetErrorForRecordID(SourceRecordId, IntegrationSynchJobErrors) then
            exit('');
        exit(IntegrationSynchJobErrors.Message);
    end;
}
