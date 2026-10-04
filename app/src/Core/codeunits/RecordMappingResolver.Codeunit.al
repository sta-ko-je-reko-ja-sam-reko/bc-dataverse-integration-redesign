namespace DataverseIntegration.Core;

using Microsoft.Integration.Dataverse;
using Microsoft.Integration.SyncEngine;

codeunit 80031 "DVI Record Mapping Resolver"
{
    Access = Internal;

    /// <summary>
    /// Resolves the mapping and coupling of a Business Central record: first the mapping stamped on its coupling, then the only mapping of its table, then a switched mapping whose connection is enabled, then the first mapping of the table.
    /// </summary>
    /// <param name="RecordId">The Business Central record.</param>
    /// <param name="Context">Receives the record, its mapping and its coupling.</param>
    /// <returns>True when the record's table has a mapping.</returns>
    internal procedure Resolve(RecordId: RecordId; var Context: Codeunit "DVI Record Action Context"): Boolean
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        CRMIntegrationRecord: Record "CRM Integration Record";
        IntegrationId: Guid;
    begin
        Context.SetRecord(RecordId);
        if CRMIntegrationRecord.FindIDFromRecordID(RecordId, IntegrationId) then
            Context.SetCoupling(IntegrationId);
        if FindStampedMapping(RecordId, IntegrationId, IntegrationTableMapping) or FindTableMapping(RecordId.TableNo(), IntegrationTableMapping) then begin
            Context.SetMapping(IntegrationTableMapping);
            exit(true);
        end;
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

    local procedure FindTableMapping(TableId: Integer; var IntegrationTableMapping: Record "Integration Table Mapping"): Boolean
    var
        MappingResolver: Codeunit "DVI Mapping Resolver";
        Connection: Interface "DVI IConnection";
    begin
        IntegrationTableMapping.SetRange(Type, IntegrationTableMapping.Type::Dataverse);
        IntegrationTableMapping.SetRange("Table ID", TableId);
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
