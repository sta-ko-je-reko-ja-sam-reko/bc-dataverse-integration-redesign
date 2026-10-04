namespace DataverseIntegration.CRM;

using DataverseIntegration.Core;
using Microsoft.Integration.D365Sales;
using Microsoft.Integration.Dataverse;
using Microsoft.Inventory.Item;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Sales.Document;
using Microsoft.Sales.Setup;

codeunit 80416 "DVI Write-in Product Converter" implements "DVI IValueConverter"
{
    Access = Public;

    var
        NotCoupledErr: Label 'The %1 %2 is not coupled to a Dataverse product.', Comment = '%1 = line type, %2 = number';
        ProductNotCoupledErr: Label 'The Dataverse product %1 is not coupled to an item or resource.', Comment = '%1 = product ID';
        WriteInProductErr: Label 'The Dataverse order line has a write-in product. Choose the write-in product in Sales & Receivables Setup.';

    procedure AppliesTo(var Context: Codeunit "DVI Sync Context"; var SourceFieldRef: FieldRef; var DestinationFieldRef: FieldRef): Boolean
    begin
        exit(IsLineProduct(SourceFieldRef, DestinationFieldRef) or IsLineProduct(DestinationFieldRef, SourceFieldRef));
    end;

    procedure Convert(var Context: Codeunit "DVI Sync Context"; var SourceFieldRef: FieldRef; var DestinationFieldRef: FieldRef; var NewValue: Variant; var NeedsConversion: Boolean): Boolean
    begin
        NeedsConversion := false;
        if IsLineProduct(SourceFieldRef, DestinationFieldRef) then
            exit(ConvertToProductId(SourceFieldRef, NewValue));
        if IsLineProduct(DestinationFieldRef, SourceFieldRef) then
            exit(ConvertToNo(SourceFieldRef, NewValue));
        exit(false);
    end;

    local procedure ConvertToProductId(var NoFieldRef: FieldRef; var NewValue: Variant): Boolean
    var
        SalesLine: Record "Sales Line";
        Item: Record Item;
        Resource: Record Resource;
        CRMIntegrationRecord: Record "CRM Integration Record";
        SalesLineRecordRef: RecordRef;
        ProductId: Guid;
        EmptyId: Guid;
    begin
        SalesLineRecordRef := NoFieldRef.Record();
        SalesLineRecordRef.SetTable(SalesLine);
        if (SalesLine."No." = '') or IsWriteInProduct(SalesLine."No.") then begin
            NewValue := EmptyId;
            exit(true);
        end;
        case SalesLine.Type of
            SalesLine.Type::Item:
                if Item.Get(SalesLine."No.") then
                    if CRMIntegrationRecord.FindIDFromRecordID(Item.RecordId(), ProductId) then begin
                        NewValue := ProductId;
                        exit(true);
                    end;
            SalesLine.Type::Resource:
                if Resource.Get(SalesLine."No.") then
                    if CRMIntegrationRecord.FindIDFromRecordID(Resource.RecordId(), ProductId) then begin
                        NewValue := ProductId;
                        exit(true);
                    end;
        end;
        Error(NotCoupledErr, SalesLine.Type, SalesLine."No.");
    end;

    local procedure ConvertToNo(var ProductIdFieldRef: FieldRef; var NewValue: Variant): Boolean
    var
        SalesReceivablesSetup: Record "Sales & Receivables Setup";
        Item: Record Item;
        Resource: Record Resource;
        CRMIntegrationRecord: Record "CRM Integration Record";
        LocalRecordId: RecordId;
        ProductId: Guid;
    begin
        ProductId := ProductIdFieldRef.Value();
        if IsNullGuid(ProductId) then begin
            SalesReceivablesSetup.SetLoadFields("Write-in Product No.");
            SalesReceivablesSetup.Get();
            if SalesReceivablesSetup."Write-in Product No." = '' then
                Error(WriteInProductErr);
            NewValue := SalesReceivablesSetup."Write-in Product No.";
            exit(true);
        end;
        if CRMIntegrationRecord.FindRecordIDFromID(ProductId, Database::Item, LocalRecordId) then
            if Item.Get(LocalRecordId) then begin
                NewValue := Item."No.";
                exit(true);
            end;
        if CRMIntegrationRecord.FindRecordIDFromID(ProductId, Database::Resource, LocalRecordId) then
            if Resource.Get(LocalRecordId) then begin
                NewValue := Resource."No.";
                exit(true);
            end;
        Error(ProductNotCoupledErr, ProductId);
    end;

    local procedure IsLineProduct(var NoFieldRef: FieldRef; var ProductIdFieldRef: FieldRef): Boolean
    var
        SalesLine: Record "Sales Line";
        CRMSalesorderdetail: Record "CRM Salesorderdetail";
    begin
        if (NoFieldRef.Record().Number() <> Database::"Sales Line") or (NoFieldRef.Number() <> SalesLine.FieldNo("No.")) then
            exit(false);
        exit((ProductIdFieldRef.Record().Number() = Database::"CRM Salesorderdetail") and (ProductIdFieldRef.Number() = CRMSalesorderdetail.FieldNo(ProductId)));
    end;

    local procedure IsWriteInProduct(No: Code[20]): Boolean
    var
        SalesReceivablesSetup: Record "Sales & Receivables Setup";
    begin
        SalesReceivablesSetup.SetLoadFields("Write-in Product No.");
        if not SalesReceivablesSetup.Get() then
            exit(false);
        exit(SalesReceivablesSetup."Write-in Product No." = No);
    end;
}
