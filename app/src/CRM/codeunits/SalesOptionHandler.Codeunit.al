namespace DataverseIntegration.CRM;

using DataverseIntegration.Core;
using Microsoft.Foundation.PaymentTerms;
using Microsoft.Foundation.Shipping;
using Microsoft.Integration.D365Sales;
using Microsoft.Integration.Dataverse;
using Microsoft.Integration.SyncEngine;
using Microsoft.Inventory.Location;
using System.Reflection;

codeunit 80406 "DVI Sales Option Handler" implements "DVI IRecordSync", "DVI IHandlerScope"
{
    Access = Public;

    var
        SalesOrderEntityTok: Label 'salesorder', Locked = true;
        QuoteEntityTok: Label 'quote', Locked = true;
        InvoiceEntityTok: Label 'invoice', Locked = true;
        PaymentTermsFieldTok: Label 'paymenttermscode', Locked = true;
        FreightTermsFieldTok: Label 'freighttermscode', Locked = true;
        ShippingMethodFieldTok: Label 'shippingmethodcode', Locked = true;

    procedure Serves(var Context: Codeunit "DVI Sync Context"): Boolean
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        "Field": Record "Field";
    begin
        Context.GetMapping(IntegrationTableMapping);
        if IntegrationTableMapping."Int. Table UID Field Type" <> Field.Type::Option then
            exit(false);
        exit(IntegrationTableMapping."Table ID" in [Database::"Payment Terms", Database::"Shipment Method", Database::"Shipping Agent"]);
    end;

    procedure DefaultModule(var Context: Codeunit "DVI Sync Context"): Enum "DVI Integration Module"
    begin
        exit(Enum::"DVI Integration Module"::DVIDataverse);
    end;

    procedure BeforeTransferFields(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    begin
    end;

    procedure AfterTransferFields(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef; var AdditionalFieldsModified: Boolean)
    begin
        AdditionalFieldsModified := false;
    end;

    procedure BeforeInsert(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    begin
    end;

    procedure AfterInsert(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    begin
        PushToDocuments(Context, SourceRecordRef, DestinationRecordRef);
    end;

    procedure BeforeModify(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    begin
    end;

    procedure AfterModify(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    begin
        PushToDocuments(Context, SourceRecordRef, DestinationRecordRef);
    end;

    procedure Unchanged(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    begin
    end;

    /// <summary>
    /// Writes the labels of every coupled payment term, shipment method and shipping agent to the option sets of Dataverse sales orders, quotes and invoices.
    /// </summary>
    procedure SyncDocumentOptionSets()
    var
        CRMOptionMapping: Record "CRM Option Mapping";
    begin
        if not IsSalesIntegrationEnabled() then
            exit;
        CRMOptionMapping.SetLoadFields("Table ID", "Option Value", "Option Value Caption");
        if not CRMOptionMapping.FindSet() then
            exit;
        repeat
            if CRMOptionMapping."Option Value Caption" <> '' then
                PushLabel(CRMOptionMapping."Table ID", CRMOptionMapping."Option Value", CRMOptionMapping."Option Value Caption");
        until CRMOptionMapping.Next() = 0;
    end;

    local procedure PushToDocuments(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        TempOptionValue: Record "DVI Option Value" temporary;
    begin
        if not IsSalesIntegrationEnabled() then
            exit;
        if Context.IsToIntegrationTable() then
            DestinationRecordRef.SetTable(TempOptionValue)
        else
            SourceRecordRef.SetTable(TempOptionValue);
        if TempOptionValue."Code" = '' then
            exit;
        Context.GetMapping(IntegrationTableMapping);
        PushLabel(IntegrationTableMapping."Table ID", TempOptionValue."Option Id", TempOptionValue."Code");
    end;

    local procedure PushLabel(TableId: Integer; OptionId: Integer; OptionLabel: Text)
    begin
        case TableId of
            Database::"Payment Terms":
                begin
                    UpdateOrInsertOption(SalesOrderEntityTok, PaymentTermsFieldTok, OptionId, OptionLabel);
                    UpdateOrInsertOption(QuoteEntityTok, PaymentTermsFieldTok, OptionId, OptionLabel);
                    UpdateOrInsertOption(InvoiceEntityTok, PaymentTermsFieldTok, OptionId, OptionLabel);
                end;
            Database::"Shipment Method":
                begin
                    UpdateOrInsertOption(SalesOrderEntityTok, FreightTermsFieldTok, OptionId, OptionLabel);
                    UpdateOrInsertOption(QuoteEntityTok, FreightTermsFieldTok, OptionId, OptionLabel);
                end;
            Database::"Shipping Agent":
                begin
                    UpdateOrInsertOption(SalesOrderEntityTok, ShippingMethodFieldTok, OptionId, OptionLabel);
                    UpdateOrInsertOption(QuoteEntityTok, ShippingMethodFieldTok, OptionId, OptionLabel);
                    UpdateOrInsertOption(InvoiceEntityTok, ShippingMethodFieldTok, OptionId, OptionLabel);
                end;
        end;
    end;

    local procedure UpdateOrInsertOption(EntityName: Text; FieldName: Text; OptionId: Integer; OptionLabel: Text)
    var
        CDSIntegrationMgt: Codeunit "CDS Integration Mgt.";
        OptionLabels: Dictionary of [Integer, Text];
    begin
        OptionLabels := CDSIntegrationMgt.GetOptionSetMetadata(EntityName, FieldName);
        if not OptionLabels.ContainsKey(OptionId) then begin
            CDSIntegrationMgt.InsertOptionSetMetadataWithOptionValue(EntityName, FieldName, OptionLabel, OptionId);
            exit;
        end;
        if OptionLabels.Get(OptionId) <> OptionLabel then
            CDSIntegrationMgt.UpdateOptionSetMetadata(EntityName, FieldName, OptionId, OptionLabel);
    end;

    local procedure IsSalesIntegrationEnabled(): Boolean
    var
        CRMIntegrationManagement: Codeunit "CRM Integration Management";
    begin
        exit(CRMIntegrationManagement.IsCRMIntegrationEnabled());
    end;
}
