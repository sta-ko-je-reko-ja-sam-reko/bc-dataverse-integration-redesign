namespace DataverseIntegration.CRM;

using DataverseIntegration.CDS;
using DataverseIntegration.Core;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Integration.D365Sales;
using Microsoft.Integration.Dataverse;
using Microsoft.Integration.SyncEngine;
using Microsoft.Inventory.Item;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Sales.Setup;
using System.IO;

codeunit 80400 "DVI Product Handler" implements "DVI IRecordSync", "DVI IRecordCoupling", "DVI IRecordFilter", "DVI IHandlerScope"
{
    Access = Public;

    procedure Serves(var Context: Codeunit "DVI Sync Context"): Boolean
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
    begin
        Context.GetMapping(IntegrationTableMapping);
        exit((IntegrationTableMapping."Table ID" in [Database::Item, Database::Resource]) and (IntegrationTableMapping."Integration Table ID" = Database::"CRM Product"));
    end;

    procedure DefaultModule(var Context: Codeunit "DVI Sync Context"): Enum "DVI Integration Module"
    begin
        exit(Enum::"DVI Integration Module"::DVISales);
    end;

    procedure IgnoreRecord(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef): Boolean
    var
        SalesReceivablesSetup: Record "Sales & Receivables Setup";
    begin
        if not (SourceRecordRef.Number() in [Database::Item, Database::Resource]) then
            exit(false);
        SalesReceivablesSetup.SetLoadFields("Write-in Product No.");
        if not SalesReceivablesSetup.Get() then
            exit(false);
        exit(SalesReceivablesSetup."Write-in Product No." = Format(SourceRecordRef.Field(1).Value()));
    end;

    procedure BeforeTransferFields(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    begin
    end;

    procedure AfterTransferFields(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef; var AdditionalFieldsModified: Boolean)
    begin
        if Context.IsToIntegrationTable() then
            AdditionalFieldsModified := UpdateProduct(SourceRecordRef, DestinationRecordRef, Context.IsDestinationInserted())
        else
            AdditionalFieldsModified := UpdateBlocked(SourceRecordRef, DestinationRecordRef);
    end;

    procedure BeforeInsert(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    var
        CRMProduct: Record "CRM Product";
        CDSCompany: Codeunit "DVI CDS Company";
        CRMSynchHelper: Codeunit "CRM Synch. Helper";
    begin
        if not Context.IsToIntegrationTable() then begin
            FillItemKeyFromTemplate(Context, SourceRecordRef, DestinationRecordRef);
            exit;
        end;
        DestinationRecordRef.SetTable(CRMProduct);
        CRMSynchHelper.SetCRMDecimalsSupportedValue(CRMProduct);
        CRMSynchHelper.SetCRMDefaultPriceListOnProduct(CRMProduct);
        DestinationRecordRef.GetTable(CRMProduct);
        CDSCompany.SetCompanyId(DestinationRecordRef);
    end;

    procedure AfterInsert(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    var
        CRMProduct: Record "CRM Product";
        CRMIntegrationManagement: Codeunit "CRM Integration Management";
        CRMSynchHelper: Codeunit "CRM Synch. Helper";
        CRMUnits: Codeunit "DVI CRM Units";
    begin
        if not Context.IsToIntegrationTable() then begin
            CRMUnits.CoupleUnitsOfNewProduct(Context, SourceRecordRef, DestinationRecordRef);
            exit;
        end;
        DestinationRecordRef.SetTable(CRMProduct);
        if CRMIntegrationManagement.IsUnitGroupMappingEnabled() then
            CRMSynchHelper.UpdateCRMPriceListItems(CRMProduct)
        else
            CRMSynchHelper.UpdateCRMPriceListItem(CRMProduct);
        CRMSynchHelper.SetCRMProductStateToActive(CRMProduct);
        CRMProduct.Modify();
        DestinationRecordRef.GetTable(CRMProduct);
    end;

    procedure BeforeModify(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    var
        CDSCompany: Codeunit "DVI CDS Company";
    begin
        if Context.IsToIntegrationTable() then
            CDSCompany.SetCompanyId(DestinationRecordRef);
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

    local procedure UpdateProduct(var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef; DestinationIsInserted: Boolean) Modified: Boolean
    var
        Item: Record Item;
        Resource: Record Resource;
        CRMProduct: Record "CRM Product";
        GeneralLedgerSetup: Record "General Ledger Setup";
        CRMIntegrationManagement: Codeunit "CRM Integration Management";
        CRMSynchHelper: Codeunit "CRM Synch. Helper";
        CurrencyFieldRef: FieldRef;
        UnitOfMeasureFieldRef: FieldRef;
        ProductTypeCode: Integer;
        Blocked: Boolean;
    begin
        if SourceRecordRef.Number() = Database::Item then begin
            Blocked := SourceRecordRef.Field(Item.FieldNo(Blocked)).Value();
            UnitOfMeasureFieldRef := SourceRecordRef.Field(Item.FieldNo("Base Unit of Measure"));
            ProductTypeCode := CRMProduct.ProductTypeCode::SalesInventory;
        end else begin
            Blocked := SourceRecordRef.Field(Resource.FieldNo(Blocked)).Value();
            UnitOfMeasureFieldRef := SourceRecordRef.Field(Resource.FieldNo("Base Unit of Measure"));
            ProductTypeCode := CRMProduct.ProductTypeCode::Services;
        end;
        GeneralLedgerSetup.SetLoadFields("LCY Code");
        GeneralLedgerSetup.Get();
        CurrencyFieldRef := DestinationRecordRef.Field(CRMProduct.FieldNo(TransactionCurrencyId));
        Modified := CRMSynchHelper.UpdateCRMCurrencyIdIfChanged(Format(GeneralLedgerSetup."LCY Code"), CurrencyFieldRef);
        DestinationRecordRef.SetTable(CRMProduct);
        if CRMIntegrationManagement.IsUnitGroupMappingEnabled() then
            Modified := CRMSynchHelper.UpdateCRMProductUomscheduleId(CRMProduct, SourceRecordRef) or Modified
        else begin
            UnitOfMeasureFieldRef.TestField();
            Modified := CRMSynchHelper.UpdateCRMProductUoMFieldsIfChanged(CRMProduct, CopyStr(Format(UnitOfMeasureFieldRef.Value()), 1, 10)) or Modified;
        end;
        Modified := CRMSynchHelper.UpdateCRMProductPriceIfNegative(CRMProduct) or Modified;
        Modified := CRMSynchHelper.UpdateCRMProductQuantityOnHandIfNegative(CRMProduct) or Modified;
        if CRMIntegrationManagement.IsUnitGroupMappingEnabled() then
            Modified := CRMSynchHelper.UpdateCRMPriceListItems(CRMProduct) or Modified
        else
            Modified := CRMSynchHelper.UpdateCRMPriceListItem(CRMProduct) or Modified;
        Modified := CRMSynchHelper.UpdateCRMProductVendorNameIfChanged(CRMProduct) or Modified;
        Modified := CRMSynchHelper.UpdateCRMProductTypeCodeIfChanged(CRMProduct, ProductTypeCode) or Modified;
        if DestinationIsInserted then
            Modified := CRMSynchHelper.UpdateCRMProductStateCodeIfChanged(CRMProduct, Blocked) or Modified;
        if Modified then
            DestinationRecordRef.GetTable(CRMProduct);
    end;

    local procedure UpdateBlocked(var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef): Boolean
    var
        CRMProduct: Record "CRM Product";
        Item: Record Item;
        Resource: Record Resource;
        CRMSynchHelper: Codeunit "CRM Synch. Helper";
    begin
        SourceRecordRef.SetTable(CRMProduct);
        case DestinationRecordRef.Number() of
            Database::Item:
                begin
                    DestinationRecordRef.SetTable(Item);
                    if not CRMSynchHelper.UpdateItemBlockedIfChanged(Item, CRMProduct.StateCode <> CRMProduct.StateCode::Active) then
                        exit(false);
                    DestinationRecordRef.GetTable(Item);
                end;
            Database::Resource:
                begin
                    DestinationRecordRef.SetTable(Resource);
                    if not CRMSynchHelper.UpdateResourceBlockedIfChanged(Resource, CRMProduct.StateCode <> CRMProduct.StateCode::Active) then
                        exit(false);
                    DestinationRecordRef.GetTable(Resource);
                end;
            else
                exit(false);
        end;
        exit(true);
    end;

    local procedure FillItemKeyFromTemplate(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        ConfigTemplateHeader: Record "Config. Template Header";
        ConfigTemplateApplier: Codeunit "DVI Config. Template Applier";
        ItemTemplMgt: Codeunit "Item Templ. Mgt.";
        TemplateCode: Code[10];
    begin
        if DestinationRecordRef.Number() <> Database::Item then
            exit;
        Context.GetMapping(IntegrationTableMapping);
        TemplateCode := ConfigTemplateApplier.FindTemplateCode(IntegrationTableMapping, SourceRecordRef, DestinationRecordRef);
        if TemplateCode = '' then
            exit;
        if ConfigTemplateHeader.Get(TemplateCode) then
            ItemTemplMgt.FillItemKeyFromInitSeries(DestinationRecordRef, ConfigTemplateHeader);
    end;
}
