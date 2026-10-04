namespace DataverseIntegration.CRM;

using DataverseIntegration.CDS;
using DataverseIntegration.Core;
using Microsoft.Foundation.UOM;
using Microsoft.Integration.D365Sales;
using Microsoft.Integration.Dataverse;
using Microsoft.Integration.SyncEngine;
using Microsoft.Inventory.Item;
using Microsoft.Pricing.Asset;
using Microsoft.Pricing.PriceList;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Sales.Pricing;

codeunit 80410 "DVI CRM Prices"
{
    Access = Internal;

    var
        NotCoupledErr: Label 'The %1 %2 is not coupled to Dataverse yet. It has been queued for synchronization; this record is synchronized again in the next run.', Comment = '%1 = table caption, %2 = number';
        UnitGroupNotFoundErr: Label 'The Dataverse unit group %1 was not found.', Comment = '%1 = unit group code';
        UnitNotFoundErr: Label 'The Dataverse unit %1 was not found in the unit group %2.', Comment = '%1 = unit of measure code, %2 = unit group ID';

    /// <summary>
    /// Checks that the prices of a customer price group can be sent to Dataverse and returns their transaction currency: one currency for all prices, and every item coupled.
    /// </summary>
    /// <param name="Context">The synchronization context, used to queue uncoupled items as prerequisites.</param>
    /// <param name="CustomerPriceGroup">The customer price group.</param>
    /// <param name="CRMTransactioncurrency">Receives the transaction currency of the prices, or the local currency when there are none.</param>
    internal procedure CheckCustomerPriceGroup(var Context: Codeunit "DVI Sync Context"; CustomerPriceGroup: Record "Customer Price Group"; var CRMTransactioncurrency: Record "CRM Transactioncurrency")
    var
        SalesPrice: Record "Sales Price";
        CRMUom: Record "CRM Uom";
        CRMSynchHelper: Codeunit "CRM Synch. Helper";
        CurrencyCode: Code[10];
    begin
        SalesPrice.SetRange("Sales Type", SalesPrice."Sales Type"::"Customer Price Group");
        SalesPrice.SetRange("Sales Code", CustomerPriceGroup.Code);
        if not SalesPrice.FindSet() then begin
            CRMSynchHelper.FindNAVLocalCurrencyInCRM(CRMTransactioncurrency);
            exit;
        end;
        CurrencyCode := SalesPrice."Currency Code";
        CRMTransactioncurrency.Get(CRMSynchHelper.GetCRMTransactioncurrency(CurrencyCode));
        repeat
            SalesPrice.TestField("Currency Code", CurrencyCode);
            RequireCoupledProduct(Context, Enum::"Price Asset Type"::Item, SalesPrice."Item No.");
            FindUnit(Enum::"Price Asset Type"::Item, SalesPrice."Item No.", SalesPrice."Unit of Measure Code", CRMUom);
        until SalesPrice.Next() = 0;
    end;

    /// <summary>
    /// Checks that the lines of a sales price list can be sent to Dataverse and returns their transaction currency.
    /// </summary>
    /// <param name="Context">The synchronization context, used to queue uncoupled items and resources as prerequisites.</param>
    /// <param name="PriceListHeader">The price list.</param>
    /// <param name="CRMTransactioncurrency">Receives the transaction currency of the lines, or the local currency when there are none.</param>
    internal procedure CheckPriceList(var Context: Codeunit "DVI Sync Context"; PriceListHeader: Record "Price List Header"; var CRMTransactioncurrency: Record "CRM Transactioncurrency")
    var
        PriceListLine: Record "Price List Line";
        CRMUom: Record "CRM Uom";
        CRMSynchHelper: Codeunit "CRM Synch. Helper";
        CurrencyCode: Code[10];
    begin
        PriceListLine.SetRange("Price List Code", PriceListHeader.Code);
        if not PriceListLine.FindSet() then begin
            CRMSynchHelper.FindNAVLocalCurrencyInCRM(CRMTransactioncurrency);
            exit;
        end;
        CurrencyCode := PriceListLine."Currency Code";
        CRMTransactioncurrency.Get(CRMSynchHelper.GetCRMTransactioncurrency(CurrencyCode));
        repeat
            PriceListLine.TestField("Currency Code", CurrencyCode);
            RequireCoupledProduct(Context, PriceListLine."Asset Type", PriceListLine."Asset No.");
            FindUnit(PriceListLine."Asset Type", PriceListLine."Asset No.", PriceListLine."Unit of Measure Code", CRMUom);
        until PriceListLine.Next() = 0;
    end;

    /// <summary>
    /// Finds the Dataverse unit of an item or resource price.
    /// </summary>
    /// <param name="AssetType">Item or resource.</param>
    /// <param name="AssetNo">The item or resource number.</param>
    /// <param name="UnitOfMeasureCode">The price's unit of measure; blank means the base unit.</param>
    /// <param name="CRMUom">Receives the Dataverse unit.</param>
    internal procedure FindUnit(AssetType: Enum "Price Asset Type"; AssetNo: Code[20]; UnitOfMeasureCode: Code[10]; var CRMUom: Record "CRM Uom")
    var
        Item: Record Item;
        Resource: Record Resource;
        UnitGroup: Record "Unit Group";
        CRMUomschedule: Record "CRM Uomschedule";
        CRMIntegrationManagement: Codeunit "CRM Integration Management";
        CRMSynchHelper: Codeunit "CRM Synch. Helper";
    begin
        case AssetType of
            AssetType::Item:
                begin
                    Item.Get(AssetNo);
                    if UnitOfMeasureCode = '' then
                        UnitOfMeasureCode := Item."Base Unit of Measure";
                end;
            AssetType::Resource:
                begin
                    Resource.Get(AssetNo);
                    if UnitOfMeasureCode = '' then
                        UnitOfMeasureCode := Resource."Base Unit of Measure";
                end;
            else
                if UnitOfMeasureCode = '' then
                    exit;
        end;
        if not CRMIntegrationManagement.IsUnitGroupMappingEnabled() then begin
            CRMSynchHelper.GetValidCRMUnitOfMeasureRecords(CRMUom, CRMUomschedule, UnitOfMeasureCode);
            exit;
        end;
        if AssetType = AssetType::Item then
            UnitGroup.Get(UnitGroup."Source Type"::Item, Item.SystemId)
        else
            UnitGroup.Get(UnitGroup."Source Type"::Resource, Resource.SystemId);
        CRMUomschedule.SetRange(Name, UnitGroup.GetCode());
        if not CRMUomschedule.FindFirst() then
            Error(UnitGroupNotFoundErr, UnitGroup.GetCode());
        CRMUom.SetRange(Name, UnitOfMeasureCode);
        CRMUom.SetRange(UoMScheduleId, CRMUomschedule.UoMScheduleId);
        if not CRMUom.FindFirst() then
            Error(UnitNotFoundErr, UnitOfMeasureCode, CRMUomschedule.UoMScheduleId);
    end;

    /// <summary>
    /// Returns the Dataverse product of an item or resource. When it is not coupled but its mapping would send it, it is queued as a prerequisite and the current record fails, so it succeeds in the next run.
    /// </summary>
    /// <param name="Context">The synchronization context.</param>
    /// <param name="AssetType">Item or resource.</param>
    /// <param name="AssetNo">The item or resource number.</param>
    /// <returns>The Dataverse product ID, or a null GUID when the asset is not synchronized at all.</returns>
    internal procedure RequireCoupledProduct(var Context: Codeunit "DVI Sync Context"; AssetType: Enum "Price Asset Type"; AssetNo: Code[20]) ProductId: Guid
    var
        Item: Record Item;
        Resource: Record Resource;
        RecordRef: RecordRef;
    begin
        case AssetType of
            AssetType::Item:
                begin
                    Item.Get(AssetNo);
                    RecordRef.GetTable(Item);
                end;
            AssetType::Resource:
                begin
                    Resource.Get(AssetNo);
                    RecordRef.GetTable(Resource);
                end;
            else
                exit;
        end;
        RecordRef.SetRecFilter();
        exit(RequireCoupledRecord(Context, RecordRef, Database::"CRM Product"));
    end;

    /// <summary>
    /// Queues the prices of a customer price group or price list for synchronization after the price level itself, replacing the standard nested synchronization.
    /// </summary>
    /// <param name="Context">The synchronization context.</param>
    /// <param name="PriceLevelSourceRecordRef">The customer price group or price list header.</param>
    internal procedure QueuePrices(var Context: Codeunit "DVI Sync Context"; var PriceLevelSourceRecordRef: RecordRef)
    var
        CustomerPriceGroup: Record "Customer Price Group";
        PriceListHeader: Record "Price List Header";
        SalesPrice: Record "Sales Price";
        PriceListLine: Record "Price List Line";
        IntegrationTableMapping: Record "Integration Table Mapping";
        CDSRelations: Codeunit "DVI CDS Relations";
    begin
        case PriceLevelSourceRecordRef.Number() of
            Database::"Customer Price Group":
                begin
                    PriceLevelSourceRecordRef.SetTable(CustomerPriceGroup);
                    if not CDSRelations.FindMapping(Database::"Sales Price", Database::"CRM Productpricelevel", IntegrationTableMapping) then
                        exit;
                    SalesPrice.SetRange("Sales Type", SalesPrice."Sales Type"::"Customer Price Group");
                    SalesPrice.SetRange("Sales Code", CustomerPriceGroup.Code);
                    if SalesPrice.FindSet() then
                        repeat
                            Context.AddFollowUp(IntegrationTableMapping.Name, SalesPrice.SystemId, true);
                        until SalesPrice.Next() = 0;
                end;
            Database::"Price List Header":
                begin
                    PriceLevelSourceRecordRef.SetTable(PriceListHeader);
                    if not CDSRelations.FindMapping(Database::"Price List Line", Database::"CRM Productpricelevel", IntegrationTableMapping) then
                        exit;
                    PriceListLine.SetRange("Price List Code", PriceListHeader.Code);
                    if PriceListLine.FindSet() then
                        repeat
                            Context.AddFollowUp(IntegrationTableMapping.Name, PriceListLine.SystemId, true);
                        until PriceListLine.Next() = 0;
                end;
        end;
    end;

    /// <summary>
    /// Returns the Dataverse ID of a record the current record needs. When the record is not coupled but its mapping would synchronize it, it is queued as a prerequisite and an error stops the current record.
    /// </summary>
    /// <param name="Context">The synchronization context, used to queue the prerequisite.</param>
    /// <param name="LocalRecordRef">The needed record, filtered to it.</param>
    /// <param name="IntegrationTableId">The Dataverse table it is coupled to.</param>
    /// <returns>The coupled Dataverse ID, or an empty GUID when the record is outside its mapping's filter or has no mapping.</returns>
    internal procedure RequireCoupledRecord(var Context: Codeunit "DVI Sync Context"; var LocalRecordRef: RecordRef; IntegrationTableId: Integer) IntegrationId: Guid
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        CRMIntegrationRecord: Record "CRM Integration Record";
        CDSRelations: Codeunit "DVI CDS Relations";
        FilterRecordRef: RecordRef;
    begin
        LocalRecordRef.FindFirst();
        if CRMIntegrationRecord.FindIDFromRecordID(LocalRecordRef.RecordId(), IntegrationId) then
            exit;
        if not CDSRelations.FindMapping(LocalRecordRef.Number(), IntegrationTableId, IntegrationTableMapping) then
            exit;
        FilterRecordRef.Open(LocalRecordRef.Number());
        FilterRecordRef.SetView(IntegrationTableMapping.GetTableFilter());
        FilterRecordRef.Field(FilterRecordRef.SystemIdNo()).SetRange(LocalRecordRef.Field(LocalRecordRef.SystemIdNo()).Value());
        if FilterRecordRef.IsEmpty() then
            exit;
        Context.AddPrerequisite(IntegrationTableMapping.Name, LocalRecordRef.Field(LocalRecordRef.SystemIdNo()).Value(), true);
        Error(NotCoupledErr, LocalRecordRef.Caption(), Format(LocalRecordRef.Field(1).Value()));
    end;
}
