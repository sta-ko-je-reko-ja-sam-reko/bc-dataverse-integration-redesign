namespace DataverseIntegration.Core;

using Microsoft.Integration.Dataverse;
using Microsoft.Integration.SyncEngine;
using Microsoft.Utilities;
using System.Reflection;

codeunit 80035 "DVI Redirect" implements "DVI IRedirectTarget"
{
    Access = Public;

    var
        NotCoupledQst: Label 'This %1 record is not coupled to a record in Business Central.', Comment = '%1 = Dataverse table caption';
        CreateOrCoupleOptionsTxt: Label 'Create it in Business Central,Couple it to an existing record';
        CoupleOnlyOptionsTxt: Label 'Couple it to an existing record';

    procedure OpenCoupledRecord(IntegrationId: Guid; EntityTypeName: Text; var Opened: Boolean; var Handled: Boolean)
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        FeatureMgt: Codeunit "DVI Feature Mgt.";
    begin
        if Handled then
            exit;
        if not FeatureMgt.IsEnabled() then
            exit;
        if not FindSwitchedMapping(EntityTypeName, IntegrationId, IntegrationTableMapping) then
            exit;
        Handled := true;
        Opened := OpenLocalRecord(IntegrationTableMapping, IntegrationId);
        if not Opened then
            Opened := OfferCoupling(IntegrationTableMapping, IntegrationId);
    end;

    local procedure FindSwitchedMapping(EntityTypeName: Text; IntegrationId: Guid; var IntegrationTableMapping: Record "Integration Table Mapping"): Boolean
    var
        CandidateMapping: Record "Integration Table Mapping";
        CRMIntegrationRecord: Record "CRM Integration Record";
        MappingResolver: Codeunit "DVI Mapping Resolver";
        LocalRecordId: RecordId;
        Found: Boolean;
    begin
        CandidateMapping.SetRange(Type, CandidateMapping.Type::Dataverse);
        CandidateMapping.SetRange("Delete After Synchronization", false);
        CandidateMapping.SetRange("Synch. Codeunit ID", Codeunit::"CRM Integration Table Synch.");
        if CandidateMapping.FindSet() then
            repeat
                if IsEntityOf(CandidateMapping, EntityTypeName) and MappingResolver.IsSwitched(CandidateMapping) then begin
                    if CRMIntegrationRecord.FindRecordIDFromID(IntegrationId, CandidateMapping."Table ID", LocalRecordId) then begin
                        IntegrationTableMapping := CandidateMapping;
                        exit(true);
                    end;
                    if not Found then begin
                        IntegrationTableMapping := CandidateMapping;
                        Found := true;
                    end;
                end;
            until CandidateMapping.Next() = 0;
        exit(Found);
    end;

    local procedure IsEntityOf(IntegrationTableMapping: Record "Integration Table Mapping"; EntityTypeName: Text): Boolean
    var
        TableMetadata: Record "Table Metadata";
    begin
        TableMetadata.SetLoadFields(ExternalName);
        if not TableMetadata.Get(IntegrationTableMapping."Integration Table ID") then
            exit(false);
        exit(LowerCase(TableMetadata.ExternalName) = LowerCase(EntityTypeName));
    end;

    local procedure OpenLocalRecord(IntegrationTableMapping: Record "Integration Table Mapping"; IntegrationId: Guid): Boolean
    var
        MappingResolver: Codeunit "DVI Mapping Resolver";
        LocalRecordView: Interface "DVI ILocalRecordView";
    begin
        LocalRecordView := MappingResolver.GetHandler(IntegrationTableMapping);
        exit(LocalRecordView.OpenLocalRecord(IntegrationTableMapping, IntegrationId));
    end;

    local procedure OfferCoupling(IntegrationTableMapping: Record "Integration Table Mapping"; IntegrationId: Guid): Boolean
    var
        TableMetadata: Record "Table Metadata";
        TableSynch: Codeunit "DVI Table Synch.";
        CanCreate: Boolean;
    begin
        if not GuiAllowed() then
            exit(false);
        TableMetadata.SetLoadFields(Caption);
        TableMetadata.Get(IntegrationTableMapping."Integration Table ID");
        CanCreate := IntegrationTableMapping.Direction in [IntegrationTableMapping.Direction::FromIntegrationTable, IntegrationTableMapping.Direction::Bidirectional];
        if CanCreate then
            case StrMenu(CreateOrCoupleOptionsTxt, 1, StrSubstNo(NotCoupledQst, TableMetadata.Caption)) of
                1:
                    begin
                        TableSynch.SynchronizeIntegrationRecord(IntegrationTableMapping, IntegrationId);
                        exit(OpenLocalRecord(IntegrationTableMapping, IntegrationId));
                    end;
                2:
                    exit(CoupleToExistingRecord(IntegrationTableMapping, IntegrationId));
            end
        else
            if StrMenu(CoupleOnlyOptionsTxt, 1, StrSubstNo(NotCoupledQst, TableMetadata.Caption)) = 1 then
                exit(CoupleToExistingRecord(IntegrationTableMapping, IntegrationId));
        exit(false);
    end;

    local procedure CoupleToExistingRecord(IntegrationTableMapping: Record "Integration Table Mapping"; IntegrationId: Guid): Boolean
    var
        CouplingStore: Codeunit "DVI Coupling Store";
        RecordLookup: Codeunit "DVI Record Lookup";
        LocalRecordRef: RecordRef;
        IntegrationRecordRef: RecordRef;
    begin
        if not RecordLookup.LookupRecord(IntegrationTableMapping."Table ID", LocalRecordRef) then
            exit(false);
        if not IntegrationTableMapping.GetRecordRef(IntegrationId, IntegrationRecordRef) then
            exit(false);
        CouplingStore.UpdateCoupling(IntegrationTableMapping, LocalRecordRef, IntegrationRecordRef);
        exit(OpenLocalRecord(IntegrationTableMapping, IntegrationId));
    end;
}
