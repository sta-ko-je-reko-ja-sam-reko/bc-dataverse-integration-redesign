namespace DataverseIntegration.CRM;

using DataverseIntegration.Core;
using Microsoft.Foundation.UOM;
using Microsoft.Integration.D365Sales;
using Microsoft.Integration.SyncEngine;

codeunit 80401 "DVI Unit Group Handler" implements "DVI IRecordSync", "DVI IRecordCoupling", "DVI IHandlerScope"
{
    Access = Public;

    procedure Serves(var Context: Codeunit "DVI Sync Context"): Boolean
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
    begin
        Context.GetMapping(IntegrationTableMapping);
        exit((IntegrationTableMapping."Table ID" in [Database::"Unit Group", Database::"Unit of Measure"]) and (IntegrationTableMapping."Integration Table ID" = Database::"CRM Uomschedule"));
    end;

    procedure DefaultModule(var Context: Codeunit "DVI Sync Context"): Enum "DVI Integration Module"
    begin
        exit(Enum::"DVI Integration Module"::DVISales);
    end;

    procedure BeforeTransferFields(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    begin
    end;

    procedure AfterTransferFields(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef; var AdditionalFieldsModified: Boolean)
    var
        CRMUnits: Codeunit "DVI CRM Units";
    begin
        AdditionalFieldsModified := false;
        if not Context.IsToIntegrationTable() then
            exit;
        case SourceRecordRef.Number() of
            Database::"Unit of Measure":
                AdditionalFieldsModified := CRMUnits.UpdateScheduleOfUnitOfMeasure(SourceRecordRef, DestinationRecordRef);
            Database::"Unit Group":
                CRMUnits.CheckScheduleIsActive(DestinationRecordRef);
        end;
    end;

    procedure BeforeInsert(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    begin
    end;

    procedure AfterInsert(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    begin
    end;

    procedure BeforeModify(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    begin
    end;

    procedure AfterModify(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    begin
    end;

    procedure Unchanged(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    begin
    end;

    procedure FindUncoupledDestination(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef; var DestinationIsDeleted: Boolean): Boolean
    var
        CRMUnits: Codeunit "DVI CRM Units";
    begin
        DestinationIsDeleted := false;
        if SourceRecordRef.Number() <> Database::"Unit of Measure" then
            exit(false);
        exit(CRMUnits.FindScheduleOfUnitOfMeasure(SourceRecordRef, DestinationRecordRef));
    end;

    procedure AfterCouple(var Context: Codeunit "DVI Sync Context"; var LocalRecordRef: RecordRef; var IntegrationRecordRef: RecordRef)
    begin
    end;

    procedure BeforeUncouple(var Context: Codeunit "DVI Sync Context"; var LocalRecordRef: RecordRef; var IntegrationRecordRef: RecordRef)
    begin
    end;

    procedure AfterUncouple(var Context: Codeunit "DVI Sync Context"; var LocalRecordRef: RecordRef; var IntegrationRecordRef: RecordRef)
    begin
    end;

    procedure SetMatchingFilter(var Context: Codeunit "DVI Sync Context"; var IntegrationRecordRef: RecordRef; var MatchingIntegrationFieldRef: FieldRef; var LocalRecordRef: RecordRef; var MatchingLocalFieldRef: FieldRef): Boolean
    var
        UnitGroup: Record "Unit Group";
        CRMUomschedule: Record "CRM Uomschedule";
    begin
        if (IntegrationRecordRef.Number() <> Database::"CRM Uomschedule") or (LocalRecordRef.Number() <> Database::"Unit Group") then
            exit(false);
        if (MatchingIntegrationFieldRef.Number() <> CRMUomschedule.FieldNo(Name)) or (MatchingLocalFieldRef.Number() <> UnitGroup.FieldNo("Source No.")) then
            exit(false);
        LocalRecordRef.SetTable(UnitGroup);
        MatchingIntegrationFieldRef.SetRange(UnitGroup.GetCode());
        exit(true);
    end;

    procedure CreateNewOnNoMatch(var Context: Codeunit "DVI Sync Context"): Boolean
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
    begin
        Context.GetMapping(IntegrationTableMapping);
        exit(IntegrationTableMapping."Create New in Case of No Match");
    end;
}
