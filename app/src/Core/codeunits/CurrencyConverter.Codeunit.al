namespace DataverseIntegration.Core;

using Microsoft.Finance.Currency;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Integration.D365Sales;
using Microsoft.Integration.Dataverse;

codeunit 80043 "DVI Currency Converter" implements "DVI IValueConverter"
{
    Access = Public;

    procedure AppliesTo(var Context: Codeunit "DVI Sync Context"; var SourceFieldRef: FieldRef; var DestinationFieldRef: FieldRef): Boolean
    begin
        exit(SourceFieldRef.Relation() in [Database::Currency, Database::"CRM Transactioncurrency"]);
    end;

    procedure Convert(var Context: Codeunit "DVI Sync Context"; var SourceFieldRef: FieldRef; var DestinationFieldRef: FieldRef; var NewValue: Variant; var NeedsConversion: Boolean): Boolean
    var
        CRMSynchHelper: Codeunit "CRM Synch. Helper";
        CoupledKeyConverter: Codeunit "DVI Coupled Key Converter";
    begin
        NeedsConversion := false;
        if ConvertLocalCurrencyInOtherBaseCurrency(SourceFieldRef, DestinationFieldRef, NewValue) then
            exit(true);
        if CRMSynchHelper.FindNewValueForSpecialMapping(SourceFieldRef, NewValue) then
            exit(true);
        exit(CoupledKeyConverter.Convert(Context, SourceFieldRef, DestinationFieldRef, NewValue, NeedsConversion));
    end;

    local procedure ConvertLocalCurrencyInOtherBaseCurrency(var SourceFieldRef: FieldRef; var DestinationFieldRef: FieldRef; var NewValue: Variant): Boolean
    var
        CDSConnectionSetup: Record "CDS Connection Setup";
        GeneralLedgerSetup: Record "General Ledger Setup";
        CRMTransactioncurrency: Record "CRM Transactioncurrency";
        TransactionCurrencyId: Guid;
    begin
        CDSConnectionSetup.SetLoadFields(BaseCurrencyCode);
        if not CDSConnectionSetup.Get() then
            exit(false);
        if CDSConnectionSetup.BaseCurrencyCode = '' then
            exit(false);
        GeneralLedgerSetup.SetLoadFields("LCY Code");
        GeneralLedgerSetup.Get();
        if GeneralLedgerSetup."LCY Code" = CDSConnectionSetup.BaseCurrencyCode then
            exit(false);
        if SourceFieldRef.Relation() = Database::Currency then begin
            if Format(SourceFieldRef.Value()) <> '' then
                exit(false);
            CRMTransactioncurrency.SetRange(ISOCurrencyCode, CopyStr(GeneralLedgerSetup."LCY Code", 1, MaxStrLen(CRMTransactioncurrency.ISOCurrencyCode)));
            if not CRMTransactioncurrency.FindFirst() then
                exit(false);
            NewValue := CRMTransactioncurrency.TransactionCurrencyId;
            exit(true);
        end;
        if DestinationFieldRef.Relation() <> Database::Currency then
            exit(false);
        Evaluate(TransactionCurrencyId, Format(SourceFieldRef.Value()));
        if not CRMTransactioncurrency.Get(TransactionCurrencyId) then
            exit(false);
        if Format(CRMTransactioncurrency.ISOCurrencyCode) <> Format(GeneralLedgerSetup."LCY Code") then
            exit(false);
        NewValue := '';
        exit(true);
    end;
}
