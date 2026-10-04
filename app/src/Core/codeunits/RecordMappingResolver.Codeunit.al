namespace DataverseIntegration.Core;

using Microsoft.Integration.Dataverse;
using Microsoft.Integration.SyncEngine;

codeunit 80031 "DVI Record Mapping Resolver"
{
    Access = Internal;

    /// <summary>
    /// Resolves the mapping and coupling of a Business Central record. Without a Dataverse table: first the mapping stamped on its coupling, then the only mapping of its table, then a switched mapping whose connection is enabled, then the first mapping of the table. With a Dataverse table: the mapping to that table and the coupling to a record of that table.
    /// </summary>
    /// <param name="RecordId">The Business Central record.</param>
    /// <param name="IntegrationTableId">The Dataverse table, or 0 for any.</param>
    /// <param name="Context">Receives the record, its mapping and its coupling.</param>
    /// <returns>True when the record's table has a mapping.</returns>
    internal procedure Resolve(RecordId: RecordId; IntegrationTableId: Integer; var Context: Codeunit "DVI Record Action Context"): Boolean
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        CRMIntegrationRecord: Record "CRM Integration Record";
        IntegrationId: Guid;
    begin
        Context.SetRecord(RecordId);
        if IntegrationTableId <> 0 then begin
            if not FindTableMapping(RecordId.TableNo(), IntegrationTableId, IntegrationTableMapping) then
                exit(false);
            Context.SetMapping(IntegrationTableMapping);
            if FindCouplingTo(RecordId, IntegrationTableMapping, IntegrationId) then
                Context.SetCoupling(IntegrationId);
            exit(true);
        end;
        if CRMIntegrationRecord.FindIDFromRecordID(RecordId, IntegrationId) then
            Context.SetCoupling(IntegrationId);
        if FindStampedMapping(RecordId, IntegrationId, IntegrationTableMapping) or FindTableMapping(RecordId.TableNo(), 0, IntegrationTableMapping) then begin
            Context.SetMapping(IntegrationTableMapping);
            exit(true);
        end;
        exit(false);
    end;

    local procedure FindCouplingTo(RecordId: RecordId; IntegrationTableMapping: Record "Integration Table Mapping"; var IntegrationId: Guid): Boolean
    var
        CRMIntegrationRecord: Record "CRM Integration Record";
        StampedIntegrationTableMapping: Record "Integration Table Mapping";
        RecordRef: RecordRef;
        IntegrationRecordRef: RecordRef;
    begin
        if not RecordRef.Get(RecordId) then
            exit(false);
        CRMIntegrationRecord.SetLoadFields("CRM ID", "DVI Mapping Name");
        CRMIntegrationRecord.SetRange("Integration ID", RecordRef.Field(RecordRef.SystemIdNo()).Value());
        CRMIntegrationRecord.SetRange("Table ID", RecordId.TableNo());
        if CRMIntegrationRecord.FindSet() then
            repeat
                if CRMIntegrationRecord."DVI Mapping Name" <> '' then begin
                    if StampedIntegrationTableMapping.Get(CRMIntegrationRecord."DVI Mapping Name") then
                        if StampedIntegrationTableMapping."Integration Table ID" = IntegrationTableMapping."Integration Table ID" then begin
                            IntegrationId := CRMIntegrationRecord."CRM ID";
                            exit(true);
                        end;
                end else begin
                    IntegrationRecordRef.Open(IntegrationTableMapping."Integration Table ID");
                    IntegrationRecordRef.Field(IntegrationTableMapping."Integration Table UID Fld. No.").SetRange(CRMIntegrationRecord."CRM ID");
                    if not IntegrationRecordRef.IsEmpty() then begin
                        IntegrationId := CRMIntegrationRecord."CRM ID";
                        exit(true);
                    end;
                    IntegrationRecordRef.Close();
                end;
            until CRMIntegrationRecord.Next() = 0;
        exit(false);
    end;

    local procedure FindStampedMapping(RecordId: RecordId; IntegrationId: Guid; var IntegrationTableMapping: Record "Integration Table Mapping"): Boolean
    var
        CRMIntegrationRecord: Record "CRM Integration Record";
        RecordRef: RecordRef;
    begin
        if IsNullGuid(IntegrationId) then
            exit(false);
        if not RecordRef.Get(RecordId) then
            exit(false);
        CRMIntegrationRecord.SetLoadFields("DVI Mapping Name");
        CRMIntegrationRecord.SetRange("CRM ID", IntegrationId);
        CRMIntegrationRecord.SetRange("Integration ID", RecordRef.Field(RecordRef.SystemIdNo()).Value());
        if not CRMIntegrationRecord.FindFirst() then
            exit(false);
        if CRMIntegrationRecord."DVI Mapping Name" = '' then
            exit(false);
        exit(IntegrationTableMapping.Get(CRMIntegrationRecord."DVI Mapping Name"));
    end;

    local procedure FindTableMapping(TableId: Integer; IntegrationTableId: Integer; var IntegrationTableMapping: Record "Integration Table Mapping"): Boolean
    var
        MappingResolver: Codeunit "DVI Mapping Resolver";
        Connection: Interface "DVI IConnection";
    begin
        IntegrationTableMapping.SetRange(Type, IntegrationTableMapping.Type::Dataverse);
        IntegrationTableMapping.SetRange("Table ID", TableId);
        if IntegrationTableId <> 0 then
            IntegrationTableMapping.SetRange("Integration Table ID", IntegrationTableId);
        IntegrationTableMapping.SetRange("Delete After Synchronization", false);
        IntegrationTableMapping.SetRange("Synch. Codeunit ID", Codeunit::"CRM Integration Table Synch.");
        case IntegrationTableMapping.Count() of
            0:
                exit(false);
            1:
                exit(IntegrationTableMapping.FindFirst());
        end;
        if IntegrationTableMapping.FindSet() then
            repeat
                if MappingResolver.IsSwitched(IntegrationTableMapping) then begin
                    Connection := MappingResolver.GetModule(IntegrationTableMapping);
                    if Connection.IsEnabled() then
                        exit(true);
                end;
            until IntegrationTableMapping.Next() = 0;
        exit(IntegrationTableMapping.FindFirst());
    end;
}
