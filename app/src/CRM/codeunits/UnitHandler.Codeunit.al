namespace DataverseIntegration.CRM;

using DataverseIntegration.Core;
using Microsoft.Foundation.UOM;
using Microsoft.Integration.D365Sales;
using Microsoft.Integration.SyncEngine;
using Microsoft.Inventory.Item;
using Microsoft.Projects.Resources.Resource;

codeunit 80402 "DVI Unit Handler" implements "DVI IRecordSync", "DVI IRecordCoupling", "DVI IHandlerScope"
{
    Access = Public;

    procedure Serves(var Context: Codeunit "DVI Sync Context"): Boolean
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
    begin
        Context.GetMapping(IntegrationTableMapping);
        exit((IntegrationTableMapping."Table ID" in [Database::"Item Unit of Measure", Database::"Resource Unit of Measure"]) and (IntegrationTableMapping."Integration Table ID" = Database::"CRM Uom"));
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
        if Context.IsToIntegrationTable() then
            AdditionalFieldsModified := CRMUnits.UpdateUnit(Context, SourceRecordRef, DestinationRecordRef);
    end;

    procedure BeforeInsert(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    begin
    end;

    procedure AfterInsert(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    var
        CRMUnits: Codeunit "DVI CRM Units";
    begin
        if Context.IsToIntegrationTable() then
            CRMUnits.UpdatePriceListItemOfUnit(SourceRecordRef, DestinationRecordRef);
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
    begin
        DestinationIsDeleted := false;
        exit(false);
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
        Item: Record Item;
        Resource: Record Resource;
        ItemUnitOfMeasure: Record "Item Unit of Measure";
        ResourceUnitOfMeasure: Record "Resource Unit of Measure";
        CRMUomschedule: Record "CRM Uomschedule";
        CRMUom: Record "CRM Uom";
    begin
        if IntegrationRecordRef.Number() <> Database::"CRM Uom" then
            exit(false);
        if MatchingIntegrationFieldRef.Number() <> CRMUom.FieldNo(Name) then
            exit(false);
        case LocalRecordRef.Number() of
            Database::"Item Unit of Measure":
                begin
                    LocalRecordRef.SetTable(ItemUnitOfMeasure);
                    if Item.Get(ItemUnitOfMeasure."Item No.") then
                        if not UnitGroup.Get(UnitGroup."Source Type"::Item, Item.SystemId) then
                            exit(false);
                end;
            Database::"Resource Unit of Measure":
                begin
                    LocalRecordRef.SetTable(ResourceUnitOfMeasure);
                    if Resource.Get(ResourceUnitOfMeasure."Resource No.") then
                        if not UnitGroup.Get(UnitGroup."Source Type"::Resource, Resource.SystemId) then
                            exit(false);
                end;
            else
                exit(false);
        end;
        CRMUomschedule.SetRange(Name, UnitGroup.GetCode());
        if CRMUomschedule.FindFirst() then
            IntegrationRecordRef.Field(CRMUom.FieldNo(UoMScheduleId)).SetRange(CRMUomschedule.UoMScheduleId);
        exit(false);
    end;

    procedure CreateNewOnNoMatch(var Context: Codeunit "DVI Sync Context"): Boolean
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
    begin
        Context.GetMapping(IntegrationTableMapping);
        exit(IntegrationTableMapping."Create New in Case of No Match");
    end;
}
