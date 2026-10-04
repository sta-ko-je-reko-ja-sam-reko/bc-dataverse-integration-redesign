namespace DataverseIntegration.Core;

using Microsoft.Integration.D365Sales;
using Microsoft.Integration.Dataverse;
using Microsoft.Integration.SyncEngine;
using System.Reflection;
using System.Utilities;

codeunit 80023 "DVI Integration Record Reader"
{
    Access = Internal;

    var
        ModifiedByFieldMustBeGuidErr: Label 'The %1 field in the %2 table must be of type GUID.', Comment = '%1 = field name, %2 = table name';

    /// <summary>
    /// Loads the Dataverse records a scheduled run synchronizes into a temporary RecordRef: records whose last synchronization failed, then records changed after the mapping's watermark.
    /// </summary>
    /// <param name="IntegrationTableMapping">The mapping being run.</param>
    /// <param name="TempIntegrationRecordRef">Receives the records; opened as temporary on the integration table.</param>
    internal procedure LoadRecords(IntegrationTableMapping: Record "Integration Table Mapping"; var TempIntegrationRecordRef: RecordRef)
    var
        LoadedIds: Dictionary of [Guid, Boolean];
    begin
        TempIntegrationRecordRef.Open(IntegrationTableMapping."Integration Table ID", true);
        LoadFailedRecords(IntegrationTableMapping, TempIntegrationRecordRef, LoadedIds);
        LoadModifiedRecords(IntegrationTableMapping, TempIntegrationRecordRef, LoadedIds);
    end;

    local procedure LoadFailedRecords(IntegrationTableMapping: Record "Integration Table Mapping"; var TempIntegrationRecordRef: RecordRef; var LoadedIds: Dictionary of [Guid, Boolean])
    var
        CRMIntegrationRecord: Record "CRM Integration Record";
        IntegrationRecordRef: RecordRef;
    begin
        IntegrationRecordRef.Open(IntegrationTableMapping."Integration Table ID");
        IntegrationRecordRef.SetView(IntegrationTableMapping.GetIntegrationTableFilter());
        if IntegrationRecordRef.Field(IntegrationTableMapping."Integration Table UID Fld. No.").GetFilter() <> '' then
            exit;
        CRMIntegrationRecord.SetLoadFields("CRM ID");
        CRMIntegrationRecord.SetRange("Table ID", IntegrationTableMapping."Table ID");
        CRMIntegrationRecord.SetRange(Skipped, false);
        CRMIntegrationRecord.SetRange("Last Synch. Result", CRMIntegrationRecord."Last Synch. Result"::Failure);
        if CRMIntegrationRecord.FindSet() then
            repeat
                IntegrationRecordRef.Reset();
                IntegrationRecordRef.Field(IntegrationTableMapping."Integration Table UID Fld. No.").SetRange(CRMIntegrationRecord."CRM ID");
                if IntegrationRecordRef.FindFirst() then
                    AddRecord(IntegrationTableMapping, IntegrationRecordRef, TempIntegrationRecordRef, LoadedIds);
            until CRMIntegrationRecord.Next() = 0;
    end;

    local procedure LoadModifiedRecords(IntegrationTableMapping: Record "Integration Table Mapping"; var TempIntegrationRecordRef: RecordRef; var LoadedIds: Dictionary of [Guid, Boolean])
    var
        IntegrationRecordRef: RecordRef;
    begin
        IntegrationRecordRef.Open(IntegrationTableMapping."Integration Table ID");
        IntegrationRecordRef.SetView(IntegrationTableMapping.GetIntegrationTableFilter());
        if IntegrationTableMapping."Synch. Modified On Filter" <> 0DT then
            IntegrationRecordRef.Field(IntegrationTableMapping."Int. Tbl. Modified On Fld. No.").SetFilter('>%1', IntegrationTableMapping."Synch. Modified On Filter" - 999);
        if IsModifiedByFilterNeeded(IntegrationTableMapping) then
            SetModifiedByFilter(IntegrationTableMapping, IntegrationRecordRef);
        if IntegrationRecordRef.FindSet() then
            repeat
                AddRecord(IntegrationTableMapping, IntegrationRecordRef, TempIntegrationRecordRef, LoadedIds);
            until IntegrationRecordRef.Next() = 0;
    end;

    local procedure AddRecord(IntegrationTableMapping: Record "Integration Table Mapping"; var IntegrationRecordRef: RecordRef; var TempIntegrationRecordRef: RecordRef; var LoadedIds: Dictionary of [Guid, Boolean])
    var
        IntegrationId: Guid;
    begin
        IntegrationId := IntegrationRecordRef.Field(IntegrationTableMapping."Integration Table UID Fld. No.").Value();
        if LoadedIds.ContainsKey(IntegrationId) then
            exit;
        LoadedIds.Add(IntegrationId, true);
        CopyRecord(IntegrationTableMapping, IntegrationRecordRef, TempIntegrationRecordRef);
    end;

    local procedure CopyRecord(IntegrationTableMapping: Record "Integration Table Mapping"; var FromRecordRef: RecordRef; var ToRecordRef: RecordRef)
    var
        TempBlob: Codeunit "Temp Blob";
        FromFieldRef: FieldRef;
        ToFieldRef: FieldRef;
        FieldIndex: Integer;
    begin
        ToRecordRef.Init();
        for FieldIndex := 1 to FromRecordRef.FieldCount() do begin
            FromFieldRef := FromRecordRef.FieldIndex(FieldIndex);
            if FromFieldRef.Type() <> FieldType::TableFilter then begin
                ToFieldRef := ToRecordRef.Field(FromFieldRef.Number());
                if FromFieldRef.Type() <> FieldType::Blob then
                    ToFieldRef.Value(FromFieldRef.Value())
                else
                    if IsFieldMapped(IntegrationTableMapping, FromFieldRef.Number()) then begin
                        TempBlob.FromFieldRef(FromFieldRef);
                        TempBlob.ToFieldRef(ToFieldRef);
                    end;
            end;
        end;
        ToRecordRef.Insert(false);
    end;

    local procedure IsFieldMapped(IntegrationTableMapping: Record "Integration Table Mapping"; IntegrationFieldNo: Integer): Boolean
    var
        IntegrationFieldMapping: Record "Integration Field Mapping";
    begin
        IntegrationFieldMapping.SetRange("Integration Table Mapping Name", IntegrationTableMapping.Name);
        IntegrationFieldMapping.SetRange("Integration Table Field No.", IntegrationFieldNo);
        exit(not IntegrationFieldMapping.IsEmpty());
    end;

    local procedure IsModifiedByFilterNeeded(IntegrationTableMapping: Record "Integration Table Mapping"): Boolean
    var
        IntegrationFieldMapping: Record "Integration Field Mapping";
    begin
        if IntegrationTableMapping."Delete After Synchronization" then
            exit(false);
        if IntegrationTableMapping.Direction <> IntegrationTableMapping.Direction::Bidirectional then
            exit(false);
        IntegrationFieldMapping.SetRange("Integration Table Mapping Name", IntegrationTableMapping.Name);
        IntegrationFieldMapping.SetRange(Direction, IntegrationFieldMapping.Direction::FromIntegrationTable);
        IntegrationFieldMapping.SetFilter("Integration Table Field No.", '>0');
        IntegrationFieldMapping.SetFilter(Status, '<>%1', IntegrationFieldMapping.Status::Disabled);
        exit(IntegrationFieldMapping.IsEmpty());
    end;

    local procedure SetModifiedByFilter(IntegrationTableMapping: Record "Integration Table Mapping"; var IntegrationRecordRef: RecordRef)
    var
        ModifiedByFieldRef: FieldRef;
    begin
        ModifiedByFieldRef := IntegrationRecordRef.Field(GetModifiedByFieldNo(IntegrationTableMapping."Integration Table ID"));
        if ModifiedByFieldRef.Type() <> FieldType::GUID then
            Error(ModifiedByFieldMustBeGuidErr, ModifiedByFieldRef.Name(), IntegrationRecordRef.Name());
        ModifiedByFieldRef.SetFilter('<>%1', GetIntegrationUserId());
    end;

    local procedure GetModifiedByFieldNo(IntegrationTableId: Integer): Integer
    var
        "Field": Record "Field";
    begin
        Field.SetLoadFields("No.");
        Field.SetRange(TableNo, IntegrationTableId);
        Field.SetRange(FieldName, 'ModifiedBy');
        Field.FindFirst();
        exit(Field."No.");
    end;

    local procedure GetIntegrationUserId(): Guid
    var
        CRMConnectionSetup: Record "CRM Connection Setup";
        CRMIntegrationManagement: Codeunit "CRM Integration Management";
        IntegrationUserId: Guid;
        Handled: Boolean;
    begin
        CRMIntegrationManagement.OnGetCDSIntegrationUserId(IntegrationUserId, Handled);
        if Handled then
            exit(IntegrationUserId);
        exit(CRMConnectionSetup.GetIntegrationUserID());
    end;
}
