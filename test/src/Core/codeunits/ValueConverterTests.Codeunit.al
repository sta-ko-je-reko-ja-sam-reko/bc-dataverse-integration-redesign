namespace DataverseIntegration.Test;

using DataverseIntegration.Core;
using Microsoft.CRM.Contact;
using Microsoft.Integration.D365Sales;
using Microsoft.Integration.Dataverse;
using Microsoft.Integration.SyncEngine;
using Microsoft.Sales.Customer;
using System.TestLibraries.Utilities;

codeunit 84017 "DVI Value Converter Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLibrary: Codeunit "DVI Test Library";

    [Test]
    procedure SwitchingAssignsConvertersByFieldPair()
    var
        Customer: Record Customer;
        CRMAccount: Record "CRM Account";
        IntegrationTableMapping: Record "Integration Table Mapping";
        DefaultAssignment: Codeunit "DVI Default Assignment";
        ConverterAssignment: Codeunit "DVI Converter Assignment";
    begin
        // [GIVEN] A customer mapping with a name, a primary contact, a currency and an owner field mapping, and a contact mapping
        IntegrationTableMapping := TestLibrary.CreateDataverseMapping('DVITEST', Database::Customer, Database::"CRM Account", IntegrationTableMapping.Direction::Bidirectional);
        TestLibrary.CreateDataverseMapping('DVICONTACT', Database::Contact, Database::"CRM Contact", IntegrationTableMapping.Direction::Bidirectional);
        TestLibrary.CreateFieldMapping('DVITEST', Customer.FieldNo(Name), CRMAccount.FieldNo(Name), IntegrationTableMapping.Direction::Bidirectional, '');
        TestLibrary.CreateFieldMapping('DVITEST', Customer.FieldNo("Primary Contact No."), CRMAccount.FieldNo(PrimaryContactId), IntegrationTableMapping.Direction::Bidirectional, '');
        TestLibrary.CreateFieldMapping('DVITEST', Customer.FieldNo("Currency Code"), CRMAccount.FieldNo(TransactionCurrencyId), IntegrationTableMapping.Direction::ToIntegrationTable, '');
        TestLibrary.CreateFieldMapping('DVITEST', Customer.FieldNo("Salesperson Code"), CRMAccount.FieldNo(OwnerId), IntegrationTableMapping.Direction::ToIntegrationTable, '');

        // [WHEN] The mapping is switched to the redesigned synchronization
        DefaultAssignment.SwitchToRedesigned(IntegrationTableMapping);

        // [THEN] Each field mapping gets the converter for its field pair
        Assert.AreEqual(Enum::"DVI Value Converter"::DVIDirect, ConverterAssignment.GetConverter('DVITEST', Customer.FieldNo(Name), CRMAccount.FieldNo(Name)), 'Name');
        Assert.AreEqual(Enum::"DVI Value Converter"::DVIPrimaryContact, ConverterAssignment.GetConverter('DVITEST', Customer.FieldNo("Primary Contact No."), CRMAccount.FieldNo(PrimaryContactId)), 'Primary contact');
        Assert.AreEqual(Enum::"DVI Value Converter"::DVICurrency, ConverterAssignment.GetConverter('DVITEST', Customer.FieldNo("Currency Code"), CRMAccount.FieldNo(TransactionCurrencyId)), 'Currency');
        Assert.AreEqual(Enum::"DVI Value Converter"::DVIOwner, ConverterAssignment.GetConverter('DVITEST', Customer.FieldNo("Salesperson Code"), CRMAccount.FieldNo(OwnerId)), 'Owner');
    end;

    [Test]
    procedure CoupledKeyConvertsLocalKeyToCoupledDataverseId()
    var
        Contact: Record Contact;
        TempCustomer: Record Customer temporary;
        TempCRMAccount: Record "CRM Account" temporary;
        IntegrationTableMapping: Record "Integration Table Mapping";
        CoupledKeyConverter: Codeunit "DVI Coupled Key Converter";
        Context: Codeunit "DVI Sync Context";
        SourceRecordRef: RecordRef;
        DestinationRecordRef: RecordRef;
        SourceFieldRef: FieldRef;
        DestinationFieldRef: FieldRef;
        ContactId: Guid;
        NewValue: Variant;
        NeedsConversion: Boolean;
    begin
        // [GIVEN] A contact mapping and a contact coupled to a Dataverse contact
        IntegrationTableMapping := TestLibrary.CreateDataverseMapping('DVICONTACT', Database::Contact, Database::"CRM Contact", IntegrationTableMapping.Direction::Bidirectional);
        ContactId := CreateCoupledContact(Contact);
        TempCustomer."Primary Contact No." := Contact."No.";
        SourceRecordRef.GetTable(TempCustomer);
        DestinationRecordRef.GetTable(TempCRMAccount);
        SourceFieldRef := SourceRecordRef.Field(TempCustomer.FieldNo("Primary Contact No."));
        DestinationFieldRef := DestinationRecordRef.Field(TempCRMAccount.FieldNo(PrimaryContactId));
        Context.SetToIntegrationTable(true);

        // [WHEN] The customer's primary contact is converted for Dataverse
        Assert.IsTrue(CoupledKeyConverter.Convert(Context, SourceFieldRef, DestinationFieldRef, NewValue, NeedsConversion), 'The value must be converted.');

        // [THEN] The account gets the coupled Dataverse contact
        Assert.AreEqual(Format(ContactId), Format(NewValue), 'Coupled contact ID');
        Assert.IsFalse(NeedsConversion, 'A GUID needs no further conversion.');
    end;

    [Test]
    procedure CoupledKeyConvertsDataverseIdToCoupledLocalKey()
    var
        Contact: Record Contact;
        TempCustomer: Record Customer temporary;
        TempCRMAccount: Record "CRM Account" temporary;
        IntegrationTableMapping: Record "Integration Table Mapping";
        CoupledKeyConverter: Codeunit "DVI Coupled Key Converter";
        Context: Codeunit "DVI Sync Context";
        SourceRecordRef: RecordRef;
        DestinationRecordRef: RecordRef;
        SourceFieldRef: FieldRef;
        DestinationFieldRef: FieldRef;
        NewValue: Variant;
        NeedsConversion: Boolean;
    begin
        // [GIVEN] A contact mapping and an account whose primary contact is a coupled Dataverse contact
        IntegrationTableMapping := TestLibrary.CreateDataverseMapping('DVICONTACT', Database::Contact, Database::"CRM Contact", IntegrationTableMapping.Direction::Bidirectional);
        TempCRMAccount.PrimaryContactId := CreateCoupledContact(Contact);
        SourceRecordRef.GetTable(TempCRMAccount);
        DestinationRecordRef.GetTable(TempCustomer);
        SourceFieldRef := SourceRecordRef.Field(TempCRMAccount.FieldNo(PrimaryContactId));
        DestinationFieldRef := DestinationRecordRef.Field(TempCustomer.FieldNo("Primary Contact No."));

        // [WHEN] The account's primary contact is converted for Business Central
        Assert.IsTrue(CoupledKeyConverter.Convert(Context, SourceFieldRef, DestinationFieldRef, NewValue, NeedsConversion), 'The value must be converted.');

        // [THEN] The customer gets the coupled contact's number
        Assert.AreEqual(Contact."No.", Format(NewValue), 'Coupled contact number');
    end;

    [Test]
    procedure BlankKeyBecomesEmptyId()
    var
        TempCustomer: Record Customer temporary;
        TempCRMAccount: Record "CRM Account" temporary;
        IntegrationTableMapping: Record "Integration Table Mapping";
        CoupledKeyConverter: Codeunit "DVI Coupled Key Converter";
        Context: Codeunit "DVI Sync Context";
        SourceRecordRef: RecordRef;
        DestinationRecordRef: RecordRef;
        SourceFieldRef: FieldRef;
        DestinationFieldRef: FieldRef;
        EmptyId: Guid;
        NewValue: Variant;
        NeedsConversion: Boolean;
    begin
        // [GIVEN] A contact mapping and a customer without a primary contact
        TestLibrary.CreateDataverseMapping('DVICONTACT', Database::Contact, Database::"CRM Contact", IntegrationTableMapping.Direction::Bidirectional);
        SourceRecordRef.GetTable(TempCustomer);
        DestinationRecordRef.GetTable(TempCRMAccount);
        SourceFieldRef := SourceRecordRef.Field(TempCustomer.FieldNo("Primary Contact No."));
        DestinationFieldRef := DestinationRecordRef.Field(TempCRMAccount.FieldNo(PrimaryContactId));

        // [WHEN] / [THEN] The blank key converts to an empty Dataverse ID
        Assert.IsTrue(CoupledKeyConverter.Convert(Context, SourceFieldRef, DestinationFieldRef, NewValue, NeedsConversion), 'The value must be converted.');
        Assert.AreEqual(Format(EmptyId), Format(NewValue), 'Empty ID');
    end;

    [Test]
    procedure TeamOwnershipKeepsTheDataverseOwner()
    var
        CDSConnectionSetup: Record "CDS Connection Setup";
        TempCustomer: Record Customer temporary;
        TempCRMAccount: Record "CRM Account" temporary;
        OwnerConverter: Codeunit "DVI Owner Converter";
        Context: Codeunit "DVI Sync Context";
        SourceRecordRef: RecordRef;
        DestinationRecordRef: RecordRef;
        SourceFieldRef: FieldRef;
        DestinationFieldRef: FieldRef;
        OwnerId: Guid;
        NewValue: Variant;
        NeedsConversion: Boolean;
    begin
        // [GIVEN] Team ownership and an account owned by a team
        if not CDSConnectionSetup.Get() then begin
            CDSConnectionSetup.Init();
            CDSConnectionSetup.Insert(false);
        end;
        CDSConnectionSetup."Ownership Model" := CDSConnectionSetup."Ownership Model"::Team;
        CDSConnectionSetup.Modify(false);
        OwnerId := CreateGuid();
        TempCRMAccount.OwnerId := OwnerId;
        TempCustomer."Salesperson Code" := 'DVISP';
        SourceRecordRef.GetTable(TempCustomer);
        DestinationRecordRef.GetTable(TempCRMAccount);
        SourceFieldRef := SourceRecordRef.Field(TempCustomer.FieldNo("Salesperson Code"));
        DestinationFieldRef := DestinationRecordRef.Field(TempCRMAccount.FieldNo(OwnerId));

        // [WHEN] The salesperson is converted to the owner
        Assert.IsTrue(OwnerConverter.Convert(Context, SourceFieldRef, DestinationFieldRef, NewValue, NeedsConversion), 'The value must be converted.');

        // [THEN] The team stays the owner
        Assert.AreEqual(Format(OwnerId), Format(NewValue), 'Owner');
    end;

    local procedure CreateCoupledContact(var Contact: Record Contact) ContactId: Guid
    var
        CRMIntegrationRecord: Record "CRM Integration Record";
    begin
        Contact.Init();
        Contact."No." := 'DVICT01';
        Contact.Insert(false);
        ContactId := CreateGuid();
        CRMIntegrationRecord.Init();
        CRMIntegrationRecord."CRM ID" := ContactId;
        CRMIntegrationRecord."Integration ID" := Contact.SystemId;
        CRMIntegrationRecord."Table ID" := Database::Contact;
        CRMIntegrationRecord.Insert(false);
    end;
}
