namespace DataverseIntegration.CRM;

using DataverseIntegration.Core;
using Microsoft.Foundation.UOM;
using Microsoft.Integration.D365Sales;
using Microsoft.Integration.Dataverse;
using Microsoft.Integration.SyncEngine;
using Microsoft.Inventory.Item;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Sales.Document;

codeunit 80408 "DVI Sales Order Line Handler" implements "DVI IRecordSync", "DVI IHandlerScope"
{
    Access = Public;

    var
        UnitOfMeasureNotCoupledErr: Label 'The unit of measure %1 is not coupled to a Dataverse unit group.', Comment = '%1 = unit of measure code';
        UnitNotCoupledErr: Label 'The %1 %2 is not coupled to a Dataverse unit.', Comment = '%1 = table caption, %2 = unit of measure code';
        DataverseUnitNotCoupledErr: Label 'The Dataverse unit %1 is not coupled to a unit of measure.', Comment = '%1 = unit name';

    procedure Serves(var Context: Codeunit "DVI Sync Context"): Boolean
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
    begin
        Context.GetMapping(IntegrationTableMapping);
        exit((IntegrationTableMapping."Table ID" = Database::"Sales Line") and (IntegrationTableMapping."Integration Table ID" = Database::"CRM Salesorderdetail"));
    end;

    procedure DefaultModule(var Context: Codeunit "DVI Sync Context"): Enum "DVI Integration Module"
    begin
        exit(Enum::"DVI Integration Module"::DVISales);
    end;

    procedure BeforeTransferFields(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    var
        CRMSalesOrders: Codeunit "DVI CRM Sales Orders";
    begin
        if not CRMSalesOrders.IsBidirectional() then
            exit;
        if Context.IsToIntegrationTable() then
            CRMSalesOrders.SetOrderOfLine(SourceRecordRef, DestinationRecordRef)
        else
            CRMSalesOrders.SetOrderAndTypeOfLine(SourceRecordRef, DestinationRecordRef);
    end;

    procedure AfterTransferFields(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef; var AdditionalFieldsModified: Boolean)
    begin
        if Context.IsToIntegrationTable() then
            AdditionalFieldsModified := SetUnitInDataverse(SourceRecordRef, DestinationRecordRef)
        else
            AdditionalFieldsModified := SetUnitAndPriceInBusinessCentral(SourceRecordRef, DestinationRecordRef);
    end;

    procedure BeforeInsert(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    var
        SalesLine: Record "Sales Line";
        CRMSalesorderdetail: Record "CRM Salesorderdetail";
        CRMSalesOrders: Codeunit "DVI CRM Sales Orders";
    begin
        if not (Context.IsToIntegrationTable() and CRMSalesOrders.IsBidirectional()) then
            exit;
        SourceRecordRef.SetTable(SalesLine);
        DestinationRecordRef.SetTable(CRMSalesorderdetail);
        if IsNullGuid(CRMSalesorderdetail.ProductId) then begin
            CRMSalesorderdetail.IsProductOverridden := true;
            CRMSalesorderdetail.ProductDescription := SalesLine.Description;
        end;
        CRMSalesorderdetail.Tax := SalesLine."Amount Including VAT" - SalesLine.Amount;
        DestinationRecordRef.GetTable(CRMSalesorderdetail);
    end;

    procedure AfterInsert(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    var
        SalesLine: Record "Sales Line";
        CRMSalesOrders: Codeunit "DVI CRM Sales Orders";
    begin
        if Context.IsToIntegrationTable() or not CRMSalesOrders.IsBidirectional() then
            exit;
        DestinationRecordRef.SetTable(SalesLine);
        if (SalesLine.Type = SalesLine.Type::Item) and (SalesLine.Reserve = SalesLine.Reserve::Always) then
            SalesLine.AutoReserve();
    end;

    procedure BeforeModify(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    var
        SalesLine: Record "Sales Line";
        CRMSalesorderdetail: Record "CRM Salesorderdetail";
        CRMSalesOrders: Codeunit "DVI CRM Sales Orders";
    begin
        if not (Context.IsToIntegrationTable() and CRMSalesOrders.IsBidirectional()) then
            exit;
        SourceRecordRef.SetTable(SalesLine);
        DestinationRecordRef.SetTable(CRMSalesorderdetail);
        CRMSalesorderdetail.Tax := SalesLine."Amount Including VAT" - SalesLine.Amount;
        DestinationRecordRef.GetTable(CRMSalesorderdetail);
    end;

    procedure AfterModify(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    begin
    end;

    procedure Unchanged(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    begin
    end;

    local procedure SetUnitInDataverse(var SalesLineRecordRef: RecordRef; var CRMSalesorderdetailRecordRef: RecordRef): Boolean
    var
        SalesLine: Record "Sales Line";
        CRMSalesorderdetail: Record "CRM Salesorderdetail";
        UnitOfMeasure: Record "Unit of Measure";
        ItemUnitOfMeasure: Record "Item Unit of Measure";
        ResourceUnitOfMeasure: Record "Resource Unit of Measure";
        CRMIntegrationRecord: Record "CRM Integration Record";
        CRMUom: Record "CRM Uom";
        CRMIntegrationManagement: Codeunit "CRM Integration Management";
        CRMUomscheduleId: Guid;
        CRMUomId: Guid;
    begin
        SalesLineRecordRef.SetTable(SalesLine);
        CRMSalesorderdetailRecordRef.SetTable(CRMSalesorderdetail);
        if IsNullGuid(CRMSalesorderdetail.ProductId) then
            exit(false);
        if not CRMIntegrationManagement.IsUnitGroupMappingEnabled() then begin
            UnitOfMeasure.Get(SalesLine."Unit of Measure Code");
            if not CRMIntegrationRecord.FindIDFromRecordID(UnitOfMeasure.RecordId(), CRMUomscheduleId) then
                Error(UnitOfMeasureNotCoupledErr, UnitOfMeasure.Code);
            CRMUom.SetRange(UoMScheduleId, CRMUomscheduleId);
            CRMUom.SetRange(Name, UnitOfMeasure.Code);
            if not CRMUom.FindFirst() then
                exit(false);
            CRMUomId := CRMUom.UoMId;
        end else
            case SalesLine.Type of
                SalesLine.Type::Item:
                    begin
                        ItemUnitOfMeasure.Get(SalesLine."No.", SalesLine."Unit of Measure Code");
                        if not CRMIntegrationRecord.FindIDFromRecordID(ItemUnitOfMeasure.RecordId(), CRMUomId) then
                            Error(UnitNotCoupledErr, ItemUnitOfMeasure.TableCaption(), ItemUnitOfMeasure.Code);
                    end;
                SalesLine.Type::Resource:
                    begin
                        ResourceUnitOfMeasure.Get(SalesLine."No.", SalesLine."Unit of Measure Code");
                        if not CRMIntegrationRecord.FindIDFromRecordID(ResourceUnitOfMeasure.RecordId(), CRMUomId) then
                            Error(UnitNotCoupledErr, ResourceUnitOfMeasure.TableCaption(), ResourceUnitOfMeasure.Code);
                    end;
                else
                    exit(false);
            end;
        if CRMSalesorderdetail.UoMId = CRMUomId then
            exit(false);
        CRMSalesorderdetail.UoMId := CRMUomId;
        CRMSalesorderdetailRecordRef.GetTable(CRMSalesorderdetail);
        exit(true);
    end;

    local procedure SetUnitAndPriceInBusinessCentral(var CRMSalesorderdetailRecordRef: RecordRef; var SalesLineRecordRef: RecordRef): Boolean
    var
        CRMSalesorderdetail: Record "CRM Salesorderdetail";
        CRMProduct: Record "CRM Product";
        SalesLine: Record "Sales Line";
        CRMIntegrationRecord: Record "CRM Integration Record";
        ItemUnitOfMeasure: Record "Item Unit of Measure";
        ResourceUnitOfMeasure: Record "Resource Unit of Measure";
        CRMIntegrationManagement: Codeunit "CRM Integration Management";
        UnitRecordId: RecordId;
    begin
        if not CRMIntegrationManagement.IsUnitGroupMappingEnabled() then
            exit(false);
        CRMSalesorderdetailRecordRef.SetTable(CRMSalesorderdetail);
        SalesLineRecordRef.SetTable(SalesLine);
        if IsNullGuid(CRMSalesorderdetail.ProductId) then
            exit(false);
        CRMProduct.Get(CRMSalesorderdetail.ProductId);
        case CRMProduct.ProductTypeCode of
            CRMProduct.ProductTypeCode::SalesInventory:
                begin
                    if not CRMIntegrationRecord.FindRecordIDFromID(CRMSalesorderdetail.UoMId, Database::"Item Unit of Measure", UnitRecordId) then
                        Error(DataverseUnitNotCoupledErr, CRMSalesorderdetail.UoMIdName);
                    ItemUnitOfMeasure.Get(UnitRecordId);
                    SalesLine.Validate("Unit of Measure Code", ItemUnitOfMeasure.Code);
                end;
            CRMProduct.ProductTypeCode::Services:
                begin
                    if not CRMIntegrationRecord.FindRecordIDFromID(CRMSalesorderdetail.UoMId, Database::"Resource Unit of Measure", UnitRecordId) then
                        Error(DataverseUnitNotCoupledErr, CRMSalesorderdetail.UoMIdName);
                    ResourceUnitOfMeasure.Get(UnitRecordId);
                    SalesLine.Validate("Unit of Measure Code", ResourceUnitOfMeasure.Code);
                end;
            else
                exit(false);
        end;
        if SalesLine."Unit Price" <> CRMSalesorderdetail.PricePerUnit then
            SalesLine.Validate("Unit Price", CRMSalesorderdetail.PricePerUnit);
        SalesLineRecordRef.GetTable(SalesLine);
        exit(true);
    end;
}
