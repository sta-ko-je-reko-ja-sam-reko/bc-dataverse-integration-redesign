namespace DataverseIntegration.CRM;

using DataverseIntegration.CDS;
using DataverseIntegration.Core;
using Microsoft.Foundation.UOM;
using Microsoft.Integration.D365Sales;
using Microsoft.Integration.Dataverse;
using Microsoft.Integration.SyncEngine;
using Microsoft.Inventory.Item;
using Microsoft.Projects.Resources.Resource;

codeunit 80411 "DVI CRM Units"
{
    Access = Internal;

    var
        UnitGroupInactiveErr: Label 'The %1 %2 exists in Dataverse but is inactive.', Comment = '%1 = table caption, %2 = unit group name';
        UnitGroupHasSeveralUnitsErr: Label 'The %1 %2 in Dataverse contains more than one %3.', Comment = '%1 = unit group table caption, %2 = unit group name, %3 = unit table caption';
        UnitGroupNotSynchronizedErr: Label 'The unit group %1 is not synchronized to Dataverse yet. It has been queued for synchronization; this unit is synchronized again in the next run.', Comment = '%1 = unit group code';
        UnitGroupOfItemNotFoundErr: Label 'The unit group of %1 %2 was not found.', Comment = '%1 = table caption, %2 = number';

    /// <summary>
    /// Names the Dataverse unit schedule of a Business Central unit of measure and validates its single unit.
    /// </summary>
    /// <param name="UnitOfMeasureRecordRef">The unit of measure.</param>
    /// <param name="ScheduleRecordRef">The Dataverse unit schedule.</param>
    /// <returns>True when a field of the schedule or its unit changed.</returns>
    internal procedure UpdateScheduleOfUnitOfMeasure(var UnitOfMeasureRecordRef: RecordRef; var ScheduleRecordRef: RecordRef): Boolean
    var
        CRMUomschedule: Record "CRM Uomschedule";
        CRMSynchHelper: Codeunit "CRM Synch. Helper";
        NameFieldRef: FieldRef;
        UnitOfMeasureName: Text[100];
        ScheduleName: Text[200];
        Modified: Boolean;
    begin
        UnitOfMeasureName := CRMSynchHelper.GetUnitOfMeasureName(UnitOfMeasureRecordRef);
        ScheduleName := CRMSynchHelper.GetUnitGroupName(UnitOfMeasureName);
        NameFieldRef := ScheduleRecordRef.Field(CRMUomschedule.FieldNo(Name));
        if Format(NameFieldRef.Value()) <> ScheduleName then begin
            NameFieldRef.Value(ScheduleName);
            Modified := true;
        end;
        if ValidateSchedule(ScheduleName, ScheduleRecordRef.Field(CRMUomschedule.FieldNo(StateCode)).Value(), ScheduleRecordRef.Field(CRMUomschedule.FieldNo(UoMScheduleId)).Value(), UnitOfMeasureName) then
            Modified := true;
        exit(Modified);
    end;

    /// <summary>
    /// Raises an error when the Dataverse unit schedule of a unit group is inactive.
    /// </summary>
    /// <param name="ScheduleRecordRef">The Dataverse unit schedule.</param>
    internal procedure CheckScheduleIsActive(var ScheduleRecordRef: RecordRef)
    var
        CRMUomschedule: Record "CRM Uomschedule";
        StateCode: Integer;
    begin
        StateCode := ScheduleRecordRef.Field(CRMUomschedule.FieldNo(StateCode)).Value();
        if StateCode = CRMUomschedule.StateCode::Inactive then
            Error(UnitGroupInactiveErr, CRMUomschedule.TableCaption(), Format(ScheduleRecordRef.Field(CRMUomschedule.FieldNo(Name)).Value()));
    end;

    /// <summary>
    /// Finds the existing Dataverse unit schedule of a Business Central unit of measure.
    /// </summary>
    /// <param name="UnitOfMeasureRecordRef">The unit of measure.</param>
    /// <param name="ScheduleRecordRef">Receives the unit schedule.</param>
    /// <returns>True when a schedule with the expected name exists.</returns>
    internal procedure FindScheduleOfUnitOfMeasure(var UnitOfMeasureRecordRef: RecordRef; var ScheduleRecordRef: RecordRef): Boolean
    var
        CRMUomschedule: Record "CRM Uomschedule";
        CRMSynchHelper: Codeunit "CRM Synch. Helper";
        UnitOfMeasureName: Text[100];
    begin
        UnitOfMeasureName := CRMSynchHelper.GetUnitOfMeasureName(UnitOfMeasureRecordRef);
        CRMUomschedule.SetRange(Name, CRMSynchHelper.GetUnitGroupName(UnitOfMeasureName));
        if not CRMUomschedule.FindFirst() then
            exit(false);
        ValidateSchedule(CRMUomschedule.Name, CRMUomschedule.StateCode, CRMUomschedule.UoMScheduleId, UnitOfMeasureName);
        exit(ScheduleRecordRef.Get(CRMUomschedule.RecordId()));
    end;

    /// <summary>
    /// Points a Dataverse unit at the schedule of its item's or resource's unit group, and keeps the product's price list item in step.
    /// </summary>
    /// <param name="Context">The synchronization context, used to queue a missing unit group as a prerequisite.</param>
    /// <param name="UnitRecordRef">The item or resource unit of measure.</param>
    /// <param name="CRMUomRecordRef">The Dataverse unit.</param>
    /// <returns>True when a field of the unit changed.</returns>
    internal procedure UpdateUnit(var Context: Codeunit "DVI Sync Context"; var UnitRecordRef: RecordRef; var CRMUomRecordRef: RecordRef): Boolean
    var
        UnitGroup: Record "Unit Group";
        CRMUom: Record "CRM Uom";
        CRMUomschedule: Record "CRM Uomschedule";
        ScheduleFieldRef: FieldRef;
        CurrentScheduleId: Guid;
        Modified: Boolean;
    begin
        FindUnitGroupOfUnit(UnitRecordRef, UnitGroup);
        CRMUomschedule.SetRange(Name, UnitGroup.GetCode());
        if not CRMUomschedule.FindFirst() then
            RequireUnitGroup(Context, UnitGroup);
        ScheduleFieldRef := CRMUomRecordRef.Field(CRMUom.FieldNo(UoMScheduleId));
        CurrentScheduleId := ScheduleFieldRef.Value();
        if CurrentScheduleId <> CRMUomschedule.UoMScheduleId then begin
            ScheduleFieldRef.Value(CRMUomschedule.UoMScheduleId);
            Modified := true;
        end;
        if UpdatePriceListItemOfUnit(UnitRecordRef, CRMUomRecordRef) then
            Modified := true;
        exit(Modified);
    end;

    /// <summary>
    /// Keeps the price list item of the product coupled to a unit's item or resource in step with the unit.
    /// </summary>
    /// <param name="UnitRecordRef">The item or resource unit of measure.</param>
    /// <param name="CRMUomRecordRef">The Dataverse unit.</param>
    /// <returns>True when the price list item changed.</returns>
    internal procedure UpdatePriceListItemOfUnit(var UnitRecordRef: RecordRef; var CRMUomRecordRef: RecordRef): Boolean
    var
        CRMUom: Record "CRM Uom";
        CRMProduct: Record "CRM Product";
        CRMIntegrationRecord: Record "CRM Integration Record";
        CRMSynchHelper: Codeunit "CRM Synch. Helper";
        OwnerRecordRef: RecordRef;
        ProductId: Guid;
    begin
        if not FindOwnerOfUnit(UnitRecordRef, OwnerRecordRef) then
            exit(false);
        if not CRMIntegrationRecord.FindIDFromRecordRef(OwnerRecordRef, ProductId) then
            exit(false);
        if not CRMProduct.Get(ProductId) then
            exit(false);
        CRMUomRecordRef.SetTable(CRMUom);
        exit(CRMSynchHelper.UpdateCRMPriceListItemForUom(CRMProduct, CRMUom));
    end;

    /// <summary>
    /// After an item or resource was created from a Dataverse product, couples its unit group to the product's unit schedule and creates and couples its base unit, and queues both for synchronization.
    /// </summary>
    /// <param name="Context">The synchronization context.</param>
    /// <param name="CRMProductRecordRef">The Dataverse product.</param>
    /// <param name="LocalRecordRef">The new item or resource.</param>
    internal procedure CoupleUnitsOfNewProduct(var Context: Codeunit "DVI Sync Context"; var CRMProductRecordRef: RecordRef; var LocalRecordRef: RecordRef)
    var
        CRMProduct: Record "CRM Product";
        UnitGroup: Record "Unit Group";
        UnitGroupMapping: Record "Integration Table Mapping";
        UnitMapping: Record "Integration Table Mapping";
        CRMIntegrationRecord: Record "CRM Integration Record";
        CDSRelations: Codeunit "DVI CDS Relations";
        UnitSystemId: Guid;
        LocalSystemId: Guid;
    begin
        if not CDSRelations.FindMapping(Database::"Unit Group", Database::"CRM Uomschedule", UnitGroupMapping) then
            exit;
        if UnitGroupMapping."Synch. Only Coupled Records" then
            exit;
        if not CDSRelations.FindMapping(UnitTableOf(LocalRecordRef.Number()), Database::"CRM Uom", UnitMapping) then
            exit;
        if UnitMapping."Synch. Only Coupled Records" then
            exit;
        CRMProductRecordRef.SetTable(CRMProduct);
        LocalSystemId := LocalRecordRef.Field(LocalRecordRef.SystemIdNo()).Value();
        if UnitGroup.Get(UnitGroupSourceTypeOf(LocalRecordRef.Number()), LocalSystemId) then begin
            CRMIntegrationRecord.CoupleRecordIdToCRMID(UnitGroup.RecordId(), CRMProduct.DefaultUoMScheduleId);
            Context.AddFollowUp(UnitGroupMapping.Name, UnitGroup.SystemId, true);
        end;
        if CreateBaseUnit(LocalRecordRef, CRMProduct.DefaultUoMId, UnitSystemId) then
            Context.AddFollowUp(UnitMapping.Name, UnitSystemId, true);
    end;

    local procedure CreateBaseUnit(var LocalRecordRef: RecordRef; UomId: Guid; var UnitSystemId: Guid): Boolean
    var
        Item: Record Item;
        Resource: Record Resource;
        ItemUnitOfMeasure: Record "Item Unit of Measure";
        ResourceUnitOfMeasure: Record "Resource Unit of Measure";
        CRMIntegrationRecord: Record "CRM Integration Record";
    begin
        case LocalRecordRef.Number() of
            Database::Item:
                begin
                    LocalRecordRef.SetTable(Item);
                    if ItemUnitOfMeasure.Get(Item."No.", Item."Base Unit of Measure") then
                        exit(false);
                    ItemUnitOfMeasure.Init();
                    ItemUnitOfMeasure.Validate("Item No.", Item."No.");
                    ItemUnitOfMeasure.Validate(Code, Item."Base Unit of Measure");
                    ItemUnitOfMeasure."Qty. per Unit of Measure" := 1;
                    ItemUnitOfMeasure.Insert(true);
                    CRMIntegrationRecord.CoupleRecordIdToCRMID(ItemUnitOfMeasure.RecordId(), UomId);
                    UnitSystemId := ItemUnitOfMeasure.SystemId;
                end;
            Database::Resource:
                begin
                    LocalRecordRef.SetTable(Resource);
                    if ResourceUnitOfMeasure.Get(Resource."No.", Resource."Base Unit of Measure") then
                        exit(false);
                    ResourceUnitOfMeasure.Init();
                    ResourceUnitOfMeasure.Validate("Resource No.", Resource."No.");
                    ResourceUnitOfMeasure.Validate(Code, Resource."Base Unit of Measure");
                    ResourceUnitOfMeasure."Qty. per Unit of Measure" := 1;
                    ResourceUnitOfMeasure.Insert(true);
                    CRMIntegrationRecord.CoupleRecordIdToCRMID(ResourceUnitOfMeasure.RecordId(), UomId);
                    UnitSystemId := ResourceUnitOfMeasure.SystemId;
                end;
            else
                exit(false);
        end;
        exit(true);
    end;

    local procedure ValidateSchedule(ScheduleName: Text; StateCode: Integer; ScheduleId: Guid; UnitOfMeasureName: Text[100]): Boolean
    var
        CRMUom: Record "CRM Uom";
        CRMUomschedule: Record "CRM Uomschedule";
    begin
        if StateCode = CRMUomschedule.StateCode::Inactive then
            Error(UnitGroupInactiveErr, CRMUomschedule.TableCaption(), ScheduleName);
        CRMUom.SetRange(UoMScheduleId, ScheduleId);
        if CRMUom.Count() > 1 then
            Error(UnitGroupHasSeveralUnitsErr, CRMUomschedule.TableCaption(), ScheduleName, CRMUom.TableCaption());
        if not CRMUom.FindFirst() then
            exit(false);
        if CRMUom.Name = UnitOfMeasureName then
            exit(false);
        CRMUom.Name := UnitOfMeasureName;
        CRMUom.Modify();
        exit(true);
    end;

    local procedure RequireUnitGroup(var Context: Codeunit "DVI Sync Context"; UnitGroup: Record "Unit Group")
    var
        UnitGroupMapping: Record "Integration Table Mapping";
        CDSRelations: Codeunit "DVI CDS Relations";
    begin
        if CDSRelations.FindMapping(Database::"Unit Group", Database::"CRM Uomschedule", UnitGroupMapping) then
            Context.AddPrerequisite(UnitGroupMapping.Name, UnitGroup.SystemId, true);
        Error(UnitGroupNotSynchronizedErr, UnitGroup.GetCode());
    end;

    local procedure FindUnitGroupOfUnit(var UnitRecordRef: RecordRef; var UnitGroup: Record "Unit Group")
    var
        OwnerRecordRef: RecordRef;
        OwnerSystemId: Guid;
    begin
        FindOwnerOfUnit(UnitRecordRef, OwnerRecordRef);
        OwnerSystemId := OwnerRecordRef.Field(OwnerRecordRef.SystemIdNo()).Value();
        if not UnitGroup.Get(UnitGroupSourceTypeOf(OwnerRecordRef.Number()), OwnerSystemId) then
            Error(UnitGroupOfItemNotFoundErr, OwnerRecordRef.Caption(), Format(OwnerRecordRef.Field(1).Value()));
    end;

    local procedure FindOwnerOfUnit(var UnitRecordRef: RecordRef; var OwnerRecordRef: RecordRef): Boolean
    var
        Item: Record Item;
        Resource: Record Resource;
        ItemUnitOfMeasure: Record "Item Unit of Measure";
        ResourceUnitOfMeasure: Record "Resource Unit of Measure";
    begin
        case UnitRecordRef.Number() of
            Database::"Item Unit of Measure":
                begin
                    Item.Get(Format(UnitRecordRef.Field(ItemUnitOfMeasure.FieldNo("Item No.")).Value()));
                    OwnerRecordRef.GetTable(Item);
                end;
            Database::"Resource Unit of Measure":
                begin
                    Resource.Get(Format(UnitRecordRef.Field(ResourceUnitOfMeasure.FieldNo("Resource No.")).Value()));
                    OwnerRecordRef.GetTable(Resource);
                end;
            else
                exit(false);
        end;
        exit(true);
    end;

    local procedure UnitGroupSourceTypeOf(TableId: Integer): Enum "Unit Group Source Type"
    begin
        if TableId = Database::Resource then
            exit(Enum::"Unit Group Source Type"::Resource);
        exit(Enum::"Unit Group Source Type"::Item);
    end;

    local procedure UnitTableOf(TableId: Integer): Integer
    begin
        if TableId = Database::Resource then
            exit(Database::"Resource Unit of Measure");
        exit(Database::"Item Unit of Measure");
    end;
}
