namespace DataverseIntegration.CRM;

using DataverseIntegration.CDS;
using DataverseIntegration.Core;
using Microsoft.Integration.D365Sales;
using Microsoft.Integration.Dataverse;
using Microsoft.Integration.SyncEngine;
using Microsoft.Pricing.PriceList;
using Microsoft.Sales.Pricing;

codeunit 80403 "DVI Price Level Handler" implements "DVI IRecordSync", "DVI IHandlerScope"
{
    Access = Public;

    procedure Serves(var Context: Codeunit "DVI Sync Context"): Boolean
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
    begin
        Context.GetMapping(IntegrationTableMapping);
        exit((IntegrationTableMapping."Table ID" in [Database::"Customer Price Group", Database::"Price List Header"]) and (IntegrationTableMapping."Integration Table ID" = Database::"CRM Pricelevel"));
    end;

    procedure DefaultModule(var Context: Codeunit "DVI Sync Context"): Enum "DVI Integration Module"
    begin
        exit(Enum::"DVI Integration Module"::DVISales);
    end;

    procedure BeforeTransferFields(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    begin
    end;

    procedure AfterTransferFields(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef; var AdditionalFieldsModified: Boolean)
    begin
        AdditionalFieldsModified := false;
    end;

    procedure BeforeInsert(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    var
        CRMPricelevel: Record "CRM Pricelevel";
        CRMTransactioncurrency: Record "CRM Transactioncurrency";
        CRMSynchHelper: Codeunit "CRM Synch. Helper";
        CDSCompany: Codeunit "DVI CDS Company";
        CurrencyFieldRef: FieldRef;
        OutStream: OutStream;
    begin
        if not Context.IsToIntegrationTable() then
            exit;
        CheckSource(Context, SourceRecordRef, CRMTransactioncurrency);
        CurrencyFieldRef := DestinationRecordRef.Field(CRMPricelevel.FieldNo(TransactionCurrencyId));
        CRMSynchHelper.UpdateCRMCurrencyIdIfChanged(CRMTransactioncurrency.ISOCurrencyCode, CurrencyFieldRef);
        DestinationRecordRef.SetTable(CRMPricelevel);
        CRMPricelevel.Description.CreateOutStream(OutStream, TextEncoding::UTF16);
        OutStream.WriteText(SourceDescription(SourceRecordRef));
        if SourceRecordRef.Number() = Database::"Price List Header" then
            if IsActivePriceList(SourceRecordRef) then
                CRMPricelevel.StateCode := CRMPricelevel.StateCode::Active
            else
                CRMPricelevel.StateCode := CRMPricelevel.StateCode::Inactive;
        DestinationRecordRef.GetTable(CRMPricelevel);
        CDSCompany.SetCompanyId(DestinationRecordRef);
    end;

    procedure AfterInsert(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    var
        CRMPrices: Codeunit "DVI CRM Prices";
    begin
        if Context.IsToIntegrationTable() then
            CRMPrices.QueuePrices(Context, SourceRecordRef);
    end;

    procedure BeforeModify(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    var
        CRMPricelevel: Record "CRM Pricelevel";
        CRMTransactioncurrency: Record "CRM Transactioncurrency";
        CDSCompany: Codeunit "DVI CDS Company";
    begin
        if not Context.IsToIntegrationTable() then
            exit;
        CheckSource(Context, SourceRecordRef, CRMTransactioncurrency);
        DestinationRecordRef.SetTable(CRMPricelevel);
        CRMPricelevel.TestField(TransactionCurrencyId, CRMTransactioncurrency.TransactionCurrencyId);
        CDSCompany.SetCompanyId(DestinationRecordRef);
    end;

    procedure AfterModify(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    var
        CRMPrices: Codeunit "DVI CRM Prices";
    begin
        if Context.IsToIntegrationTable() then
            CRMPrices.QueuePrices(Context, SourceRecordRef);
    end;

    procedure Unchanged(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    var
        CRMPrices: Codeunit "DVI CRM Prices";
    begin
        if Context.IsToIntegrationTable() then
            CRMPrices.QueuePrices(Context, SourceRecordRef);
    end;

    local procedure CheckSource(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var CRMTransactioncurrency: Record "CRM Transactioncurrency")
    var
        CustomerPriceGroup: Record "Customer Price Group";
        PriceListHeader: Record "Price List Header";
        CRMPrices: Codeunit "DVI CRM Prices";
    begin
        if SourceRecordRef.Number() = Database::"Customer Price Group" then begin
            SourceRecordRef.SetTable(CustomerPriceGroup);
            CRMPrices.CheckCustomerPriceGroup(Context, CustomerPriceGroup, CRMTransactioncurrency);
        end else begin
            SourceRecordRef.SetTable(PriceListHeader);
            CRMPrices.CheckPriceList(Context, PriceListHeader, CRMTransactioncurrency);
        end;
    end;

    local procedure SourceDescription(var SourceRecordRef: RecordRef): Text
    var
        CustomerPriceGroup: Record "Customer Price Group";
        PriceListHeader: Record "Price List Header";
    begin
        if SourceRecordRef.Number() = Database::"Customer Price Group" then
            exit(Format(SourceRecordRef.Field(CustomerPriceGroup.FieldNo(Description)).Value()));
        exit(Format(SourceRecordRef.Field(PriceListHeader.FieldNo(Description)).Value()));
    end;

    local procedure IsActivePriceList(var SourceRecordRef: RecordRef): Boolean
    var
        PriceListHeader: Record "Price List Header";
    begin
        SourceRecordRef.SetTable(PriceListHeader);
        exit(PriceListHeader.Status = PriceListHeader.Status::Active);
    end;
}
