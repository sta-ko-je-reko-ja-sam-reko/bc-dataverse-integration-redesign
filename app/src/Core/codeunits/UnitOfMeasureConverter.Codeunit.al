namespace DataverseIntegration.Core;

using Microsoft.Foundation.UOM;
using Microsoft.Integration.D365Sales;
using Microsoft.Integration.Dataverse;
using Microsoft.Inventory.Item;
using Microsoft.Pricing.PriceList;
using Microsoft.Projects.Resources.Resource;

codeunit 80044 "DVI Unit of Measure Converter" implements "DVI IValueConverter"
{
    Access = Public;

    procedure AppliesTo(var Context: Codeunit "DVI Sync Context"; var SourceFieldRef: FieldRef; var DestinationFieldRef: FieldRef): Boolean
    begin
        exit(IsLocalUnitOfMeasureField(SourceFieldRef) or IsProductUnitField(SourceFieldRef) or (SourceFieldRef.Record().Number() = Database::"Unit Group"));
    end;

    procedure Convert(var Context: Codeunit "DVI Sync Context"; var SourceFieldRef: FieldRef; var DestinationFieldRef: FieldRef; var NewValue: Variant; var NeedsConversion: Boolean): Boolean
    var
        CRMIntegrationManagement: Codeunit "CRM Integration Management";
        CRMSynchHelper: Codeunit "CRM Synch. Helper";
        CoupledKeyConverter: Codeunit "DVI Coupled Key Converter";
    begin
        NeedsConversion := false;
        if not CRMIntegrationManagement.IsUnitGroupMappingEnabled() then
            exit(CoupledKeyConverter.Convert(Context, SourceFieldRef, DestinationFieldRef, NewValue, NeedsConversion));
        if IsLocalUnitOfMeasureField(SourceFieldRef) then begin
            CRMSynchHelper.ConvertBaseUnitOfMeasureToUomId(SourceFieldRef, DestinationFieldRef, NewValue);
            exit(true);
        end;
        if IsProductUnitField(SourceFieldRef) then begin
            CRMSynchHelper.ConvertUomIdToBaseUnitOfMeasure(SourceFieldRef, DestinationFieldRef, NewValue);
            exit(true);
        end;
        if SourceFieldRef.Record().Number() = Database::"Unit Group" then begin
            CRMSynchHelper.PrefixUnitGroupCode(SourceFieldRef, NewValue);
            exit(true);
        end;
        exit(CoupledKeyConverter.Convert(Context, SourceFieldRef, DestinationFieldRef, NewValue, NeedsConversion));
    end;

    local procedure IsLocalUnitOfMeasureField(var SourceFieldRef: FieldRef): Boolean
    var
        Item: Record Item;
        Resource: Record Resource;
        PriceListLine: Record "Price List Line";
    begin
        case SourceFieldRef.Record().Number() of
            Database::Item:
                exit(SourceFieldRef.Number() = Item.FieldNo("Base Unit of Measure"));
            Database::Resource:
                exit(SourceFieldRef.Number() = Resource.FieldNo("Base Unit of Measure"));
            Database::"Price List Line":
                exit(SourceFieldRef.Number() = PriceListLine.FieldNo("Unit of Measure Code"));
        end;
        exit(false);
    end;

    local procedure IsProductUnitField(var SourceFieldRef: FieldRef): Boolean
    var
        CRMProduct: Record "CRM Product";
    begin
        exit((SourceFieldRef.Record().Number() = Database::"CRM Product") and (SourceFieldRef.Number() = CRMProduct.FieldNo(DefaultUoMId)));
    end;
}
