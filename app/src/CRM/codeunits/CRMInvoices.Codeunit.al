namespace DataverseIntegration.CRM;

using DataverseIntegration.CDS;
using DataverseIntegration.Core;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Foundation.Shipping;
using Microsoft.Integration.D365Sales;
using Microsoft.Integration.Dataverse;
using Microsoft.Integration.SyncEngine;
using Microsoft.Inventory.Item;
using Microsoft.Pricing.Asset;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Sales.Customer;
using Microsoft.Sales.Document;
using Microsoft.Sales.History;
using Microsoft.Sales.Setup;
using Microsoft.Utilities;

codeunit 80415 "DVI CRM Invoices"
{
    Access = Internal;

    var
        NoLinesErr: Label 'The posted sales invoice %1 has no lines.', Comment = '%1 = invoice number';
        CustomerHasChangedErr: Label 'Cannot create the invoice in Dataverse. The customer of the Dataverse sales order %1 was changed or is no longer coupled.', Comment = '%1 = Dataverse order number';
        CustomerNotCoupledErr: Label 'The customer %1 must be coupled to a Dataverse account.', Comment = '%1 = customer number';
        InvoiceNotCoupledErr: Label 'The posted sales invoice %1 is not coupled to a Dataverse invoice.', Comment = '%1 = invoice number';
        UnitDoesNotExistErr: Label 'Cannot create the invoice line in Dataverse. The %1 %2 does not exist.', Comment = '%1 = table caption, %2 = unit of measure code';
        UnitNotCoupledErr: Label 'Cannot create the invoice line in Dataverse. The %1 %2 is not coupled to a Dataverse unit.', Comment = '%1 = table caption, %2 = unit of measure code';
        WriteInDescriptionTxt: Label '%1 %2.', Locked = true, Comment = '%1 = number, %2 = description';
        RoundingTxt: Label 'Rounding', Locked = true;

    /// <summary>
    /// Returns whether a posted sales invoice is coupled to a Dataverse invoice that is no longer active, which cannot be updated.
    /// </summary>
    /// <param name="SalesInvoiceHeaderRecordRef">The posted sales invoice.</param>
    /// <returns>True when the coupled invoice is not active.</returns>
    internal procedure IsReadOnly(var SalesInvoiceHeaderRecordRef: RecordRef): Boolean
    var
        CRMInvoice: Record "CRM Invoice";
        CRMIntegrationRecord: Record "CRM Integration Record";
        CRMInvoiceId: Guid;
    begin
        if not CRMIntegrationRecord.FindIDFromRecordID(SalesInvoiceHeaderRecordRef.RecordId(), CRMInvoiceId) then
            exit(false);
        if not CRMInvoice.Get(CRMInvoiceId) then
            exit(false);
        exit(CRMInvoice.StateCode <> CRMInvoice.StateCode::Active);
    end;

    /// <summary>
    /// Returns whether a posted sales invoice line belongs to an invoice that is not coupled yet; such lines are sent with their invoice.
    /// </summary>
    /// <param name="SalesInvoiceLineRecordRef">The posted sales invoice line.</param>
    /// <returns>True when the invoice of the line is not coupled.</returns>
    internal procedure IsLineOfUncoupledInvoice(var SalesInvoiceLineRecordRef: RecordRef): Boolean
    var
        SalesInvoiceLine: Record "Sales Invoice Line";
        SalesInvoiceHeader: Record "Sales Invoice Header";
        CRMIntegrationRecord: Record "CRM Integration Record";
    begin
        SalesInvoiceLineRecordRef.SetTable(SalesInvoiceLine);
        if not SalesInvoiceHeader.Get(SalesInvoiceLine."Document No.") then
            exit(true);
        exit(not CRMIntegrationRecord.IsRecordCoupled(SalesInvoiceHeader.RecordId()));
    end;

    /// <summary>
    /// Checks the lines of a new invoice before it is sent: there are lines, their items and resources are not blocked, and their products are coupled; an uncoupled product inside its mapping's filter is queued as a prerequisite.
    /// </summary>
    /// <param name="Context">The synchronization context, used to queue prerequisites.</param>
    /// <param name="SalesInvoiceHeaderRecordRef">The posted sales invoice.</param>
    internal procedure CheckLines(var Context: Codeunit "DVI Sync Context"; var SalesInvoiceHeaderRecordRef: RecordRef)
    var
        SalesInvoiceHeader: Record "Sales Invoice Header";
        SalesInvoiceLine: Record "Sales Invoice Line";
        Item: Record Item;
        Resource: Record Resource;
        CRMPrices: Codeunit "DVI CRM Prices";
    begin
        SalesInvoiceHeaderRecordRef.SetTable(SalesInvoiceHeader);
        SalesInvoiceLine.SetRange("Document No.", SalesInvoiceHeader."No.");
        if SalesInvoiceLine.IsEmpty() then
            Error(NoLinesErr, SalesInvoiceHeader."No.");
        SalesInvoiceLine.SetFilter(Type, '%1|%2', SalesInvoiceLine.Type::Item, SalesInvoiceLine.Type::Resource);
        if SalesInvoiceLine.FindSet() then
            repeat
                if SalesInvoiceLine.Type = SalesInvoiceLine.Type::Item then begin
                    Item.Get(SalesInvoiceLine."No.");
                    Item.TestField(Blocked, false);
                end else begin
                    Resource.Get(SalesInvoiceLine."No.");
                    Resource.TestField(Blocked, false);
                end;
                if not IsWriteInProduct(SalesInvoiceLine."No.") then
                    CRMPrices.RequireCoupledProduct(Context, AssetTypeOf(SalesInvoiceLine), SalesInvoiceLine."No.");
            until SalesInvoiceLine.Next() = 0;
    end;

    /// <summary>
    /// Fills a new Dataverse invoice: description from the shipment method, and either the Dataverse order it was invoiced from (order, opportunity, price list, name, customer and owner) or the customer's account and the price list of its currency; company ID and owning team.
    /// </summary>
    /// <param name="Context">The synchronization context, used to queue a customer that is not coupled yet.</param>
    /// <param name="SalesInvoiceHeaderRecordRef">The posted sales invoice.</param>
    /// <param name="CRMInvoiceRecordRef">The new Dataverse invoice.</param>
    internal procedure PrepareInvoice(var Context: Codeunit "DVI Sync Context"; var SalesInvoiceHeaderRecordRef: RecordRef; var CRMInvoiceRecordRef: RecordRef)
    var
        SalesInvoiceHeader: Record "Sales Invoice Header";
        CRMInvoice: Record "CRM Invoice";
        CRMSalesorder: Record "CRM Salesorder";
        ShipmentMethod: Record "Shipment Method";
        CRMSalesOrderToSalesOrder: Codeunit "CRM Sales Order to Sales Order";
        CDSCompany: Codeunit "DVI CDS Company";
        CDSIntegrationMgt: Codeunit "CDS Integration Mgt.";
        OutStream: OutStream;
    begin
        SalesInvoiceHeaderRecordRef.SetTable(SalesInvoiceHeader);
        CRMInvoiceRecordRef.SetTable(CRMInvoice);
        if not CRMInvoice.Description.HasValue() then
            if ShipmentMethod.Get(SalesInvoiceHeader."Shipment Method Code") then begin
                CRMInvoice.Description.CreateOutStream(OutStream, TextEncoding::UTF16);
                OutStream.WriteText(ShipmentMethod.Description);
            end;
        if CRMSalesOrderToSalesOrder.GetCRMSalesOrder(CRMSalesorder, SalesInvoiceHeader."Your Reference") then begin
            CheckCustomerOfOrder(Context, CRMSalesorder, SalesInvoiceHeader);
            CRMInvoice.OpportunityId := CRMSalesorder.OpportunityId;
            CRMInvoice.SalesOrderId := CRMSalesorder.SalesOrderId;
            CRMInvoice.PriceLevelId := CRMSalesorder.PriceLevelId;
            CRMInvoice.Name := CRMSalesorder.Name;
            CRMInvoice.CustomerId := CRMSalesorder.CustomerId;
            CRMInvoice.CustomerIdType := CRMSalesorder.CustomerIdType;
            if CRMSalesorder.OwnerIdType = CRMSalesorder.OwnerIdType::team then begin
                CRMInvoice.OwnerId := CRMSalesorder.OwnerId;
                CRMInvoice.OwnerIdType := CRMInvoice.OwnerIdType::team;
            end;
            CRMInvoiceRecordRef.GetTable(CRMInvoice);
            if CRMSalesorder.OwnerIdType = CRMSalesorder.OwnerIdType::systemuser then
                CDSIntegrationMgt.SetOwningUser(CRMInvoiceRecordRef, CRMSalesorder.OwnerId, true);
            CDSCompany.SetCompanyId(CRMInvoiceRecordRef);
            exit;
        end;
        CRMInvoice.Name := SalesInvoiceHeader."No.";
        CRMInvoice.CustomerId := RequireCoupledCustomer(Context, SalesInvoiceHeader."Sell-to Customer No.");
        CRMInvoice.CustomerIdType := CRMInvoice.CustomerIdType::account;
        CRMInvoice.PriceLevelId := FindPriceLevel(SalesInvoiceHeader);
        CRMInvoiceRecordRef.GetTable(CRMInvoice);
        CDSCompany.SetCompanyId(CRMInvoiceRecordRef);
        SetOwningTeamInTeamModel(CRMInvoiceRecordRef);
    end;

    /// <summary>
    /// Queues the lines of a new Dataverse invoice for synchronization after the invoice, and the completion step that sets its totals.
    /// </summary>
    /// <param name="Context">The synchronization context.</param>
    /// <param name="SalesInvoiceHeaderRecordRef">The posted sales invoice.</param>
    internal procedure QueueLinesAndTotals(var Context: Codeunit "DVI Sync Context"; var SalesInvoiceHeaderRecordRef: RecordRef)
    var
        SalesInvoiceHeader: Record "Sales Invoice Header";
        SalesInvoiceLine: Record "Sales Invoice Line";
        LineMapping: Record "Integration Table Mapping";
        CDSRelations: Codeunit "DVI CDS Relations";
    begin
        SalesInvoiceHeaderRecordRef.SetTable(SalesInvoiceHeader);
        if CDSRelations.FindMapping(Database::"Sales Invoice Line", Database::"CRM Invoicedetail", LineMapping) then begin
            SalesInvoiceLine.SetRange("Document No.", SalesInvoiceHeader."No.");
            SalesInvoiceLine.SetLoadFields(SystemId);
            if SalesInvoiceLine.FindSet() then
                repeat
                    Context.AddFollowUp(LineMapping.Name, SalesInvoiceLine.SystemId, true);
                until SalesInvoiceLine.Next() = 0;
        end;
        Context.AddCompletion(Context.GetMappingName(), SalesInvoiceHeader.SystemId, true, Enum::"DVI Synch Action"::DVIInsert);
    end;

    /// <summary>
    /// Finishes a new Dataverse invoice after its lines were sent: totals, discount, payment status and, with prices including VAT, a rounding line.
    /// </summary>
    /// <param name="SalesInvoiceHeaderRecordRef">The posted sales invoice.</param>
    /// <param name="CRMInvoiceRecordRef">The Dataverse invoice.</param>
    internal procedure CompleteInvoice(var SalesInvoiceHeaderRecordRef: RecordRef; var CRMInvoiceRecordRef: RecordRef)
    var
        SalesInvoiceHeader: Record "Sales Invoice Header";
        SalesInvoiceLine: Record "Sales Invoice Line";
        CRMInvoice: Record "CRM Invoice";
        CRMConnectionSetup: Record "CRM Connection Setup";
        CRMSynchHelper: Codeunit "CRM Synch. Helper";
        DocumentTotals: Codeunit "Document Totals";
        TaxAmount: Decimal;
    begin
        SalesInvoiceHeaderRecordRef.SetTable(SalesInvoiceHeader);
        CRMInvoiceRecordRef.SetTable(CRMInvoice);
        CRMInvoice.Get(CRMInvoice.InvoiceId);
        SalesInvoiceLine.SetRange("Document No.", SalesInvoiceHeader."No.");
        if not SalesInvoiceLine.IsEmpty() then begin
            SalesInvoiceLine.CalcSums("Line Discount Amount");
            CRMInvoice.TotalLineItemDiscountAmount := SalesInvoiceLine."Line Discount Amount";
        end;
        CRMConnectionSetup.SetLoadFields("Is S.Order Integration Enabled", "Bidirectional Sales Order Int.");
        if not CRMConnectionSetup.Get() then
            Clear(CRMConnectionSetup);
        if CRMConnectionSetup."Is S.Order Integration Enabled" or CRMConnectionSetup."Bidirectional Sales Order Int." then begin
            DocumentTotals.CalculatePostedSalesInvoiceTotals(SalesInvoiceHeader, TaxAmount, SalesInvoiceLine);
            CRMInvoice.TotalAmount := SalesInvoiceHeader."Amount Including VAT";
            CRMInvoice.TotalTax := TaxAmount;
            CRMInvoice.TotalAmountLessFreight := CRMInvoice.TotalAmount - CRMInvoice.TotalTax;
            CRMInvoice.TotalDiscountAmount := SalesInvoiceHeader."Invoice Discount Amount";
        end else begin
            CRMInvoice.FreightAmount := 0;
            CRMInvoice.DiscountPercentage := 0;
            CRMInvoice.TotalTax := CRMInvoice.TotalAmount - CRMInvoice.TotalAmountLessFreight;
            CRMInvoice.TotalDiscountAmount := CRMInvoice.DiscountAmount + CRMInvoice.TotalLineItemDiscountAmount;
        end;
        CRMInvoice.Modify();
        CRMSynchHelper.UpdateCRMInvoiceStatus(CRMInvoice, SalesInvoiceHeader);
        AddRoundingLine(SalesInvoiceHeader, CRMInvoice);
    end;

    /// <summary>
    /// Fills a new Dataverse invoice line from the coupled invoice and the posted line: currency, exchange rate, ship-to, line number, tax, price without VAT, and the product and unit, or a write-in product when the line's item or resource has none.
    /// </summary>
    /// <param name="Context">The synchronization context, used to queue an uncoupled product.</param>
    /// <param name="SalesInvoiceLineRecordRef">The posted sales invoice line.</param>
    /// <param name="CRMInvoicedetailRecordRef">The new Dataverse invoice line.</param>
    internal procedure PrepareLine(var Context: Codeunit "DVI Sync Context"; var SalesInvoiceLineRecordRef: RecordRef; var CRMInvoicedetailRecordRef: RecordRef)
    var
        SalesInvoiceLine: Record "Sales Invoice Line";
        SalesInvoiceHeader: Record "Sales Invoice Header";
        CRMInvoice: Record "CRM Invoice";
        CRMInvoicedetail: Record "CRM Invoicedetail";
        CRMIntegrationRecord: Record "CRM Integration Record";
        GeneralLedgerSetup: Record "General Ledger Setup";
        CRMSynchHelper: Codeunit "CRM Synch. Helper";
        CRMInvoiceId: Guid;
    begin
        SalesInvoiceLineRecordRef.SetTable(SalesInvoiceLine);
        CRMInvoicedetailRecordRef.SetTable(CRMInvoicedetail);
        SalesInvoiceHeader.Get(SalesInvoiceLine."Document No.");
        if not CRMIntegrationRecord.FindIDFromRecordID(SalesInvoiceHeader.RecordId(), CRMInvoiceId) then
            Error(InvoiceNotCoupledErr, SalesInvoiceHeader."No.");
        CRMInvoice.Get(CRMInvoiceId);
        CRMInvoicedetail.ActualDeliveryOn := CRMInvoice.DateDelivered;
        CRMInvoicedetail.InvoiceId := CRMInvoice.InvoiceId;
        CRMInvoicedetail.ShipTo_City := CRMInvoice.ShipTo_City;
        CRMInvoicedetail.ShipTo_Country := CRMInvoice.ShipTo_Country;
        CRMInvoicedetail.ShipTo_Line1 := CRMInvoice.ShipTo_Line1;
        CRMInvoicedetail.ShipTo_Line2 := CRMInvoice.ShipTo_Line2;
        CRMInvoicedetail.ShipTo_Line3 := CRMInvoice.ShipTo_Line3;
        CRMInvoicedetail.ShipTo_Name := CRMInvoice.ShipTo_Name;
        CRMInvoicedetail.ShipTo_PostalCode := CRMInvoice.ShipTo_PostalCode;
        CRMInvoicedetail.ShipTo_StateOrProvince := CRMInvoice.ShipTo_StateOrProvince;
        CRMInvoicedetail.ShipTo_Fax := CRMInvoice.ShipTo_Fax;
        CRMInvoicedetail.ShipTo_Telephone := CRMInvoice.ShipTo_Telephone;
        CRMInvoicedetail.TransactionCurrencyId := CRMSynchHelper.GetCRMTransactioncurrency(SalesInvoiceHeader."Currency Code");
        if SalesInvoiceHeader."Currency Factor" = 0 then
            CRMInvoicedetail.ExchangeRate := 1
        else
            CRMInvoicedetail.ExchangeRate := Round(1 / SalesInvoiceHeader."Currency Factor");
        CRMInvoicedetail.LineItemNumber := SalesInvoiceLine."Line No.";
        CRMInvoicedetail.Tax := SalesInvoiceLine."Amount Including VAT" - SalesInvoiceLine.Amount;
        if SalesInvoiceHeader."Prices Including VAT" and (SalesInvoiceLine.Quantity <> 0) then begin
            GeneralLedgerSetup.SetLoadFields("Unit-Amount Rounding Precision");
            GeneralLedgerSetup.Get();
            CRMInvoicedetail.PricePerUnit := SalesInvoiceLine."Unit Price" -
              Round((SalesInvoiceLine."Amount Including VAT" - SalesInvoiceLine.Amount) / SalesInvoiceLine.Quantity, GeneralLedgerSetup."Unit-Amount Rounding Precision");
        end;
        SetProduct(Context, SalesInvoiceLine, CRMInvoicedetail);
        CRMSynchHelper.CreateCRMProductpriceIfAbsent(CRMInvoicedetail);
        CRMInvoicedetailRecordRef.GetTable(CRMInvoicedetail);
    end;

    /// <summary>
    /// Writes the amounts of a posted invoice line to its new Dataverse invoice line: discount, tax, base and extended amount.
    /// </summary>
    /// <param name="SalesInvoiceLineRecordRef">The posted sales invoice line.</param>
    /// <param name="CRMInvoicedetailRecordRef">The inserted Dataverse invoice line.</param>
    internal procedure UpdateLineAmounts(var SalesInvoiceLineRecordRef: RecordRef; var CRMInvoicedetailRecordRef: RecordRef)
    var
        SalesInvoiceLine: Record "Sales Invoice Line";
        CRMInvoicedetail: Record "CRM Invoicedetail";
    begin
        SalesInvoiceLineRecordRef.SetTable(SalesInvoiceLine);
        CRMInvoicedetailRecordRef.SetTable(CRMInvoicedetail);
        CRMInvoicedetail.VolumeDiscountAmount := 0;
        CRMInvoicedetail.ManualDiscountAmount := SalesInvoiceLine."Line Discount Amount";
        CRMInvoicedetail.Tax := SalesInvoiceLine."Amount Including VAT" - SalesInvoiceLine.Amount;
        CRMInvoicedetail.BaseAmount := SalesInvoiceLine.Amount + SalesInvoiceLine."Inv. Discount Amount" + SalesInvoiceLine."Line Discount Amount";
        CRMInvoicedetail.ExtendedAmount := SalesInvoiceLine."Amount Including VAT" + SalesInvoiceLine."Inv. Discount Amount";
        CRMInvoicedetail.Modify();
        CRMInvoicedetailRecordRef.GetTable(CRMInvoicedetail);
    end;

    /// <summary>
    /// Computes the rounding difference between a posted invoice with prices including VAT and its Dataverse lines.
    /// </summary>
    /// <param name="LineAmountIncludingVAT">The amount including VAT of the posted line.</param>
    /// <param name="PricePerUnit">The price per unit of the Dataverse line.</param>
    /// <param name="Quantity">The quantity of the Dataverse line.</param>
    /// <param name="Tax">The tax of the Dataverse line.</param>
    /// <param name="ManualDiscountAmount">The manual discount of the Dataverse line.</param>
    /// <returns>The amount the Dataverse line misses or exceeds.</returns>
    internal procedure RoundingDifference(LineAmountIncludingVAT: Decimal; PricePerUnit: Decimal; Quantity: Decimal; Tax: Decimal; ManualDiscountAmount: Decimal): Decimal
    begin
        exit(LineAmountIncludingVAT - ((PricePerUnit * Quantity) + Tax - ManualDiscountAmount));
    end;

    local procedure AddRoundingLine(SalesInvoiceHeader: Record "Sales Invoice Header"; CRMInvoice: Record "CRM Invoice")
    var
        SalesInvoiceLine: Record "Sales Invoice Line";
        CRMInvoicedetail: Record "CRM Invoicedetail";
        RoundingCRMInvoicedetail: Record "CRM Invoicedetail";
        DifferenceAmount: Decimal;
    begin
        if not SalesInvoiceHeader."Prices Including VAT" then
            exit;
        CRMInvoicedetail.SetRange(InvoiceId, CRMInvoice.InvoiceId);
        CRMInvoicedetail.SetRange(IsProductOverridden, true);
        CRMInvoicedetail.SetRange(ProductDescription, RoundingTxt);
        if not CRMInvoicedetail.IsEmpty() then
            exit;
        SalesInvoiceLine.SetRange("Document No.", SalesInvoiceHeader."No.");
        if not SalesInvoiceLine.FindSet() then
            exit;
        CRMInvoicedetail.Reset();
        CRMInvoicedetail.SetRange(InvoiceId, CRMInvoice.InvoiceId);
        repeat
            CRMInvoicedetail.SetRange(LineItemNumber, SalesInvoiceLine."Line No.");
            if CRMInvoicedetail.FindFirst() then
                DifferenceAmount += RoundingDifference(SalesInvoiceLine."Amount Including VAT", CRMInvoicedetail.PricePerUnit, CRMInvoicedetail.Quantity, CRMInvoicedetail.Tax, CRMInvoicedetail.ManualDiscountAmount);
        until SalesInvoiceLine.Next() = 0;
        if DifferenceAmount = 0 then
            exit;
        RoundingCRMInvoicedetail.Init();
        RoundingCRMInvoicedetail.InvoiceId := CRMInvoice.InvoiceId;
        RoundingCRMInvoicedetail.Quantity := 1;
        RoundingCRMInvoicedetail.PricePerUnit := DifferenceAmount;
        RoundingCRMInvoicedetail.IsProductOverridden := true;
        RoundingCRMInvoicedetail.ProductDescription := RoundingTxt;
        RoundingCRMInvoicedetail.Insert();
    end;

    local procedure SetProduct(var Context: Codeunit "DVI Sync Context"; SalesInvoiceLine: Record "Sales Invoice Line"; var CRMInvoicedetail: Record "CRM Invoicedetail")
    var
        CRMProduct: Record "CRM Product";
        CRMPrices: Codeunit "DVI CRM Prices";
        CRMIntegrationManagement: Codeunit "CRM Integration Management";
        ProductId: Guid;
    begin
        if (SalesInvoiceLine.Type in [SalesInvoiceLine.Type::Item, SalesInvoiceLine.Type::Resource]) and not IsWriteInProduct(SalesInvoiceLine."No.") then
            ProductId := CRMPrices.RequireCoupledProduct(Context, AssetTypeOf(SalesInvoiceLine), SalesInvoiceLine."No.");
        if IsNullGuid(ProductId) then begin
            CRMInvoicedetail.IsProductOverridden := true;
            CRMInvoicedetail.ProductDescription := StrSubstNo(WriteInDescriptionTxt, SalesInvoiceLine."No.", SalesInvoiceLine.Description);
            exit;
        end;
        CRMProduct.Get(ProductId);
        CRMInvoicedetail.ProductId := CRMProduct.ProductId;
        if CRMIntegrationManagement.IsUnitGroupMappingEnabled() then
            CRMInvoicedetail.UoMId := FindCoupledUnit(SalesInvoiceLine)
        else
            CRMInvoicedetail.UoMId := CRMProduct.DefaultUoMId;
    end;

    local procedure FindCoupledUnit(SalesInvoiceLine: Record "Sales Invoice Line") UoMId: Guid
    var
        ItemUnitOfMeasure: Record "Item Unit of Measure";
        ResourceUnitOfMeasure: Record "Resource Unit of Measure";
        CRMIntegrationRecord: Record "CRM Integration Record";
    begin
        if SalesInvoiceLine.Type = SalesInvoiceLine.Type::Item then begin
            if not ItemUnitOfMeasure.Get(SalesInvoiceLine."No.", SalesInvoiceLine."Unit of Measure Code") then
                Error(UnitDoesNotExistErr, ItemUnitOfMeasure.TableCaption(), SalesInvoiceLine."Unit of Measure Code");
            if not CRMIntegrationRecord.FindIDFromRecordID(ItemUnitOfMeasure.RecordId(), UoMId) then
                Error(UnitNotCoupledErr, ItemUnitOfMeasure.TableCaption(), SalesInvoiceLine."Unit of Measure Code");
            exit;
        end;
        if not ResourceUnitOfMeasure.Get(SalesInvoiceLine."No.", SalesInvoiceLine."Unit of Measure Code") then
            Error(UnitDoesNotExistErr, ResourceUnitOfMeasure.TableCaption(), SalesInvoiceLine."Unit of Measure Code");
        if not CRMIntegrationRecord.FindIDFromRecordID(ResourceUnitOfMeasure.RecordId(), UoMId) then
            Error(UnitNotCoupledErr, ResourceUnitOfMeasure.TableCaption(), SalesInvoiceLine."Unit of Measure Code");
    end;

    local procedure CheckCustomerOfOrder(var Context: Codeunit "DVI Sync Context"; CRMSalesorder: Record "CRM Salesorder"; SalesInvoiceHeader: Record "Sales Invoice Header")
    var
        Customer: Record Customer;
        CRMAccount: Record "CRM Account";
        CustomerMapping: Record "Integration Table Mapping";
        CRMSalesOrderToSalesOrder: Codeunit "CRM Sales Order to Sales Order";
        CDSRelations: Codeunit "DVI CDS Relations";
    begin
        if not CRMSalesOrderToSalesOrder.GetCoupledCustomer(CRMSalesorder, Customer) then begin
            if CRMSalesOrderToSalesOrder.GetCRMAccountOfCRMSalesOrder(CRMSalesorder, CRMAccount) then
                if CDSRelations.FindMapping(Database::Customer, Database::"CRM Account", CustomerMapping) then
                    Context.AddPrerequisite(CustomerMapping.Name, CRMAccount.AccountId, false);
            Error(CustomerHasChangedErr, CRMSalesorder.OrderNumber);
        end;
        if Customer."No." <> SalesInvoiceHeader."Sell-to Customer No." then
            Error(CustomerHasChangedErr, CRMSalesorder.OrderNumber);
    end;

    local procedure RequireCoupledCustomer(var Context: Codeunit "DVI Sync Context"; CustomerNo: Code[20]) AccountId: Guid
    var
        Customer: Record Customer;
        CRMPrices: Codeunit "DVI CRM Prices";
        CustomerRecordRef: RecordRef;
    begin
        Customer.SetRange("No.", CustomerNo);
        CustomerRecordRef.GetTable(Customer);
        AccountId := CRMPrices.RequireCoupledRecord(Context, CustomerRecordRef, Database::"CRM Account");
        if IsNullGuid(AccountId) then
            Error(CustomerNotCoupledErr, CustomerNo);
    end;

    local procedure FindPriceLevel(SalesInvoiceHeader: Record "Sales Invoice Header"): Guid
    var
        CRMPricelevel: Record "CRM Pricelevel";
        CRMSynchHelper: Codeunit "CRM Synch. Helper";
    begin
        if not CRMSynchHelper.FindCRMPriceListByCurrencyCode(CRMPricelevel, SalesInvoiceHeader."Currency Code") then
            CRMSynchHelper.CreateCRMPricelevelInCurrency(CRMPricelevel, SalesInvoiceHeader."Currency Code", SalesInvoiceHeader."Currency Factor");
        exit(CRMPricelevel.PriceLevelId);
    end;

    local procedure SetOwningTeamInTeamModel(var CRMInvoiceRecordRef: RecordRef)
    var
        CDSConnectionSetup: Record "CDS Connection Setup";
        CDSIntegrationMgt: Codeunit "CDS Integration Mgt.";
    begin
        CDSConnectionSetup.SetLoadFields("Ownership Model");
        if not CDSConnectionSetup.Get() then
            exit;
        if CDSConnectionSetup."Ownership Model" = CDSConnectionSetup."Ownership Model"::Team then
            CDSIntegrationMgt.SetOwningTeam(CRMInvoiceRecordRef);
    end;

    local procedure AssetTypeOf(SalesInvoiceLine: Record "Sales Invoice Line"): Enum "Price Asset Type"
    begin
        if SalesInvoiceLine.Type = SalesInvoiceLine.Type::Resource then
            exit(Enum::"Price Asset Type"::Resource);
        exit(Enum::"Price Asset Type"::Item);
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
