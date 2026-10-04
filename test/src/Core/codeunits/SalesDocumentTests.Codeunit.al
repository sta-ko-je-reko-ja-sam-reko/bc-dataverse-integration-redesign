namespace DataverseIntegration.Test;

using DataverseIntegration.Core;
using DataverseIntegration.CRM;
using Microsoft.Integration.D365Sales;
using Microsoft.Integration.SyncEngine;
using Microsoft.Sales.Document;
using Microsoft.Sales.History;
using Microsoft.Sales.Setup;
using System.TestLibraries.Utilities;

codeunit 84020 "DVI Sales Document Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLibrary: Codeunit "DVI Test Library";

    [Test]
    procedure SwitchingPicksTheHandlerOfEachSalesDocumentPair()
    begin
        // [GIVEN] / [WHEN] Mappings of sales orders, their lines, posted invoices and their lines are switched
        // [THEN] Each gets its handler and the Sales module
        AssertSwitchedHandler('DVISO', Database::"Sales Header", Database::"CRM Salesorder", Enum::"DVI Sync Handler"::DVICRMSalesOrder);
        AssertSwitchedHandler('DVISOL', Database::"Sales Line", Database::"CRM Salesorderdetail", Enum::"DVI Sync Handler"::DVICRMSalesOrderLine);
        AssertSwitchedHandler('DVIINV', Database::"Sales Invoice Header", Database::"CRM Invoice", Enum::"DVI Sync Handler"::DVICRMInvoice);
        AssertSwitchedHandler('DVIINVL', Database::"Sales Invoice Line", Database::"CRM Invoicedetail", Enum::"DVI Sync Handler"::DVICRMInvoiceLine);
    end;

    [Test]
    procedure LineProductFieldGetsTheWriteInConverter()
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        SalesLine: Record "Sales Line";
        CRMSalesorderdetail: Record "CRM Salesorderdetail";
        FieldConverter: Record "DVI Field Converter";
        DefaultAssignment: Codeunit "DVI Default Assignment";
    begin
        // [GIVEN] An order line mapping with the field mapping No. - ProductId
        IntegrationTableMapping := TestLibrary.CreateDataverseMapping('DVISOL2', Database::"Sales Line", Database::"CRM Salesorderdetail", IntegrationTableMapping.Direction::Bidirectional);
        TestLibrary.CreateFieldMapping('DVISOL2', SalesLine.FieldNo("No."), CRMSalesorderdetail.FieldNo(ProductId), IntegrationTableMapping.Direction::Bidirectional, '');

        // [WHEN] The mapping is switched
        DefaultAssignment.SwitchToRedesigned(IntegrationTableMapping);

        // [THEN] The field gets the write-in product converter
        FieldConverter.Get('DVISOL2', SalesLine.FieldNo("No."), CRMSalesorderdetail.FieldNo(ProductId));
        Assert.AreEqual(Enum::"DVI Value Converter"::DVIWriteInProduct, FieldConverter.Converter, 'Converter');
    end;

    [Test]
    procedure WriteInProductIsSentWithoutProduct()
    var
        TempSalesLine: Record "Sales Line" temporary;
        TempCRMSalesorderdetail: Record "CRM Salesorderdetail" temporary;
        WriteInProductConverter: Codeunit "DVI Write-in Product Converter";
        Context: Codeunit "DVI Sync Context";
        SalesLineRecordRef: RecordRef;
        DetailRecordRef: RecordRef;
        SourceFieldRef: FieldRef;
        DestinationFieldRef: FieldRef;
        NewValue: Variant;
        ProductId: Guid;
        NeedsConversion: Boolean;
    begin
        // [GIVEN] A sales line for the write-in product
        SetWriteInProduct('DVIWRITEIN');
        TempSalesLine.Type := TempSalesLine.Type::Item;
        TempSalesLine."No." := 'DVIWRITEIN';
        SalesLineRecordRef.GetTable(TempSalesLine);
        DetailRecordRef.GetTable(TempCRMSalesorderdetail);
        SourceFieldRef := SalesLineRecordRef.Field(TempSalesLine.FieldNo("No."));
        DestinationFieldRef := DetailRecordRef.Field(TempCRMSalesorderdetail.FieldNo(ProductId));

        // [WHEN] The line's number is converted for Dataverse
        Assert.IsTrue(WriteInProductConverter.Convert(Context, SourceFieldRef, DestinationFieldRef, NewValue, NeedsConversion), 'The converter must produce the value.');

        // [THEN] The Dataverse line has no product
        ProductId := NewValue;
        Assert.IsTrue(IsNullGuid(ProductId), 'A write-in line has no product.');
    end;

    [Test]
    procedure DataverseLineWithoutProductGetsTheWriteInProduct()
    var
        TempSalesLine: Record "Sales Line" temporary;
        TempCRMSalesorderdetail: Record "CRM Salesorderdetail" temporary;
        WriteInProductConverter: Codeunit "DVI Write-in Product Converter";
        Context: Codeunit "DVI Sync Context";
        SalesLineRecordRef: RecordRef;
        DetailRecordRef: RecordRef;
        SourceFieldRef: FieldRef;
        DestinationFieldRef: FieldRef;
        NewValue: Variant;
        NeedsConversion: Boolean;
    begin
        // [GIVEN] A Dataverse order line without product
        SetWriteInProduct('DVIWRITEIN');
        DetailRecordRef.GetTable(TempCRMSalesorderdetail);
        SalesLineRecordRef.GetTable(TempSalesLine);
        SourceFieldRef := DetailRecordRef.Field(TempCRMSalesorderdetail.FieldNo(ProductId));
        DestinationFieldRef := SalesLineRecordRef.Field(TempSalesLine.FieldNo("No."));

        // [WHEN] The product is converted for Business Central
        Assert.IsTrue(WriteInProductConverter.Convert(Context, SourceFieldRef, DestinationFieldRef, NewValue, NeedsConversion), 'The converter must produce the value.');

        // [THEN] The sales line gets the write-in product
        Assert.AreEqual('DVIWRITEIN', Format(NewValue), 'No.');
    end;

    [Test]
    procedure OrderIsFullyInvoicedOnlyWhenNothingIsOutstanding()
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        CRMSalesOrders: Codeunit "DVI CRM Sales Orders";
    begin
        // [GIVEN] An order with one line, nothing invoiced
        SalesHeader."Document Type" := SalesHeader."Document Type"::Order;
        SalesHeader."No." := 'DVISO1';
        SalesLine."Document Type" := SalesLine."Document Type"::Order;
        SalesLine."Document No." := 'DVISO1';
        SalesLine."Line No." := 10000;
        SalesLine."Outstanding Quantity" := 5;
        SalesLine.Insert(false);

        // [WHEN] / [THEN] It is not invoiced
        Assert.IsFalse(CRMSalesOrders.IsFullyInvoiced(SalesHeader), 'Nothing is invoiced yet.');

        // [GIVEN] Part of it invoiced, part outstanding
        SalesLine."Quantity Invoiced" := 2;
        SalesLine."Outstanding Quantity" := 3;
        SalesLine.Modify(false);
        Assert.IsFalse(CRMSalesOrders.IsFullyInvoiced(SalesHeader), 'Quantities are still outstanding.');

        // [GIVEN] Everything shipped and invoiced
        SalesLine."Quantity Invoiced" := 5;
        SalesLine."Outstanding Quantity" := 0;
        SalesLine."Qty. Shipped Not Invoiced" := 0;
        SalesLine.Modify(false);
        Assert.IsTrue(CRMSalesOrders.IsFullyInvoiced(SalesHeader), 'Everything is invoiced.');
    end;

    [Test]
    procedure RoundingDifferenceIsWhatTheDataverseLineMisses()
    var
        CRMInvoices: Codeunit "DVI CRM Invoices";
    begin
        // [GIVEN] / [WHEN] / [THEN] A Dataverse line that matches has no difference; one that is a cent short has one cent
        Assert.AreEqual(0, CRMInvoices.RoundingDifference(121, 100, 1, 21, 0), 'Matching line');
        Assert.AreEqual(0.01, CRMInvoices.RoundingDifference(121.01, 100, 1, 21, 0), 'Line one cent short');
        Assert.AreEqual(0, CRMInvoices.RoundingDifference(108.9, 50, 2, 18.9, 10), 'Line with discount');
    end;

    [Test]
    procedure LinesOfAnUncoupledInvoiceWaitForTheirInvoice()
    var
        SalesInvoiceHeader: Record "Sales Invoice Header";
        SalesInvoiceLine: Record "Sales Invoice Line";
        InvoiceLineHandler: Codeunit "DVI Invoice Line Handler";
        Context: Codeunit "DVI Sync Context";
        LineRecordRef: RecordRef;
    begin
        // [GIVEN] A posted invoice that is not coupled, with a line
        SalesInvoiceHeader."No." := 'DVIINV1';
        SalesInvoiceHeader.Insert(false);
        SalesInvoiceLine."Document No." := 'DVIINV1';
        SalesInvoiceLine."Line No." := 10000;
        SalesInvoiceLine.Insert(false);
        LineRecordRef.GetTable(SalesInvoiceLine);

        // [WHEN] / [THEN] The scheduled synchronization leaves the line for its invoice
        Assert.IsTrue(InvoiceLineHandler.IgnoreRecord(Context, LineRecordRef), 'The line is sent with its invoice.');
    end;

    [Test]
    procedure CompletionIsQueuedOncePerRecord()
    var
        TempFollowUpBuffer: Record "DVI Follow-up Buffer" temporary;
        Context: Codeunit "DVI Sync Context";
        OrderId: Guid;
    begin
        // [GIVEN] An order that queues a line and its completion twice
        OrderId := CreateGuid();
        Context.AddFollowUp('SALESLINES', CreateGuid(), true);
        Context.AddCompletion('SALESORDERS', OrderId, true, Enum::"DVI Synch Action"::DVIModify);
        Context.AddCompletion('SALESORDERS', OrderId, true, Enum::"DVI Synch Action"::DVIModify);

        // [WHEN] The follow-ups are taken
        Context.GetFollowUps(TempFollowUpBuffer);

        // [THEN] There is one completion, after the line, with the action
        Assert.RecordCount(TempFollowUpBuffer, 2);
        TempFollowUpBuffer.SetRange(Completion, true);
        Assert.RecordCount(TempFollowUpBuffer, 1);
        TempFollowUpBuffer.FindFirst();
        Assert.AreEqual(OrderId, TempFollowUpBuffer."Source System Id", 'Completion record');
        Assert.AreEqual(Enum::"DVI Synch Action"::DVIModify, TempFollowUpBuffer."Synch Action", 'Completion action');
        Assert.AreEqual(2, TempFollowUpBuffer."Entry No.", 'The completion comes after the line.');
    end;

    [Test]
    procedure CompletionIsDroppedWhenItsRecordFails()
    var
        TempFollowUpBuffer: Record "DVI Follow-up Buffer" temporary;
        Context: Codeunit "DVI Sync Context";
    begin
        // [GIVEN] A completion and a prerequisite queued by a record that then fails
        Context.AddCompletion('SALESORDERS', CreateGuid(), true, Enum::"DVI Synch Action"::DVIInsert);
        Context.AddPrerequisite('CUSTOMERS', CreateGuid(), true);

        // [WHEN] The failure is handled
        Context.DropFollowUpsAfterFailure();

        // [THEN] Only the prerequisite is left
        Context.GetFollowUps(TempFollowUpBuffer);
        Assert.RecordCount(TempFollowUpBuffer, 1);
        TempFollowUpBuffer.FindFirst();
        Assert.IsFalse(TempFollowUpBuffer.Completion, 'The completion must be dropped.');
    end;

    local procedure SetWriteInProduct(No: Code[20])
    var
        SalesReceivablesSetup: Record "Sales & Receivables Setup";
    begin
        if not SalesReceivablesSetup.Get() then begin
            SalesReceivablesSetup.Init();
            SalesReceivablesSetup.Insert(false);
        end;
        SalesReceivablesSetup."Write-in Product No." := No;
        SalesReceivablesSetup.Modify(false);
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
        Assert.AreEqual(Enum::"DVI Integration Module"::DVISales, MappingAssignment.Module, MappingName);
    end;
}
