namespace DataverseIntegration.Test;

using DataverseIntegration.Core;
using DataverseIntegration.CRM;
using Microsoft.CRM.Opportunity;
using Microsoft.Foundation.PaymentTerms;
using Microsoft.Foundation.UOM;
using Microsoft.Integration.D365Sales;
using Microsoft.Integration.SyncEngine;
using Microsoft.Inventory.Item;
using Microsoft.Pricing.PriceList;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Purchases.Vendor;
using Microsoft.Sales.Customer;
using Microsoft.Sales.Pricing;
using Microsoft.Sales.Setup;
using System.Reflection;
using System.TestLibraries.Utilities;

codeunit 84019 "DVI CRM Handler Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLibrary: Codeunit "DVI Test Library";

    [Test]
    procedure SwitchingPicksTheHandlerOfEachSalesTablePair()
    begin
        // [GIVEN] / [WHEN] Mappings of each Dynamics 365 Sales table pair are switched
        // [THEN] Each gets the handler that serves its pair and the Sales module
        AssertSwitchedHandler('DVIITEM', Database::Item, Database::"CRM Product", Enum::"DVI Sync Handler"::DVICRMProduct);
        AssertSwitchedHandler('DVIRES', Database::Resource, Database::"CRM Product", Enum::"DVI Sync Handler"::DVICRMProduct);
        AssertSwitchedHandler('DVIUGROUP', Database::"Unit Group", Database::"CRM Uomschedule", Enum::"DVI Sync Handler"::DVICRMUnitGroup);
        AssertSwitchedHandler('DVIIUOM', Database::"Item Unit of Measure", Database::"CRM Uom", Enum::"DVI Sync Handler"::DVICRMUnit);
        AssertSwitchedHandler('DVICPG', Database::"Customer Price Group", Database::"CRM Pricelevel", Enum::"DVI Sync Handler"::DVICRMPriceLevel);
        AssertSwitchedHandler('DVIPLH', Database::"Price List Header", Database::"CRM Pricelevel", Enum::"DVI Sync Handler"::DVICRMPriceLevel);
        AssertSwitchedHandler('DVIPLL', Database::"Price List Line", Database::"CRM Productpricelevel", Enum::"DVI Sync Handler"::DVICRMPriceLine);
        AssertSwitchedHandler('DVIOPP', Database::Opportunity, Database::"CRM Opportunity", Enum::"DVI Sync Handler"::DVICRMOpportunity);
    end;

    [Test]
    procedure PaymentTermsOptionMappingGetsTheSalesOptionHandler()
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        MappingAssignment: Record "DVI Mapping Assignment";
        "Field": Record "Field";
        DefaultAssignment: Codeunit "DVI Default Assignment";
    begin
        // [GIVEN] An option mapping of payment terms
        IntegrationTableMapping := TestLibrary.CreateDataverseMapping('DVIPAYTERM', Database::"Payment Terms", Database::"CRM Account", IntegrationTableMapping.Direction::ToIntegrationTable);
        IntegrationTableMapping."Int. Table UID Field Type" := Field.Type::Option;
        IntegrationTableMapping.Modify(false);

        // [WHEN] It is switched
        DefaultAssignment.SwitchToRedesigned(IntegrationTableMapping);

        // [THEN] The Sales option handler serves it within the Dataverse module
        MappingAssignment.Get('DVIPAYTERM');
        Assert.AreEqual(Enum::"DVI Sync Handler"::DVICRMSalesOption, MappingAssignment.Handler, 'Handler');
        Assert.AreEqual(Enum::"DVI Integration Module"::DVIDataverse, MappingAssignment.Module, 'Module');
    end;

    [Test]
    procedure PaymentTermsTableMappingIsNotAnOptionMapping()
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        SalesOptionHandler: Codeunit "DVI Sales Option Handler";
        Context: Codeunit "DVI Sync Context";
    begin
        // [GIVEN] A payment terms mapping keyed by a GUID
        IntegrationTableMapping := TestLibrary.CreateDataverseMapping('DVIPAYTERM2', Database::"Payment Terms", Database::"CRM Account", IntegrationTableMapping.Direction::ToIntegrationTable);
        Context.SetMapping(IntegrationTableMapping);

        // [WHEN] / [THEN] The Sales option handler does not serve it
        Assert.IsFalse(SalesOptionHandler.Serves(Context), 'Only option mappings are served.');
    end;

    [Test]
    procedure WriteInProductIsNotSentToDataverse()
    var
        SalesReceivablesSetup: Record "Sales & Receivables Setup";
        TempItem: Record Item temporary;
        ProductHandler: Codeunit "DVI Product Handler";
        Context: Codeunit "DVI Sync Context";
        ItemRecordRef: RecordRef;
    begin
        // [GIVEN] An item that is the write-in product
        if not SalesReceivablesSetup.Get() then begin
            SalesReceivablesSetup.Init();
            SalesReceivablesSetup.Insert(false);
        end;
        SalesReceivablesSetup."Write-in Product No." := 'DVIWRITEIN';
        SalesReceivablesSetup.Modify(false);
        TempItem."No." := 'DVIWRITEIN';
        ItemRecordRef.GetTable(TempItem);

        // [WHEN] / [THEN] It is left out of the synchronization
        Assert.IsTrue(ProductHandler.IgnoreRecord(Context, ItemRecordRef), 'The write-in product must be ignored.');

        // [WHEN] / [THEN] Any other item is synchronized
        TempItem."No." := 'DVIOTHER';
        ItemRecordRef.GetTable(TempItem);
        Assert.IsFalse(ProductHandler.IgnoreRecord(Context, ItemRecordRef), 'Other items must be synchronized.');
    end;

    [Test]
    procedure RetiredProductBlocksItsItem()
    var
        TempCRMProduct: Record "CRM Product" temporary;
        TempItem: Record Item temporary;
        ProductHandler: Codeunit "DVI Product Handler";
        Context: Codeunit "DVI Sync Context";
        ProductRecordRef: RecordRef;
        ItemRecordRef: RecordRef;
        AdditionalFieldsModified: Boolean;
    begin
        // [GIVEN] A retired product and an unblocked item
        TempCRMProduct.StateCode := TempCRMProduct.StateCode::Retired;
        ProductRecordRef.GetTable(TempCRMProduct);
        ItemRecordRef.GetTable(TempItem);
        Context.SetToIntegrationTable(false);

        // [WHEN] The product is synchronized to the item
        ProductHandler.AfterTransferFields(Context, ProductRecordRef, ItemRecordRef, AdditionalFieldsModified);

        // [THEN] The item is blocked
        Assert.IsTrue(AdditionalFieldsModified, 'The item must be reported as modified.');
        ItemRecordRef.SetTable(TempItem);
        Assert.IsTrue(TempItem.Blocked, 'Blocked');
    end;

    [Test]
    procedure ActiveProductLeavesItsResourceAlone()
    var
        TempCRMProduct: Record "CRM Product" temporary;
        TempResource: Record Resource temporary;
        ProductHandler: Codeunit "DVI Product Handler";
        Context: Codeunit "DVI Sync Context";
        ProductRecordRef: RecordRef;
        ResourceRecordRef: RecordRef;
        AdditionalFieldsModified: Boolean;
    begin
        // [GIVEN] An active product and an unblocked resource
        TempCRMProduct.StateCode := TempCRMProduct.StateCode::Active;
        ProductRecordRef.GetTable(TempCRMProduct);
        ResourceRecordRef.GetTable(TempResource);
        Context.SetToIntegrationTable(false);

        // [WHEN] The product is synchronized to the resource
        ProductHandler.AfterTransferFields(Context, ProductRecordRef, ResourceRecordRef, AdditionalFieldsModified);

        // [THEN] Nothing changes
        Assert.IsFalse(AdditionalFieldsModified, 'The resource must not be modified.');
    end;

    [Test]
    procedure AccountStatisticsAreOfferedOnlyForCoupledCustomers()
    var
        CustomerMapping: Record "Integration Table Mapping";
        VendorMapping: Record "Integration Table Mapping";
        TempCustomer: Record Customer temporary;
        AccountStatistics: Codeunit "DVI Account Statistics";
        Context: Codeunit "DVI Record Action Context";
        VendorContext: Codeunit "DVI Record Action Context";
    begin
        // [GIVEN] An uncoupled customer on a bidirectional mapping
        CustomerMapping := TestLibrary.CreateDataverseMapping('DVISTATCUST', Database::Customer, Database::"CRM Account", CustomerMapping.Direction::Bidirectional);
        TempCustomer."No." := 'DVISTAT';
        Context.SetRecord(TempCustomer.RecordId());
        Context.SetMapping(CustomerMapping);

        // [WHEN] / [THEN] The action is not offered while the customer is not coupled
        Assert.IsFalse(AccountStatistics.CanUpdateStatistics(Context), 'An uncoupled customer has no account to update.');

        // [GIVEN] A coupled vendor
        VendorMapping := TestLibrary.CreateDataverseMapping('DVISTATVEND', Database::Vendor, Database::"CRM Account", VendorMapping.Direction::Bidirectional);
        VendorContext.SetMapping(VendorMapping);
        VendorContext.SetCoupling(CreateGuid());

        // [WHEN] / [THEN] The action is never offered for vendors
        Assert.IsFalse(AccountStatistics.CanUpdateStatistics(VendorContext), 'Account statistics are for customers only.');
    end;

    [Test]
    procedure StatisticsAreNotOfferedByDefault()
    var
        StandardRecordActions: Codeunit "DVI Standard Record Actions";
        Context: Codeunit "DVI Record Action Context";
    begin
        // [GIVEN] / [WHEN] / [THEN] Handlers without statistics never show the action
        Assert.IsFalse(StandardRecordActions.CanUpdateStatistics(Context), 'The default implementation offers no statistics.');
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
