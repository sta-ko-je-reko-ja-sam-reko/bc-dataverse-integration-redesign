namespace DataverseIntegration.CRM;

using DataverseIntegration.CDS;
using DataverseIntegration.Core;
using Microsoft.Finance.ReceivablesPayables;
using Microsoft.Integration.D365Sales;
using Microsoft.Integration.Dataverse;
using Microsoft.Integration.SyncEngine;
using Microsoft.Pricing.Calculation;
using Microsoft.Sales.Archive;
using Microsoft.Sales.Document;
using Microsoft.Sales.Setup;
using Microsoft.Utilities;
using System.Environment.Configuration;
using System.Utilities;

codeunit 80414 "DVI CRM Sales Orders"
{
    Access = Internal;

    var
        OrderPriceListLbl: Label 'Business Central Order %1 Price List', Locked = true, Comment = '%1 = order number';
        SalesHeaderNotCoupledErr: Label 'The sales order %1 is not coupled to a Dataverse sales order.', Comment = '%1 = order number';
        WriteInProductErr: Label 'The Dataverse order line has a write-in product. Choose the write-in product in Sales & Receivables Setup.';

    /// <summary>
    /// Returns whether sales orders are synchronized in both directions.
    /// </summary>
    /// <returns>True when bidirectional sales order integration is enabled.</returns>
    internal procedure IsBidirectional(): Boolean
    var
        CRMConnectionSetup: Record "CRM Connection Setup";
    begin
        exit(CRMConnectionSetup.IsBidirectionalSalesOrderIntEnabled());
    end;

    /// <summary>
    /// Returns whether a sales order or Dataverse order belongs to an archived order, which bidirectional synchronization leaves alone.
    /// </summary>
    /// <param name="SourceRecordRef">The sales header or the Dataverse order.</param>
    /// <returns>True when the coupling is marked as archived and synchronization is bidirectional.</returns>
    internal procedure IsArchived(var SourceRecordRef: RecordRef): Boolean
    var
        CRMIntegrationRecord: Record "CRM Integration Record";
        CRMSalesorder: Record "CRM Salesorder";
    begin
        if not IsBidirectional() then
            exit(false);
        case SourceRecordRef.Number() of
            Database::"Sales Header":
                if not CRMIntegrationRecord.FindByRecordID(SourceRecordRef.RecordId()) then
                    exit(false);
            Database::"CRM Salesorder":
                begin
                    SourceRecordRef.SetTable(CRMSalesorder);
                    if not CRMIntegrationRecord.FindByCRMID(CRMSalesorder.SalesOrderId) then
                        exit(false);
                end;
            else
                exit(false);
        end;
        exit(CRMIntegrationRecord."Archived Sales Order");
    end;

    /// <summary>
    /// Points a Dataverse order at a price list that holds its products: the price list of its currency, or with extended pricing a price list of its own.
    /// </summary>
    /// <param name="SalesHeaderRecordRef">The sales order.</param>
    /// <param name="CRMSalesorderRecordRef">The Dataverse order, before it is inserted or modified.</param>
    internal procedure SetPriceList(var SalesHeaderRecordRef: RecordRef; var CRMSalesorderRecordRef: RecordRef)
    var
        SalesHeader: Record "Sales Header";
        CRMSalesorder: Record "CRM Salesorder";
        CRMPricelevel: Record "CRM Pricelevel";
        CRMSynchHelper: Codeunit "CRM Synch. Helper";
        PriceCalculationMgt: Codeunit "Price Calculation Mgt.";
    begin
        SalesHeaderRecordRef.SetTable(SalesHeader);
        CRMSalesorderRecordRef.SetTable(CRMSalesorder);
        if not IsNullGuid(CRMSalesorder.PriceLevelId) then begin
            CRMSynchHelper.UpdateCRMPriceList(SalesHeader, CRMSalesorder.PriceLevelId);
            exit;
        end;
        if PriceCalculationMgt.IsExtendedPriceCalculationEnabled() then begin
            CRMPricelevel.SetRange(Name, StrSubstNo(OrderPriceListLbl, SalesHeader."No."));
            if CRMPricelevel.FindFirst() then
                CRMSynchHelper.UpdateCRMPriceList(SalesHeader, CRMPricelevel.PriceLevelId)
            else
                CRMSynchHelper.CreateCRMPriceList(SalesHeader, CRMPricelevel);
        end else begin
            if not CRMSynchHelper.FindCRMPriceListByCurrencyCode(CRMPricelevel, SalesHeader."Currency Code") then
                CRMSynchHelper.CreateCRMPricelevelInCurrency(CRMPricelevel, SalesHeader."Currency Code", SalesHeader."Currency Factor");
            CRMSynchHelper.UpdateCRMPriceList(SalesHeader, CRMPricelevel.PriceLevelId);
        end;
        CRMSalesorder.PriceLevelId := CRMPricelevel.PriceLevelId;
        CRMSalesorderRecordRef.GetTable(CRMSalesorder);
    end;

    /// <summary>
    /// Names a new Dataverse order after the customer and stamps the occurrence of the Business Central order number.
    /// </summary>
    /// <param name="SalesHeaderRecordRef">The sales order.</param>
    /// <param name="CRMSalesorderRecordRef">The new Dataverse order.</param>
    internal procedure SetNameAndOccurrence(var SalesHeaderRecordRef: RecordRef; var CRMSalesorderRecordRef: RecordRef)
    var
        SalesHeader: Record "Sales Header";
        CRMSalesorder: Record "CRM Salesorder";
    begin
        SalesHeaderRecordRef.SetTable(SalesHeader);
        CRMSalesorderRecordRef.SetTable(CRMSalesorder);
        CRMSalesorder.Name := SalesHeader."Sell-to Customer Name";
        SetOccurrence(CRMSalesorder, SalesHeader);
        CRMSalesorderRecordRef.GetTable(CRMSalesorder);
    end;

    /// <summary>
    /// Links a sales order created from a Dataverse order to the sales quote of the Dataverse quote it came from, and archives that quote.
    /// </summary>
    /// <param name="CRMSalesorderRecordRef">The Dataverse order.</param>
    /// <param name="SalesHeaderRecordRef">The new sales order.</param>
    internal procedure SetQuoteNo(var CRMSalesorderRecordRef: RecordRef; var SalesHeaderRecordRef: RecordRef)
    var
        CRMSalesorder: Record "CRM Salesorder";
        CRMQuote: Record "CRM Quote";
        SalesHeader: Record "Sales Header";
        QuoteSalesHeader: Record "Sales Header";
        ArchiveManagement: Codeunit ArchiveManagement;
    begin
        CRMSalesorderRecordRef.SetTable(CRMSalesorder);
        if IsNullGuid(CRMSalesorder.QuoteId) then
            exit;
        if not CRMQuote.Get(CRMSalesorder.QuoteId) then
            exit;
        QuoteSalesHeader.SetRange("Your Reference", CRMQuote.QuoteNumber);
        if not QuoteSalesHeader.FindLast() then
            exit;
        SalesHeaderRecordRef.SetTable(SalesHeader);
        SalesHeader."Quote No." := QuoteSalesHeader."No.";
        SalesHeaderRecordRef.GetTable(SalesHeader);
        ArchiveManagement.ArchSalesDocumentNoConfirm(QuoteSalesHeader);
    end;

    /// <summary>
    /// Removes Dataverse order lines whose sales line was deleted, and queues the order's sales lines for synchronization after the order.
    /// </summary>
    /// <param name="Context">The synchronization context, used to queue the lines.</param>
    /// <param name="SalesHeaderRecordRef">The sales order.</param>
    /// <param name="CRMSalesorderRecordRef">The Dataverse order.</param>
    internal procedure QueueLinesToDataverse(var Context: Codeunit "DVI Sync Context"; var SalesHeaderRecordRef: RecordRef; var CRMSalesorderRecordRef: RecordRef)
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        CRMSalesorder: Record "CRM Salesorder";
        CRMSalesorderdetail: Record "CRM Salesorderdetail";
        OrphanCRMSalesorderdetail: Record "CRM Salesorderdetail";
        CRMIntegrationRecord: Record "CRM Integration Record";
        LineMapping: Record "Integration Table Mapping";
        CDSRelations: Codeunit "DVI CDS Relations";
    begin
        SalesHeaderRecordRef.SetTable(SalesHeader);
        CRMSalesorderRecordRef.SetTable(CRMSalesorder);
        CRMSalesorderdetail.SetRange(SalesOrderId, CRMSalesorder.SalesOrderId);
        if CRMSalesorderdetail.FindSet() then
            repeat
                CRMIntegrationRecord.SetRange("CRM ID", CRMSalesorderdetail.SalesOrderDetailId);
                CRMIntegrationRecord.SetRange("Table ID", Database::"Sales Line");
                if CRMIntegrationRecord.FindFirst() then begin
                    SalesLine.SetRange(SystemId, CRMIntegrationRecord."Integration ID");
                    if SalesLine.IsEmpty() then begin
                        CRMIntegrationRecord.Delete();
                        if OrphanCRMSalesorderdetail.Get(CRMSalesorderdetail.SalesOrderDetailId) then
                            OrphanCRMSalesorderdetail.Delete();
                    end;
                end;
            until CRMSalesorderdetail.Next() = 0;
        if not CDSRelations.FindMapping(Database::"Sales Line", Database::"CRM Salesorderdetail", LineMapping) then
            exit;
        SalesLine.Reset();
        SalesLine.SetView(LineMapping.GetTableFilter());
        SalesLine.SetRange("Document Type", SalesLine."Document Type"::Order);
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.SetLoadFields(SystemId);
        if SalesLine.FindSet() then
            repeat
                Context.AddFollowUp(LineMapping.Name, SalesLine.SystemId, true);
            until SalesLine.Next() = 0;
    end;

    /// <summary>
    /// Removes sales lines whose Dataverse order line was deleted, and queues the order's Dataverse lines for products of type sales inventory or services, and write-in lines, for synchronization after the order.
    /// </summary>
    /// <param name="Context">The synchronization context, used to queue the lines.</param>
    /// <param name="CRMSalesorderRecordRef">The Dataverse order.</param>
    /// <param name="SalesHeaderRecordRef">The sales order.</param>
    internal procedure QueueLinesFromDataverse(var Context: Codeunit "DVI Sync Context"; var CRMSalesorderRecordRef: RecordRef; var SalesHeaderRecordRef: RecordRef)
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        DeletedSalesLine: Record "Sales Line";
        CRMSalesorder: Record "CRM Salesorder";
        CRMSalesorderdetail: Record "CRM Salesorderdetail";
        CRMProduct: Record "CRM Product";
        CRMIntegrationRecord: Record "CRM Integration Record";
        LineMapping: Record "Integration Table Mapping";
        CDSRelations: Codeunit "DVI CDS Relations";
    begin
        CRMSalesorderRecordRef.SetTable(CRMSalesorder);
        SalesHeaderRecordRef.SetTable(SalesHeader);
        SalesLine.SetRange("Document Type", SalesLine."Document Type"::Order);
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        if SalesLine.FindSet() then
            repeat
                CRMIntegrationRecord.SetRange("Integration ID", SalesLine.SystemId);
                CRMIntegrationRecord.SetRange("Table ID", Database::"Sales Line");
                if CRMIntegrationRecord.FindFirst() then begin
                    CRMSalesorderdetail.SetRange(SalesOrderDetailId, CRMIntegrationRecord."CRM ID");
                    if CRMSalesorderdetail.IsEmpty() then begin
                        CRMIntegrationRecord.Delete();
                        if DeletedSalesLine.GetBySystemId(SalesLine.SystemId) then
                            DeletedSalesLine.Delete(true);
                    end;
                end;
            until SalesLine.Next() = 0;
        if not CDSRelations.FindMapping(Database::"Sales Line", Database::"CRM Salesorderdetail", LineMapping) then
            exit;
        CRMSalesorderdetail.Reset();
        CRMSalesorderdetail.SetView(LineMapping.GetIntegrationTableFilter());
        CRMSalesorderdetail.SetRange(SalesOrderId, CRMSalesorder.SalesOrderId);
        if CRMSalesorderdetail.FindSet() then
            repeat
                if IsNullGuid(CRMSalesorderdetail.ProductId) then
                    Context.AddFollowUp(LineMapping.Name, CRMSalesorderdetail.SalesOrderDetailId, false)
                else
                    if CRMProduct.Get(CRMSalesorderdetail.ProductId) then
                        if CRMProduct.ProductTypeCode in [CRMProduct.ProductTypeCode::SalesInventory, CRMProduct.ProductTypeCode::Services] then
                            Context.AddFollowUp(LineMapping.Name, CRMSalesorderdetail.SalesOrderDetailId, false);
            until CRMSalesorderdetail.Next() = 0;
    end;

    /// <summary>
    /// Finishes a Dataverse order after its lines were sent: the line discount total, and, after an insert or modify, the Submitted state unless the order is completely shipped.
    /// </summary>
    /// <param name="Context">The synchronization context of the completion step.</param>
    /// <param name="SalesHeaderRecordRef">The sales order.</param>
    /// <param name="CRMSalesorderRecordRef">The Dataverse order.</param>
    internal procedure CompleteInDataverse(var Context: Codeunit "DVI Sync Context"; var SalesHeaderRecordRef: RecordRef; var CRMSalesorderRecordRef: RecordRef)
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        CRMSalesorder: Record "CRM Salesorder";
        LineMapping: Record "Integration Table Mapping";
        CDSRelations: Codeunit "DVI CDS Relations";
    begin
        SalesHeaderRecordRef.SetTable(SalesHeader);
        CRMSalesorderRecordRef.SetTable(CRMSalesorder);
        if CDSRelations.FindMapping(Database::"Sales Line", Database::"CRM Salesorderdetail", LineMapping) then begin
            SalesLine.SetView(LineMapping.GetTableFilter());
            SalesLine.SetRange("Document Type", SalesLine."Document Type"::Order);
            SalesLine.SetRange("Document No.", SalesHeader."No.");
            if not SalesLine.IsEmpty() then begin
                SalesLine.CalcSums("Line Discount Amount");
                if CRMSalesorder.Get(CRMSalesorder.SalesOrderId) then
                    if CRMSalesorder.TotalLineItemDiscountAmount <> SalesLine."Line Discount Amount" then begin
                        CRMSalesorder.TotalLineItemDiscountAmount := SalesLine."Line Discount Amount";
                        CRMSalesorder.Modify();
                    end;
            end;
        end;
        if not (Context.GetSynchAction() in [Enum::"DVI Synch Action"::DVIInsert, Enum::"DVI Synch Action"::DVIModify, Enum::"DVI Synch Action"::DVIForceModify]) then
            exit;
        SalesHeader.CalcFields("Completely Shipped");
        if not SalesHeader."Completely Shipped" then
            ChangeState(CRMSalesorder.SalesOrderId, CRMSalesorder.StateCode::Submitted);
    end;

    /// <summary>
    /// Finishes a sales order after its lines were received: order discount, freight line, release, the order number on the Dataverse order (new orders only) and notes.
    /// </summary>
    /// <param name="Context">The synchronization context of the completion step.</param>
    /// <param name="CRMSalesorderRecordRef">The Dataverse order.</param>
    /// <param name="SalesHeaderRecordRef">The sales order.</param>
    internal procedure CompleteInBusinessCentral(var Context: Codeunit "DVI Sync Context"; var CRMSalesorderRecordRef: RecordRef; var SalesHeaderRecordRef: RecordRef)
    var
        SalesHeader: Record "Sales Header";
        CRMSalesorder: Record "CRM Salesorder";
        SynchAction: Enum "DVI Synch Action";
    begin
        CRMSalesorderRecordRef.SetTable(CRMSalesorder);
        SalesHeaderRecordRef.SetTable(SalesHeader);
        SalesHeader.Get(SalesHeader."Document Type", SalesHeader."No.");
        SynchAction := Context.GetSynchAction();
        if SynchAction <> SynchAction::DVIIgnoreUnchanged then
            ApplyDiscount(CRMSalesorder, SalesHeader);
        CreateFreightLine(CRMSalesorder, SalesHeader);
        Release(SalesHeader);
        if SynchAction = SynchAction::DVIInsert then
            SetOrderNumberInDataverse(CRMSalesorder, SalesHeader);
        CreateNotes(CRMSalesorder, SalesHeader);
    end;

    /// <summary>
    /// Reopens a released sales order so its lines can be updated from Dataverse.
    /// </summary>
    /// <param name="SalesHeaderRecordRef">The sales order.</param>
    internal procedure Reopen(var SalesHeaderRecordRef: RecordRef)
    var
        SalesHeader: Record "Sales Header";
    begin
        if not SalesHeader.GetBySystemId(SalesHeaderRecordRef.Field(SalesHeaderRecordRef.SystemIdNo()).Value()) then
            exit;
        if SalesHeader.Status = SalesHeader.Status::Open then
            exit;
        SalesHeader.Status := SalesHeader.Status::Open;
        SalesHeader.Modify(false);
        SalesHeaderRecordRef.GetTable(SalesHeader);
    end;

    /// <summary>
    /// Sets a Dataverse order's state, used when orders go only to Dataverse: Active before an update, then Invoiced or Submitted.
    /// </summary>
    /// <param name="SalesHeaderRecordRef">The sales order, or a closed RecordRef to set Active.</param>
    /// <param name="CRMSalesorderRecordRef">The Dataverse order.</param>
    /// <param name="Activate">True to set the order Active; false to set Invoiced or Submitted.</param>
    internal procedure SetOneWayState(var SalesHeaderRecordRef: RecordRef; var CRMSalesorderRecordRef: RecordRef; Activate: Boolean)
    var
        SalesHeader: Record "Sales Header";
        CRMSalesorder: Record "CRM Salesorder";
    begin
        CRMSalesorderRecordRef.SetTable(CRMSalesorder);
        if Activate then begin
            ChangeState(CRMSalesorder.SalesOrderId, CRMSalesorder.StateCode::Active);
            exit;
        end;
        SalesHeaderRecordRef.SetTable(SalesHeader);
        if IsFullyInvoiced(SalesHeader) then
            ChangeState(CRMSalesorder.SalesOrderId, CRMSalesorder.StateCode::Invoiced)
        else
            ChangeState(CRMSalesorder.SalesOrderId, CRMSalesorder.StateCode::Submitted);
    end;

    /// <summary>
    /// Sets the Dataverse order of a sales line, before the line is sent.
    /// </summary>
    /// <param name="SalesLineRecordRef">The sales line.</param>
    /// <param name="CRMSalesorderdetailRecordRef">The Dataverse order line.</param>
    internal procedure SetOrderOfLine(var SalesLineRecordRef: RecordRef; var CRMSalesorderdetailRecordRef: RecordRef)
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        CRMSalesorderdetail: Record "CRM Salesorderdetail";
        CRMIntegrationRecord: Record "CRM Integration Record";
        CRMSalesorderId: Guid;
    begin
        SalesLineRecordRef.SetTable(SalesLine);
        CRMSalesorderdetailRecordRef.SetTable(CRMSalesorderdetail);
        SalesHeader.Get(SalesHeader."Document Type"::Order, SalesLine."Document No.");
        if not CRMIntegrationRecord.FindIDFromRecordID(SalesHeader.RecordId(), CRMSalesorderId) then
            Error(SalesHeaderNotCoupledErr, SalesHeader."No.");
        CRMSalesorderdetail.SalesOrderId := CRMSalesorderId;
        CRMSalesorderdetailRecordRef.GetTable(CRMSalesorderdetail);
    end;

    /// <summary>
    /// Sets the sales order and the line type of a sales line created from a Dataverse order line.
    /// </summary>
    /// <param name="CRMSalesorderdetailRecordRef">The Dataverse order line.</param>
    /// <param name="SalesLineRecordRef">The new sales line.</param>
    internal procedure SetOrderAndTypeOfLine(var CRMSalesorderdetailRecordRef: RecordRef; var SalesLineRecordRef: RecordRef)
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        CRMSalesorderdetail: Record "CRM Salesorderdetail";
        CRMProduct: Record "CRM Product";
        SalesReceivablesSetup: Record "Sales & Receivables Setup";
        CRMIntegrationRecord: Record "CRM Integration Record";
        SalesOrderRecordId: RecordId;
    begin
        CRMSalesorderdetailRecordRef.SetTable(CRMSalesorderdetail);
        SalesLineRecordRef.SetTable(SalesLine);
        if not CRMIntegrationRecord.FindRecordIDFromID(CRMSalesorderdetail.SalesOrderId, Database::"Sales Header", SalesOrderRecordId) then
            Error(SalesHeaderNotCoupledErr, CRMSalesorderdetail.SalesOrderId);
        SalesHeader.Get(SalesOrderRecordId);
        SalesLine."Document Type" := SalesLine."Document Type"::Order;
        SalesLine."Document No." := SalesHeader."No.";
        if IsNullGuid(CRMSalesorderdetail.ProductId) then begin
            SalesReceivablesSetup.Get();
            if SalesReceivablesSetup."Write-in Product No." = '' then
                Error(WriteInProductErr);
            case SalesReceivablesSetup."Write-in Product Type" of
                SalesReceivablesSetup."Write-in Product Type"::Item:
                    SalesLine.Type := SalesLine.Type::Item;
                SalesReceivablesSetup."Write-in Product Type"::Resource:
                    SalesLine.Type := SalesLine.Type::Resource;
            end;
        end else begin
            CRMProduct.Get(CRMSalesorderdetail.ProductId);
            case CRMProduct.ProductTypeCode of
                CRMProduct.ProductTypeCode::SalesInventory:
                    SalesLine.Type := SalesLine.Type::Item;
                CRMProduct.ProductTypeCode::Services:
                    SalesLine.Type := SalesLine.Type::Resource;
            end;
        end;
        SalesLineRecordRef.GetTable(SalesLine);
    end;

    /// <summary>
    /// Returns whether every line of a sales order is invoiced.
    /// </summary>
    /// <param name="SalesHeader">The sales order.</param>
    /// <returns>True when something was invoiced and nothing is outstanding or shipped but not invoiced.</returns>
    internal procedure IsFullyInvoiced(SalesHeader: Record "Sales Header"): Boolean
    var
        SalesLine: Record "Sales Line";
    begin
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        SalesLine.SetFilter("Quantity Invoiced", '<>0');
        if SalesLine.IsEmpty() then
            exit(false);
        SalesLine.SetRange("Quantity Invoiced");
        SalesLine.SetFilter("Outstanding Quantity", '<>0');
        if not SalesLine.IsEmpty() then
            exit(false);
        SalesLine.SetRange("Outstanding Quantity");
        SalesLine.SetFilter("Qty. Shipped Not Invoiced", '<>0');
        exit(SalesLine.IsEmpty());
    end;

    local procedure ChangeState(SalesOrderId: Guid; NewStateCode: Option)
    var
        CRMSalesorder: Record "CRM Salesorder";
        CRMIntegrationManagement: Codeunit "CRM Integration Management";
    begin
        if not CRMIntegrationManagement.IsCRMIntegrationEnabled() then
            exit;
        if not CRMSalesorder.Get(SalesOrderId) then
            exit;
        if CRMSalesorder.StateCode = NewStateCode then
            exit;
        CRMSalesorder.StateCode := NewStateCode;
        CRMSalesorder.Modify();
    end;

    local procedure ApplyDiscount(CRMSalesorder: Record "CRM Salesorder"; var SalesHeader: Record "Sales Header")
    var
        SalesCalcDiscountByType: Codeunit "Sales - Calc Discount By Type";
    begin
        if (CRMSalesorder.DiscountAmount = 0) and (CRMSalesorder.DiscountPercentage = 0) then
            exit;
        SalesCalcDiscountByType.ApplyInvDiscBasedOnAmt(CRMSalesorder.TotalLineItemAmount - CRMSalesorder.TotalAmountLessFreight, SalesHeader);
        SalesHeader.Get(SalesHeader."Document Type", SalesHeader."No.");
    end;

    local procedure CreateFreightLine(CRMSalesorder: Record "CRM Salesorder"; SalesHeader: Record "Sales Header")
    var
        SalesReceivablesSetup: Record "Sales & Receivables Setup";
        SalesLine: Record "Sales Line";
        FreightAmount: Decimal;
    begin
        SalesReceivablesSetup.SetLoadFields("Freight G/L Acc. No.");
        SalesReceivablesSetup.Get();
        if SalesReceivablesSetup."Freight G/L Acc. No." <> '' then begin
            SalesLine.SetRange("Document Type", SalesHeader."Document Type");
            SalesLine.SetRange("Document No.", SalesHeader."No.");
            SalesLine.SetRange(Type, SalesLine.Type::"G/L Account");
            SalesLine.SetRange("No.", SalesReceivablesSetup."Freight G/L Acc. No.");
            SalesLine.SetRange("Unit Price", CRMSalesorder.FreightAmount);
            if not SalesLine.IsEmpty() then
                exit;
        end;
        SalesLine.Reset();
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");
        if not SalesLine.FindLast() then
            exit;
        FreightAmount := CRMSalesorder.FreightAmount;
        SalesLine.InsertFreightLine(FreightAmount);
    end;

    local procedure Release(var SalesHeader: Record "Sales Header")
    var
        PrepaymentMgt: Codeunit "Prepayment Mgt.";
        ReleaseSalesDocument: Codeunit "Release Sales Document";
    begin
        SalesHeader.Get(SalesHeader."Document Type", SalesHeader."No.");
        if PrepaymentMgt.TestSalesPrepayment(SalesHeader) then begin
            if SalesHeader.Status <> SalesHeader.Status::Open then
                ReleaseSalesDocument.PerformManualReopen(SalesHeader);
            exit;
        end;
        if SalesHeader.Status <> SalesHeader.Status::Released then
            ReleaseSalesDocument.PerformManualRelease(SalesHeader);
    end;

    local procedure SetOrderNumberInDataverse(CRMSalesorder: Record "CRM Salesorder"; SalesHeader: Record "Sales Header")
    var
        ChangedCRMSalesorder: Record "CRM Salesorder";
    begin
        if not ChangedCRMSalesorder.Get(CRMSalesorder.SalesOrderId) then
            exit;
        SetOccurrence(ChangedCRMSalesorder, SalesHeader);
        ChangedCRMSalesorder.BusinessCentralOrderNumber := SalesHeader."No.";
        ChangedCRMSalesorder.Modify();
    end;

    local procedure SetOccurrence(var CRMSalesorder: Record "CRM Salesorder"; SalesHeader: Record "Sales Header")
    var
        SalesHeaderArchive: Record "Sales Header Archive";
    begin
        SalesHeaderArchive.SetRange("Document Type", SalesHeaderArchive."Document Type"::Order);
        SalesHeaderArchive.SetRange("No.", SalesHeader."No.");
        SalesHeaderArchive.SetCurrentKey("Doc. No. Occurrence");
        if not SalesHeaderArchive.FindLast() then begin
            CRMSalesorder.BusinessCentralDocumentOccurrenceNumber := 1;
            exit;
        end;
        if SalesHeaderArchive."Document Date" = SalesHeader."Document Date" then
            CRMSalesorder.BusinessCentralDocumentOccurrenceNumber := SalesHeaderArchive."Doc. No. Occurrence"
        else
            CRMSalesorder.BusinessCentralDocumentOccurrenceNumber := SalesHeaderArchive."Doc. No. Occurrence" + 1;
    end;

    local procedure CreateNotes(CRMSalesorder: Record "CRM Salesorder"; SalesHeader: Record "Sales Header")
    var
        CRMAnnotation: Record "CRM Annotation";
        CRMAnnotationCoupling: Record "CRM Annotation Coupling";
        RecordLink: Record "Record Link";
        DeletedRecordLink: Record "Record Link";
    begin
        RecordLink.SetRange("Record ID", SalesHeader.RecordId());
        if RecordLink.FindSet() then
            repeat
                CRMAnnotationCoupling.SetRange("Record Link Record ID", RecordLink.RecordId());
                if CRMAnnotationCoupling.FindFirst() then begin
                    CRMAnnotation.SetRange(AnnotationId, CRMAnnotationCoupling."CRM Annotation ID");
                    if CRMAnnotation.IsEmpty() then begin
                        CRMAnnotationCoupling.Delete();
                        if DeletedRecordLink.GetBySystemId(RecordLink.SystemId) then
                            DeletedRecordLink.Delete();
                    end;
                end;
            until RecordLink.Next() = 0;
        CRMAnnotation.Reset();
        CRMAnnotation.SetRange(ObjectId, CRMSalesorder.SalesOrderId);
        CRMAnnotation.SetRange(IsDocument, false);
        CRMAnnotation.SetRange(FileSize, 0);
        if CRMAnnotation.FindSet() then
            repeat
                CRMAnnotationCoupling.Reset();
                CRMAnnotationCoupling.SetRange("CRM Annotation ID", CRMAnnotation.AnnotationId);
                if CRMAnnotationCoupling.IsEmpty() then
                    CreateNote(SalesHeader, CRMAnnotation);
            until CRMAnnotation.Next() = 0;
    end;

    local procedure CreateNote(SalesHeader: Record "Sales Header"; CRMAnnotation: Record "CRM Annotation")
    var
        RecordLink: Record "Record Link";
        CRMAnnotationCoupling: Record "CRM Annotation Coupling";
        RecordLinkManagement: Codeunit "Record Link Management";
        NoteInStream: InStream;
        AnnotationText: Text;
    begin
        RecordLink."Record ID" := SalesHeader.RecordId();
        RecordLink.Type := RecordLink.Type::Note;
        RecordLink.Description := CRMAnnotation.Subject;
        CRMAnnotation.CalcFields(NoteText);
        CRMAnnotation.NoteText.CreateInStream(NoteInStream, TextEncoding::UTF16);
        NoteInStream.Read(AnnotationText);
        RecordLinkManagement.WriteNote(RecordLink, CRMAnnotationCoupling.ExtractNoteText(AnnotationText));
        RecordLink.Created := CRMAnnotation.CreatedOn;
        RecordLink.Company := CopyStr(CompanyName(), 1, MaxStrLen(RecordLink.Company));
        RecordLink.Insert();
        CRMAnnotationCoupling.Init();
        CRMAnnotationCoupling."Record Link Record ID" := RecordLink.RecordId();
        CRMAnnotationCoupling."CRM Annotation ID" := CRMAnnotation.AnnotationId;
        CRMAnnotationCoupling."Last Synch. DateTime" := CurrentDateTime();
        CRMAnnotationCoupling."CRM Created On" := CRMAnnotation.CreatedOn;
        CRMAnnotationCoupling."CRM Modified On" := CRMAnnotation.ModifiedOn;
        CRMAnnotationCoupling.Insert();
    end;
}
