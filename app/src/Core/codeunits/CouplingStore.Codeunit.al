namespace DataverseIntegration.Core;

using Microsoft.Integration.Dataverse;
using Microsoft.Integration.SyncEngine;

codeunit 80021 "DVI Coupling Store"
{
    Access = Internal;

    /// <summary>
    /// Finds the record coupled to a source record.
    /// </summary>
    /// <param name="IntegrationTableMapping">The mapping being run.</param>
    /// <param name="SourceRecordRef">The record being synchronized.</param>
    /// <param name="DestinationRecordRef">Receives the coupled record when it still exists.</param>
    /// <param name="DestinationIsDeleted">Set to true when a coupling exists but the coupled record does not.</param>
    /// <returns>True when the source record is coupled.</returns>
    internal procedure FindCoupledRecord(IntegrationTableMapping: Record "Integration Table Mapping"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef; var DestinationIsDeleted: Boolean): Boolean
    var
        IntegrationRecordManagement: Codeunit "Integration Record Management";
        LocalRecordId: RecordId;
        IntegrationTableUid: Variant;
    begin
        DestinationIsDeleted := false;
        if SourceRecordRef.Number() = IntegrationTableMapping."Table ID" then begin
            if not IntegrationRecordManagement.FindIntegrationTableUIdByRecordRef(TableConnectionType::CRM, SourceRecordRef, IntegrationTableUid) then
                exit(false);
            DestinationIsDeleted := not IntegrationTableMapping.GetRecordRef(IntegrationTableUid, DestinationRecordRef);
            exit(true);
        end;
        if not IntegrationRecordManagement.FindRecordIdByIntegrationTableUid(
             TableConnectionType::CRM, SourceRecordRef.Field(IntegrationTableMapping."Integration Table UID Fld. No.").Value(),
             IntegrationTableMapping."Table ID", LocalRecordId)
        then
            exit(false);
        DestinationIsDeleted := not DestinationRecordRef.Get(LocalRecordId);
        exit(true);
    end;

    /// <summary>
    /// Creates or refreshes the coupling between a Business Central record and a Dataverse record, and stamps it with the owning mapping.
    /// </summary>
    /// <param name="IntegrationTableMapping">The mapping being run.</param>
    /// <param name="SourceRecordRef">The record being synchronized.</param>
    /// <param name="DestinationRecordRef">The destination record.</param>
    internal procedure UpdateCoupling(IntegrationTableMapping: Record "Integration Table Mapping"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    var
        IntegrationRecordManagement: Codeunit "Integration Record Management";
        LocalRecordRef: RecordRef;
        IntegrationRecordRef: RecordRef;
        IntegrationTableUid: Variant;
    begin
        SplitLocalAndIntegration(IntegrationTableMapping, SourceRecordRef, DestinationRecordRef, LocalRecordRef, IntegrationRecordRef);
        IntegrationTableUid := IntegrationRecordRef.Field(IntegrationTableMapping."Integration Table UID Fld. No.").Value();
        IntegrationRecordManagement.UpdateIntegrationTableCoupling(TableConnectionType::CRM, IntegrationTableUid, LocalRecordRef);
        StampMappingName(IntegrationTableMapping, IntegrationTableUid, LocalRecordRef);
    end;

    /// <summary>
    /// Stores the modification times of both records on the coupling, so the next run detects only later changes.
    /// </summary>
    /// <param name="IntegrationTableMapping">The mapping being run.</param>
    /// <param name="SourceRecordRef">The record being synchronized.</param>
    /// <param name="DestinationRecordRef">The destination record.</param>
    /// <param name="JobId">The synchronization job.</param>
    /// <param name="BothModified">True when both records had changed; the destination time is then moved back so the change on the other side is not lost.</param>
    internal procedure UpdateTimestamp(IntegrationTableMapping: Record "Integration Table Mapping"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef; JobId: Guid; BothModified: Boolean)
    var
        CRMIntegrationManagement: Codeunit "CRM Integration Management";
        IntegrationRecordManagement: Codeunit "Integration Record Management";
        LocalRecordRef: RecordRef;
        IntegrationRecordRef: RecordRef;
        IntegrationTableModifiedOn: DateTime;
        LocalTableModifiedOn: DateTime;
        ToIntegrationTable: Boolean;
    begin
        if CRMIntegrationManagement.IsIntegrationRecordChild(IntegrationTableMapping."Table ID") then
            exit;
        ToIntegrationTable := SourceRecordRef.Number() = IntegrationTableMapping."Table ID";
        SplitLocalAndIntegration(IntegrationTableMapping, SourceRecordRef, DestinationRecordRef, LocalRecordRef, IntegrationRecordRef);
        IntegrationTableModifiedOn := GetModifiedOn(IntegrationTableMapping, IntegrationRecordRef);
        LocalTableModifiedOn := GetModifiedOn(IntegrationTableMapping, LocalRecordRef);
        if BothModified then
            if ToIntegrationTable then
                IntegrationTableModifiedOn -= 999
            else
                LocalTableModifiedOn -= 10;
        IntegrationRecordManagement.UpdateIntegrationTableTimestamp(
          TableConnectionType::CRM, IntegrationRecordRef.Field(IntegrationTableMapping."Integration Table UID Fld. No.").Value(),
          IntegrationTableModifiedOn, LocalRecordRef.Number(), LocalTableModifiedOn, JobId, IntegrationTableMapping.Direction);
    end;

    /// <summary>
    /// Returns whether a record changed after its last synchronization.
    /// </summary>
    /// <param name="IntegrationTableMapping">The mapping being run.</param>
    /// <param name="RecordRef">The record, on either side.</param>
    /// <returns>True when the record changed after the time stored on its coupling.</returns>
    internal procedure WasModifiedAfterLastSynch(IntegrationTableMapping: Record "Integration Table Mapping"; var RecordRef: RecordRef): Boolean
    var
        IntegrationRecordManagement: Codeunit "Integration Record Management";
    begin
        if RecordRef.Number() = IntegrationTableMapping."Integration Table ID" then
            exit(IntegrationRecordManagement.IsModifiedAfterIntegrationTableRecordLastSynch(
              TableConnectionType::CRM, RecordRef.Field(IntegrationTableMapping."Integration Table UID Fld. No.").Value(),
              IntegrationTableMapping."Table ID", GetModifiedOn(IntegrationTableMapping, RecordRef)));
        exit(IntegrationRecordManagement.IsModifiedAfterRecordLastSynch(TableConnectionType::CRM, RecordRef, GetModifiedOn(IntegrationTableMapping, RecordRef)));
    end;

    /// <summary>
    /// Marks the coupling of a record as failed in its last synchronization.
    /// </summary>
    /// <param name="IntegrationTableMapping">The mapping being run.</param>
    /// <param name="SourceRecordRef">The record that failed.</param>
    /// <param name="JobId">The synchronization job.</param>
    /// <returns>True when the coupling was marked as skipped, because it failed repeatedly.</returns>
    internal procedure MarkFailed(IntegrationTableMapping: Record "Integration Table Mapping"; var SourceRecordRef: RecordRef; JobId: Guid) MarkedAsSkipped: Boolean
    var
        CRMIntegrationManagement: Codeunit "CRM Integration Management";
        IntegrationRecordManagement: Codeunit "Integration Record Management";
    begin
        if CRMIntegrationManagement.IsIntegrationRecordChild(IntegrationTableMapping."Table ID") then
            exit(false);
        IntegrationRecordManagement.MarkLastSynchAsFailure(
          TableConnectionType::CRM, SourceRecordRef, SourceRecordRef.Number() = IntegrationTableMapping."Table ID", JobId, MarkedAsSkipped);
    end;

    /// <summary>
    /// Returns whether a record's coupling is marked as skipped.
    /// </summary>
    /// <param name="IntegrationTableMapping">The mapping being run.</param>
    /// <param name="SourceRecordRef">The record being synchronized.</param>
    /// <returns>True when the record is skipped until someone restores it.</returns>
    internal procedure IsSkipped(IntegrationTableMapping: Record "Integration Table Mapping"; var SourceRecordRef: RecordRef): Boolean
    var
        IntegrationRecordManagement: Codeunit "Integration Record Management";
    begin
        exit(IntegrationRecordManagement.IsIntegrationRecordSkipped(
          TableConnectionType::CRM, SourceRecordRef, SourceRecordRef.Number() = IntegrationTableMapping."Table ID"));
    end;

    /// <summary>
    /// Deletes the coupling of a source record whose coupled record was deleted.
    /// </summary>
    /// <param name="IntegrationTableMapping">The mapping being run.</param>
    /// <param name="SourceRecordRef">The record being synchronized.</param>
    internal procedure DeleteCoupling(IntegrationTableMapping: Record "Integration Table Mapping"; var SourceRecordRef: RecordRef)
    var
        CRMIntegrationRecord: Record "CRM Integration Record";
    begin
        CRMIntegrationRecord.SetRange("Table ID", IntegrationTableMapping."Table ID");
        if SourceRecordRef.Number() = IntegrationTableMapping."Table ID" then
            CRMIntegrationRecord.SetRange("Integration ID", SourceRecordRef.Field(SourceRecordRef.SystemIdNo()).Value())
        else
            CRMIntegrationRecord.SetRange("CRM ID", SourceRecordRef.Field(IntegrationTableMapping."Integration Table UID Fld. No.").Value());
        CRMIntegrationRecord.DeleteAll(true);
    end;

    local procedure StampMappingName(IntegrationTableMapping: Record "Integration Table Mapping"; IntegrationTableUid: Variant; var LocalRecordRef: RecordRef)
    var
        CRMIntegrationRecord: Record "CRM Integration Record";
        MappingResolver: Codeunit "DVI Mapping Resolver";
        MappingName: Code[20];
    begin
        MappingName := MappingResolver.GetCouplingMappingName(IntegrationTableMapping);
        CRMIntegrationRecord.SetLoadFields("DVI Mapping Name");
        CRMIntegrationRecord.SetRange("CRM ID", IntegrationTableUid);
        CRMIntegrationRecord.SetRange("Integration ID", LocalRecordRef.Field(LocalRecordRef.SystemIdNo()).Value());
        if not CRMIntegrationRecord.FindFirst() then
            exit;
        if CRMIntegrationRecord."DVI Mapping Name" = MappingName then
            exit;
        CRMIntegrationRecord."DVI Mapping Name" := MappingName;
        CRMIntegrationRecord.Modify(false);
    end;

    local procedure SplitLocalAndIntegration(IntegrationTableMapping: Record "Integration Table Mapping"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef; var LocalRecordRef: RecordRef; var IntegrationRecordRef: RecordRef)
    begin
        if SourceRecordRef.Number() = IntegrationTableMapping."Table ID" then begin
            LocalRecordRef := SourceRecordRef;
            IntegrationRecordRef := DestinationRecordRef;
        end else begin
            LocalRecordRef := DestinationRecordRef;
            IntegrationRecordRef := SourceRecordRef;
        end;
    end;

    local procedure GetModifiedOn(IntegrationTableMapping: Record "Integration Table Mapping"; var RecordRef: RecordRef): DateTime
    begin
        if RecordRef.Number() = IntegrationTableMapping."Integration Table ID" then
            exit(RecordRef.Field(IntegrationTableMapping."Int. Tbl. Modified On Fld. No.").Value());
        exit(RecordRef.Field(RecordRef.SystemModifiedAtNo()).Value());
    end;
}
