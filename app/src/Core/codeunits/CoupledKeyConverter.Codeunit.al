namespace DataverseIntegration.Core;

using Microsoft.Integration.Dataverse;
using Microsoft.Integration.SyncEngine;

codeunit 80046 "DVI Coupled Key Converter" implements "DVI IValueConverter"
{
    Access = Public;

    var
        RecordMustBeCoupledErr: Label '%1 %2 must be coupled to a record in Dataverse.', Comment = '%1 = field name, %2 = value';
        DataverseRecordMustBeCoupledErr: Label 'The Dataverse record %2 in %1 must be coupled to a record in Business Central.', Comment = '%1 = field name, %2 = Dataverse ID';

    procedure AppliesTo(var Context: Codeunit "DVI Sync Context"; var SourceFieldRef: FieldRef; var DestinationFieldRef: FieldRef): Boolean
    var
        RelatedIntegrationTableMapping: Record "Integration Table Mapping";
    begin
        exit(FindRelatedMapping(SourceFieldRef, DestinationFieldRef, RelatedIntegrationTableMapping));
    end;

    procedure Convert(var Context: Codeunit "DVI Sync Context"; var SourceFieldRef: FieldRef; var DestinationFieldRef: FieldRef; var NewValue: Variant; var NeedsConversion: Boolean): Boolean
    var
        RelatedIntegrationTableMapping: Record "Integration Table Mapping";
    begin
        NeedsConversion := false;
        if not FindRelatedMapping(SourceFieldRef, DestinationFieldRef, RelatedIntegrationTableMapping) then
            exit(false);
        if DestinationFieldRef.Type() = FieldType::GUID then
            exit(ConvertToIntegrationId(Context, RelatedIntegrationTableMapping, SourceFieldRef, DestinationFieldRef, NewValue));
        exit(ConvertToLocalKey(Context, RelatedIntegrationTableMapping, SourceFieldRef, DestinationFieldRef, NewValue));
    end;

    local procedure ConvertToIntegrationId(var Context: Codeunit "DVI Sync Context"; RelatedIntegrationTableMapping: Record "Integration Table Mapping"; var SourceFieldRef: FieldRef; var DestinationFieldRef: FieldRef; var NewValue: Variant): Boolean
    var
        CRMIntegrationRecord: Record "CRM Integration Record";
        CRMSynchHelper: Codeunit "CRM Synch. Helper";
        RelatedRecordId: RecordId;
        IntegrationId: Guid;
        EmptyId: Guid;
    begin
        if Format(SourceFieldRef.Value()) = '' then begin
            NewValue := EmptyId;
            exit(true);
        end;
        if CRMSynchHelper.FindRecordIDByPK(RelatedIntegrationTableMapping."Table ID", SourceFieldRef.Value(), RelatedRecordId) then
            if CRMIntegrationRecord.FindIDFromRecordID(RelatedRecordId, IntegrationId) then begin
                NewValue := IntegrationId;
                exit(true);
            end;
        if IsClearValueOnFailedSync(Context, SourceFieldRef, DestinationFieldRef) then begin
            NewValue := EmptyId;
            exit(true);
        end;
        Error(RecordMustBeCoupledErr, SourceFieldRef.Name(), SourceFieldRef.Value());
    end;

    local procedure ConvertToLocalKey(var Context: Codeunit "DVI Sync Context"; RelatedIntegrationTableMapping: Record "Integration Table Mapping"; var SourceFieldRef: FieldRef; var DestinationFieldRef: FieldRef; var NewValue: Variant): Boolean
    var
        CRMIntegrationRecord: Record "CRM Integration Record";
        CRMSynchHelper: Codeunit "CRM Synch. Helper";
        RelatedRecordId: RecordId;
        IntegrationId: Guid;
        PrimaryKey: Variant;
    begin
        IntegrationId := SourceFieldRef.Value();
        if IsNullGuid(IntegrationId) then begin
            NewValue := '';
            exit(true);
        end;
        if CRMIntegrationRecord.FindRecordIDFromID(IntegrationId, RelatedIntegrationTableMapping."Table ID", RelatedRecordId) then
            if CRMSynchHelper.FindPKByRecordID(RelatedRecordId, PrimaryKey) then begin
                NewValue := PrimaryKey;
                exit(true);
            end;
        if IsClearValueOnFailedSync(Context, SourceFieldRef, DestinationFieldRef) then begin
            NewValue := '';
            exit(true);
        end;
        Error(DataverseRecordMustBeCoupledErr, SourceFieldRef.Name(), IntegrationId);
    end;

    /// <summary>
    /// Finds the mapping between the tables that a pair of related fields points to, preferring a switched mapping.
    /// </summary>
    /// <param name="SourceFieldRef">The source field.</param>
    /// <param name="DestinationFieldRef">The destination field.</param>
    /// <param name="RelatedIntegrationTableMapping">Receives the mapping of the related tables.</param>
    /// <returns>True when both fields relate to tables that a Dataverse mapping couples.</returns>
    internal procedure FindRelatedMapping(var SourceFieldRef: FieldRef; var DestinationFieldRef: FieldRef; var RelatedIntegrationTableMapping: Record "Integration Table Mapping"): Boolean
    var
        MappingResolver: Codeunit "DVI Mapping Resolver";
    begin
        if (SourceFieldRef.Relation() = 0) or (DestinationFieldRef.Relation() = 0) then
            exit(false);
        RelatedIntegrationTableMapping.SetRange(Type, RelatedIntegrationTableMapping.Type::Dataverse);
        RelatedIntegrationTableMapping.SetRange("Delete After Synchronization", false);
        if DestinationFieldRef.Type() = FieldType::GUID then begin
            RelatedIntegrationTableMapping.SetRange("Table ID", SourceFieldRef.Relation());
            RelatedIntegrationTableMapping.SetRange("Integration Table ID", DestinationFieldRef.Relation());
        end else begin
            RelatedIntegrationTableMapping.SetRange("Table ID", DestinationFieldRef.Relation());
            RelatedIntegrationTableMapping.SetRange("Integration Table ID", SourceFieldRef.Relation());
        end;
        if RelatedIntegrationTableMapping.FindSet() then
            repeat
                if MappingResolver.IsSwitched(RelatedIntegrationTableMapping) then
                    exit(true);
            until RelatedIntegrationTableMapping.Next() = 0;
        exit(RelatedIntegrationTableMapping.FindFirst());
    end;

    local procedure IsClearValueOnFailedSync(var Context: Codeunit "DVI Sync Context"; var SourceFieldRef: FieldRef; var DestinationFieldRef: FieldRef): Boolean
    var
        IntegrationFieldMapping: Record "Integration Field Mapping";
    begin
        IntegrationFieldMapping.SetLoadFields("Clear Value on Failed Sync");
        IntegrationFieldMapping.SetRange("Integration Table Mapping Name", Context.GetMappingName());
        if Context.IsToIntegrationTable() then begin
            IntegrationFieldMapping.SetRange("Field No.", SourceFieldRef.Number());
            IntegrationFieldMapping.SetRange("Integration Table Field No.", DestinationFieldRef.Number());
        end else begin
            IntegrationFieldMapping.SetRange("Field No.", DestinationFieldRef.Number());
            IntegrationFieldMapping.SetRange("Integration Table Field No.", SourceFieldRef.Number());
        end;
        if not IntegrationFieldMapping.FindFirst() then
            exit(false);
        exit(IntegrationFieldMapping."Clear Value on Failed Sync");
    end;
}
