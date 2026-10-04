namespace DataverseIntegration.Test;

using DataverseIntegration.CDS;
using DataverseIntegration.Core;
using Microsoft.CRM.Contact;
using Microsoft.CRM.Team;
using Microsoft.Finance.Currency;
using Microsoft.Integration.D365Sales;
using Microsoft.Integration.SyncEngine;
using Microsoft.Purchases.Vendor;
using Microsoft.Sales.Customer;
using System.TestLibraries.Utilities;

codeunit 84018 "DVI CDS Handler Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLibrary: Codeunit "DVI Test Library";

    [Test]
    procedure SwitchingPicksTheHandlerOfEachCDSTablePair()
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
    begin
        // [GIVEN] / [WHEN] Mappings of each CDS table pair are switched
        // [THEN] Each gets the handler that serves its pair
        AssertSwitchedHandler('DVICUST', Database::Customer, Database::"CRM Account", Enum::"DVI Sync Handler"::DVICDSAccount);
        AssertSwitchedHandler('DVIVEND', Database::Vendor, Database::"CRM Account", Enum::"DVI Sync Handler"::DVICDSAccount);
        AssertSwitchedHandler('DVICONT', Database::Contact, Database::"CRM Contact", Enum::"DVI Sync Handler"::DVICDSContact);
        AssertSwitchedHandler('DVICURR', Database::Currency, Database::"CRM Transactioncurrency", Enum::"DVI Sync Handler"::DVICDSCurrency);
        AssertSwitchedHandler('DVISP', Database::"Salesperson/Purchaser", Database::"CRM Systemuser", Enum::"DVI Sync Handler"::DVICDSSalesperson);
        IntegrationTableMapping.SetRange(Name, 'DVICUST');
        Assert.RecordIsNotEmpty(IntegrationTableMapping);
    end;

    [Test]
    procedure InactiveAccountBlocksItsCustomer()
    var
        TempCRMAccount: Record "CRM Account" temporary;
        TempCustomer: Record Customer temporary;
        CDSRelations: Codeunit "DVI CDS Relations";
        AccountRecordRef: RecordRef;
        CustomerRecordRef: RecordRef;
    begin
        // [GIVEN] An inactive account and an unblocked customer
        TempCRMAccount.StatusCode := TempCRMAccount.StatusCode::Inactive;
        AccountRecordRef.GetTable(TempCRMAccount);
        CustomerRecordRef.GetTable(TempCustomer);

        // [WHEN] The account is synchronized to the customer
        // [THEN] The customer is blocked
        Assert.IsTrue(CDSRelations.BlockCustomerOfInactiveAccount(AccountRecordRef, CustomerRecordRef), 'The customer must be blocked.');
        Assert.AreEqual(Format(TempCustomer.Blocked::All), Format(CustomerRecordRef.Field(TempCustomer.FieldNo(Blocked)).Value()), 'Blocked');
    end;

    [Test]
    procedure ActiveAccountLeavesItsCustomerAlone()
    var
        TempCRMAccount: Record "CRM Account" temporary;
        TempCustomer: Record Customer temporary;
        CDSRelations: Codeunit "DVI CDS Relations";
        AccountRecordRef: RecordRef;
        CustomerRecordRef: RecordRef;
    begin
        // [GIVEN] An active account
        TempCRMAccount.StatusCode := TempCRMAccount.StatusCode::Active;
        AccountRecordRef.GetTable(TempCRMAccount);
        CustomerRecordRef.GetTable(TempCustomer);

        // [WHEN] / [THEN] The customer is not changed
        Assert.IsFalse(CDSRelations.BlockCustomerOfInactiveAccount(AccountRecordRef, CustomerRecordRef), 'The customer must stay unblocked.');
    end;

    [Test]
    procedure TransactionCurrencyWithoutSymbolGetsItsCode()
    var
        TempCurrency: Record Currency temporary;
        TempCRMTransactioncurrency: Record "CRM Transactioncurrency" temporary;
        CurrencyHandler: Codeunit "DVI Currency Handler";
        Context: Codeunit "DVI Sync Context";
        SourceRecordRef: RecordRef;
        DestinationRecordRef: RecordRef;
    begin
        // [GIVEN] A transaction currency without a symbol
        TempCRMTransactioncurrency.ISOCurrencyCode := 'EUR';
        SourceRecordRef.GetTable(TempCurrency);
        DestinationRecordRef.GetTable(TempCRMTransactioncurrency);
        Context.SetToIntegrationTable(true);

        // [WHEN] It is modified from Business Central
        CurrencyHandler.BeforeModify(Context, SourceRecordRef, DestinationRecordRef);

        // [THEN] The ISO code becomes the symbol
        Assert.AreEqual('EUR', Format(DestinationRecordRef.Field(TempCRMTransactioncurrency.FieldNo(CurrencySymbol)).Value()), 'Symbol');
    end;

    [Test]
    procedure NewSalespersonFromUserGetsTheNextCode()
    var
        SalespersonPurchaser: Record "Salesperson/Purchaser";
        TempCRMSystemuser: Record "CRM Systemuser" temporary;
        TempSalespersonPurchaser: Record "Salesperson/Purchaser" temporary;
        SalespersonHandler: Codeunit "DVI Salesperson Handler";
        Context: Codeunit "DVI Sync Context";
        SourceRecordRef: RecordRef;
        DestinationRecordRef: RecordRef;
    begin
        // [GIVEN] An existing generated salesperson code
        SalespersonPurchaser.SetFilter(Code, 'SP NO. 0*');
        SalespersonPurchaser.DeleteAll(false);
        SalespersonPurchaser.Init();
        SalespersonPurchaser.Code := 'SP NO. 00007';
        SalespersonPurchaser.Insert(false);
        SourceRecordRef.GetTable(TempCRMSystemuser);
        DestinationRecordRef.GetTable(TempSalespersonPurchaser);

        // [WHEN] A salesperson is created from a Dataverse user
        SalespersonHandler.BeforeInsert(Context, SourceRecordRef, DestinationRecordRef);

        // [THEN] It gets the next code
        Assert.AreEqual('SP NO. 00008', Format(DestinationRecordRef.Field(TempSalespersonPurchaser.FieldNo(Code)).Value()), 'Code');
    end;

    [Test]
    procedure ContactWithoutCustomerOrVendorIsNotSentToDataverse()
    var
        Contact: Record Contact;
        ContactHandler: Codeunit "DVI Contact Handler";
        Context: Codeunit "DVI Sync Context";
        ContactRecordRef: RecordRef;
    begin
        // [GIVEN] A person contact without a company related to a customer or vendor
        Contact.Init();
        Contact."No." := 'DVICT02';
        Contact.Type := Contact.Type::Person;
        Contact.Insert(false);
        ContactRecordRef.GetTable(Contact);
        Context.SetToIntegrationTable(true);

        // [WHEN] / [THEN] The contact is left out of the synchronization to Dataverse
        Assert.IsTrue(ContactHandler.IgnoreRecord(Context, ContactRecordRef), 'A contact without business relation must be ignored.');
    end;

    local procedure AssertSwitchedHandler(MappingName: Code[20]; TableId: Integer; IntegrationTableId: Integer; ExpectedHandler: Enum "DVI Sync Handler")
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        MappingAssignment: Record "DVI Mapping Assignment";
        DefaultAssignment: Codeunit "DVI Default Assignment";
    begin
        IntegrationTableMapping := TestLibrary.CreateDataverseMapping(MappingName, TableId, IntegrationTableId, IntegrationTableMapping.Direction::Bidirectional);
        DefaultAssignment.SwitchToRedesigned(IntegrationTableMapping);
        MappingAssignment.Get(MappingName);
        Assert.AreEqual(ExpectedHandler, MappingAssignment.Handler, MappingName);
        Assert.AreEqual(Enum::"DVI Integration Module"::DVIDataverse, MappingAssignment.Module, MappingName);
    end;
}
