namespace DataverseIntegration.CRM;

using DataverseIntegration.CDS;
using DataverseIntegration.Core;
using Microsoft.Integration.D365Sales;
using Microsoft.Integration.Dataverse;
using Microsoft.Integration.SyncEngine;
using Microsoft.Inventory.Item;
using Microsoft.Pricing.Asset;
using Microsoft.Pricing.PriceList;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Sales.Pricing;

codeunit 80404 "DVI Price Line Handler" implements "DVI IRecordSync", "DVI IRecordCoupling", "DVI IHandlerScope"
{
    Access = Public;

    procedure Serves(var Context: Codeunit "DVI Sync Context"): Boolean
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
    begin
        Context.GetMapping(IntegrationTableMapping);
        exit((IntegrationTableMapping."Table ID" in [Database::"Sales Price", Database::"Price List Line"]) and (IntegrationTableMapping."Integration Table ID" = Database::"CRM Productpricelevel"));
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
        CRMProductpricelevel: Record "CRM Productpricelevel";
        CRMUom: Record "CRM Uom";
        CRMPrices: Codeunit "DVI CRM Prices";
        AssetType: Enum "Price Asset Type";
        AssetNo: Code[20];
        UnitOfMeasureCode: Code[10];
    begin
        AdditionalFieldsModified := false;
        if not Context.IsToIntegrationTable() then
            exit;
        GetAsset(SourceRecordRef, AssetType, AssetNo, UnitOfMeasureCode);
        CRMPrices.FindUnit(AssetType, AssetNo, UnitOfMeasureCode, CRMUom);
        DestinationRecordRef.SetTable(CRMProductpricelevel);
        if CRMProductpricelevel.UoMScheduleId <> CRMUom.UoMScheduleId then begin
            CRMProductpricelevel.UoMScheduleId := CRMUom.UoMScheduleId;
            AdditionalFieldsModified := true;
        end;
        if CRMProductpricelevel.UoMId <> CRMUom.UoMId then begin
            CRMProductpricelevel.UoMId := CRMUom.UoMId;
            AdditionalFieldsModified := true;
        end;
        DestinationRecordRef.GetTable(CRMProductpricelevel);
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
        CRMProductpricelevel: Record "CRM Productpricelevel";
        CRMUom: Record "CRM Uom";
        CRMPrices: Codeunit "DVI CRM Prices";
        PriceLevelId: Guid;
        ProductId: Guid;
        AssetType: Enum "Price Asset Type";
        AssetNo: Code[20];
        UnitOfMeasureCode: Code[10];
    begin
        DestinationIsDeleted := false;
        if not Context.IsToIntegrationTable() then
            exit(false);
        if not FindPriceLevelId(SourceRecordRef, PriceLevelId) then
            exit(false);
        GetAsset(SourceRecordRef, AssetType, AssetNo, UnitOfMeasureCode);
        CRMPrices.FindUnit(AssetType, AssetNo, UnitOfMeasureCode, CRMUom);
        if not FindProductId(AssetType, AssetNo, ProductId) then
            exit(false);
        CRMProductpricelevel.SetRange(PriceLevelId, PriceLevelId);
        CRMProductpricelevel.SetRange(UoMId, CRMUom.UoMId);
        CRMProductpricelevel.SetRange(ProductId, ProductId);
        if not CRMProductpricelevel.FindFirst() then
            exit(false);
        DestinationRecordRef.GetTable(CRMProductpricelevel);
        exit(true);
    end;

    procedure AfterCouple(var Context: Codeunit "DVI Sync Context"; var LocalRecordRef: RecordRef; var IntegrationRecordRef: RecordRef)
    begin
    end;

    procedure BeforeUncouple(var Context: Codeunit "DVI Sync Context"; var LocalRecordRef: RecordRef; var IntegrationRecordRef: RecordRef)
    var
        CDSCompany: Codeunit "DVI CDS Company";
    begin
        CDSCompany.ResetCompanyId(IntegrationRecordRef);
    end;

    procedure AfterUncouple(var Context: Codeunit "DVI Sync Context"; var LocalRecordRef: RecordRef; var IntegrationRecordRef: RecordRef)
    begin
    end;

    procedure SetMatchingFilter(var Context: Codeunit "DVI Sync Context"; var IntegrationRecordRef: RecordRef; var MatchingIntegrationFieldRef: FieldRef; var LocalRecordRef: RecordRef; var MatchingLocalFieldRef: FieldRef): Boolean
    begin
        exit(false);
    end;

    procedure CreateNewOnNoMatch(var Context: Codeunit "DVI Sync Context"): Boolean
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
    begin
        Context.GetMapping(IntegrationTableMapping);
        exit(IntegrationTableMapping."Create New in Case of No Match");
    end;

    local procedure GetAsset(var SourceRecordRef: RecordRef; var AssetType: Enum "Price Asset Type"; var AssetNo: Code[20]; var UnitOfMeasureCode: Code[10])
    var
        SalesPrice: Record "Sales Price";
        PriceListLine: Record "Price List Line";
    begin
        if SourceRecordRef.Number() = Database::"Sales Price" then begin
            SourceRecordRef.SetTable(SalesPrice);
            AssetType := AssetType::Item;
            AssetNo := SalesPrice."Item No.";
            UnitOfMeasureCode := SalesPrice."Unit of Measure Code";
            exit;
        end;
        SourceRecordRef.SetTable(PriceListLine);
        AssetType := PriceListLine."Asset Type";
        AssetNo := PriceListLine."Asset No.";
        UnitOfMeasureCode := PriceListLine."Unit of Measure Code";
    end;

    local procedure FindPriceLevelId(var SourceRecordRef: RecordRef; var PriceLevelId: Guid): Boolean
    var
        SalesPrice: Record "Sales Price";
        PriceListLine: Record "Price List Line";
        CustomerPriceGroup: Record "Customer Price Group";
        PriceListHeader: Record "Price List Header";
        CRMIntegrationRecord: Record "CRM Integration Record";
    begin
        if SourceRecordRef.Number() = Database::"Sales Price" then begin
            SourceRecordRef.SetTable(SalesPrice);
            if not CustomerPriceGroup.Get(SalesPrice."Sales Code") then
                exit(false);
            exit(CRMIntegrationRecord.FindIDFromRecordID(CustomerPriceGroup.RecordId(), PriceLevelId));
        end;
        SourceRecordRef.SetTable(PriceListLine);
        if not PriceListHeader.Get(PriceListLine."Price List Code") then
            exit(false);
        exit(CRMIntegrationRecord.FindIDFromRecordID(PriceListHeader.RecordId(), PriceLevelId));
    end;

    local procedure FindProductId(AssetType: Enum "Price Asset Type"; AssetNo: Code[20]; var ProductId: Guid): Boolean
    var
        Item: Record Item;
        Resource: Record Resource;
        CRMIntegrationRecord: Record "CRM Integration Record";
    begin
        case AssetType of
            AssetType::Item:
                if Item.Get(AssetNo) then
                    exit(CRMIntegrationRecord.FindIDFromRecordID(Item.RecordId(), ProductId));
            AssetType::Resource:
                if Resource.Get(AssetNo) then
                    exit(CRMIntegrationRecord.FindIDFromRecordID(Resource.RecordId(), ProductId));
        end;
        exit(false);
    end;
}
