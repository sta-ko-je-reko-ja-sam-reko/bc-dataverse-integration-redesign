namespace DataverseIntegration.CDS;

using DataverseIntegration.Core;
using Microsoft.Finance.Currency;
using Microsoft.Integration.D365Sales;
using Microsoft.Integration.Dataverse;
using Microsoft.Integration.SyncEngine;

codeunit 80213 "DVI Currency Handler" implements "DVI IRecordSync", "DVI IRecordCoupling", "DVI IHandlerScope"
{
    Access = Public;

    var
        ExchangeRateMissingErr: Label 'Cannot find the exchange rate for the currency %1 at the current date. Add the exchange rate, so that the currency can be synchronized with Dataverse.', Comment = '%1 = currency code';

    procedure Serves(var Context: Codeunit "DVI Sync Context"): Boolean
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
    begin
        Context.GetMapping(IntegrationTableMapping);
        exit((IntegrationTableMapping."Table ID" = Database::Currency) and (IntegrationTableMapping."Integration Table ID" = Database::"CRM Transactioncurrency"));
    end;

    procedure DefaultModule(var Context: Codeunit "DVI Sync Context"): Enum "DVI Integration Module"
    begin
        exit(Enum::"DVI Integration Module"::DVIDataverse);
    end;

    procedure BeforeTransferFields(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    begin
    end;

    procedure AfterTransferFields(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef; var AdditionalFieldsModified: Boolean)
    var
        Currency: Record Currency;
        CRMTransactioncurrency: Record "CRM Transactioncurrency";
        CRMSynchHelper: Codeunit "CRM Synch. Helper";
        ExchangeRateFieldRef: FieldRef;
        CurrencyCode: Text;
        ExchangeRate: Decimal;
    begin
        AdditionalFieldsModified := false;
        if not Context.IsToIntegrationTable() then
            exit;
        CurrencyCode := Format(SourceRecordRef.Field(Currency.FieldNo(Code)).Value());
        ExchangeRate := CRMSynchHelper.GetCRMLCYToFCYExchangeRate(CopyStr(CurrencyCode, 1, 10));
        if ExchangeRate = 0 then
            Error(ExchangeRateMissingErr, CurrencyCode);
        ExchangeRateFieldRef := DestinationRecordRef.Field(CRMTransactioncurrency.FieldNo(ExchangeRate));
        AdditionalFieldsModified := CRMSynchHelper.UpdateFieldRefValueIfChanged(ExchangeRateFieldRef, Format(ExchangeRate));
    end;

    procedure BeforeInsert(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    var
        CRMTransactioncurrency: Record "CRM Transactioncurrency";
        CRMSynchHelper: Codeunit "CRM Synch. Helper";
    begin
        if not Context.IsToIntegrationTable() then
            exit;
        DestinationRecordRef.Field(CRMTransactioncurrency.FieldNo(CurrencyPrecision)).Value(CRMSynchHelper.GetCRMCurrencyDefaultPrecision());
        SetDefaultSymbol(DestinationRecordRef);
    end;

    procedure AfterInsert(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    begin
    end;

    procedure BeforeModify(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    begin
        if Context.IsToIntegrationTable() then
            SetDefaultSymbol(DestinationRecordRef);
    end;

    procedure AfterModify(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    begin
    end;

    procedure Unchanged(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    begin
    end;

    procedure FindUncoupledDestination(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef; var DestinationIsDeleted: Boolean): Boolean
    var
        Currency: Record Currency;
        CRMTransactioncurrency: Record "CRM Transactioncurrency";
    begin
        DestinationIsDeleted := false;
        if not Context.IsToIntegrationTable() then
            exit(false);
        CRMTransactioncurrency.SetRange(ISOCurrencyCode, Format(SourceRecordRef.Field(Currency.FieldNo(Code)).Value()));
        if not CRMTransactioncurrency.FindFirst() then
            exit(false);
        exit(DestinationRecordRef.Get(CRMTransactioncurrency.RecordId()));
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

    local procedure SetDefaultSymbol(var DestinationRecordRef: RecordRef)
    var
        CRMTransactioncurrency: Record "CRM Transactioncurrency";
        SymbolFieldRef: FieldRef;
    begin
        SymbolFieldRef := DestinationRecordRef.Field(CRMTransactioncurrency.FieldNo(CurrencySymbol));
        if Format(SymbolFieldRef.Value()) = '' then
            SymbolFieldRef.Value(DestinationRecordRef.Field(CRMTransactioncurrency.FieldNo(ISOCurrencyCode)).Value());
    end;
}
