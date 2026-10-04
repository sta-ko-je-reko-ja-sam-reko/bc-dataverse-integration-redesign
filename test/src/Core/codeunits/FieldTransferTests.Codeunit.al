namespace DataverseIntegration.Test;

using DataverseIntegration.Core;
using Microsoft.Integration.D365Sales;
using Microsoft.Integration.SyncEngine;
using Microsoft.Sales.Customer;
using System.TestLibraries.Utilities;

codeunit 84014 "DVI Field Transfer Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLibrary: Codeunit "DVI Test Library";

    [Test]
    procedure NewDestinationReceivesMappedValue()
    var
        TempCustomer: Record Customer temporary;
        TempCRMAccount: Record "CRM Account" temporary;
        FieldTransfer: Codeunit "DVI Field Transfer";
        Context: Codeunit "DVI Sync Context";
        SourceRecordRef: RecordRef;
        DestinationRecordRef: RecordRef;
    begin
        // [GIVEN] A mapping of Customer Name to Account Name, and a customer named Contoso
        CreateNameMapping(TempCustomer.FieldNo(Name), TempCRMAccount.FieldNo(Name), 0);
        TempCustomer.Name := 'Contoso';
        SourceRecordRef.GetTable(TempCustomer);
        DestinationRecordRef.GetTable(TempCRMAccount);

        // [WHEN] The fields are transferred to a new account
        Assert.IsTrue(FieldTransfer.LoadFieldMappings(GetMapping(), true), 'Field mappings must load.');
        FieldTransfer.TransferFields(Context, SourceRecordRef, DestinationRecordRef, false);

        // [THEN] The account gets the name
        Assert.AreEqual('Contoso', Format(DestinationRecordRef.Field(TempCRMAccount.FieldNo(Name)).Value()), 'Account name');
        Assert.IsTrue(FieldTransfer.WasModified(), 'A new destination is always modified.');
    end;

    [Test]
    procedure UnchangedValueIsNotReportedAsModified()
    var
        TempCustomer: Record Customer temporary;
        TempCRMAccount: Record "CRM Account" temporary;
        FieldTransfer: Codeunit "DVI Field Transfer";
        Context: Codeunit "DVI Sync Context";
        SourceRecordRef: RecordRef;
        DestinationRecordRef: RecordRef;
    begin
        // [GIVEN] A customer and an account with the same name
        CreateNameMapping(TempCustomer.FieldNo(Name), TempCRMAccount.FieldNo(Name), 0);
        TempCustomer.Name := 'Contoso';
        TempCRMAccount.Name := 'Contoso';
        SourceRecordRef.GetTable(TempCustomer);
        DestinationRecordRef.GetTable(TempCRMAccount);

        // [WHEN] Only modified fields are transferred
        FieldTransfer.LoadFieldMappings(GetMapping(), true);
        FieldTransfer.TransferFields(Context, SourceRecordRef, DestinationRecordRef, true);

        // [THEN] Nothing is reported as modified
        Assert.IsFalse(FieldTransfer.WasModified(), 'An equal value must not count as a change.');
    end;

    [Test]
    procedure BidirectionalChangeIsReportedForConflictDetection()
    var
        TempCustomer: Record Customer temporary;
        TempCRMAccount: Record "CRM Account" temporary;
        FieldTransfer: Codeunit "DVI Field Transfer";
        Context: Codeunit "DVI Sync Context";
        SourceRecordRef: RecordRef;
        DestinationRecordRef: RecordRef;
        SourceFieldNo: Integer;
        DestinationFieldNo: Integer;
    begin
        // [GIVEN] A bidirectional field mapping and different names on both sides
        CreateNameMapping(TempCustomer.FieldNo(Name), TempCRMAccount.FieldNo(Name), 0);
        TempCustomer.Name := 'Contoso';
        TempCRMAccount.Name := 'Fabrikam';
        SourceRecordRef.GetTable(TempCustomer);
        DestinationRecordRef.GetTable(TempCRMAccount);

        // [WHEN] Only modified fields are transferred
        FieldTransfer.LoadFieldMappings(GetMapping(), true);
        FieldTransfer.TransferFields(Context, SourceRecordRef, DestinationRecordRef, true);

        // [THEN] The bidirectional change and its fields are reported
        Assert.IsTrue(FieldTransfer.WasBidirectionalFieldModified(), 'A bidirectional field changed.');
        FieldTransfer.GetConflictFields(SourceFieldNo, DestinationFieldNo);
        Assert.AreEqual(TempCustomer.FieldNo(Name), SourceFieldNo, 'Source field');
        Assert.AreEqual(TempCRMAccount.FieldNo(Name), DestinationFieldNo, 'Destination field');
    end;

    [Test]
    procedure ConstantValueIsWrittenWithoutSourceField()
    var
        TempCustomer: Record Customer temporary;
        TempCRMAccount: Record "CRM Account" temporary;
        FieldTransfer: Codeunit "DVI Field Transfer";
        Context: Codeunit "DVI Sync Context";
        SourceRecordRef: RecordRef;
        DestinationRecordRef: RecordRef;
    begin
        // [GIVEN] A field mapping without a Business Central field and with a constant value
        CreateNameMapping(0, TempCRMAccount.FieldNo(Telephone1), 1);
        SourceRecordRef.GetTable(TempCustomer);
        DestinationRecordRef.GetTable(TempCRMAccount);

        // [WHEN] The fields are transferred to a new account
        FieldTransfer.LoadFieldMappings(GetMapping(), true);
        FieldTransfer.TransferFields(Context, SourceRecordRef, DestinationRecordRef, false);

        // [THEN] The account gets the constant
        Assert.AreEqual('+381 11 000 000', Format(DestinationRecordRef.Field(TempCRMAccount.FieldNo(Telephone1)).Value()), 'Constant value');
    end;

    local procedure CreateNameMapping(FieldNo: Integer; IntegrationFieldNo: Integer; Kind: Integer)
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
    begin
        TestLibrary.CreateDataverseMapping('DVITEST', Database::Customer, Database::"CRM Account", IntegrationTableMapping.Direction::Bidirectional);
        if Kind = 1 then
            TestLibrary.CreateFieldMapping('DVITEST', FieldNo, IntegrationFieldNo, IntegrationTableMapping.Direction::ToIntegrationTable, '+381 11 000 000')
        else
            TestLibrary.CreateFieldMapping('DVITEST', FieldNo, IntegrationFieldNo, IntegrationTableMapping.Direction::Bidirectional, '');
    end;

    local procedure GetMapping() IntegrationTableMapping: Record "Integration Table Mapping"
    begin
        IntegrationTableMapping.Get('DVITEST');
    end;
}
