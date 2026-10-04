namespace DataverseIntegration.Core;

using DataverseIntegration.CDS;
using DataverseIntegration.CRM;
using DataverseIntegration.FieldService;

enum 80000 "DVI Sync Handler" implements "DVI IRecordSync", "DVI IRecordCoupling", "DVI IRecordFilter", "DVI IConflictPolicy", "DVI IOptionSource", "DVI IHandlerScope",
    "DVI IIntegrationRecordView", "DVI ISynchronizeAction", "DVI ICouplingAction", "DVI ICreateAction", "DVI ISynchLogView", "DVI IStatisticsAction", "DVI IRecordCompletion", "DVI IChangeDetection", "DVI ILocalRecordView"
{
    Caption = 'Synchronization Handler';
    Extensible = true;
    DefaultImplementation = "DVI IRecordSync" = "DVI Generic Handler", "DVI IRecordCoupling" = "DVI Generic Handler", "DVI IRecordFilter" = "DVI Generic Handler", "DVI IConflictPolicy" = "DVI Mapping Conflict Policy", "DVI IOptionSource" = "DVI Standard Option Source", "DVI IHandlerScope" = "DVI Generic Handler",
        "DVI IIntegrationRecordView" = "DVI Standard Record Actions", "DVI ISynchronizeAction" = "DVI Standard Record Actions", "DVI ICouplingAction" = "DVI Standard Record Actions", "DVI ICreateAction" = "DVI Standard Record Actions", "DVI ISynchLogView" = "DVI Standard Record Actions", "DVI IStatisticsAction" = "DVI Standard Record Actions", "DVI IRecordCompletion" = "DVI Generic Handler", "DVI IChangeDetection" = "DVI Generic Handler", "DVI ILocalRecordView" = "DVI Standard Record Actions";

    value(0; DVIMicrosoft)
    {
        Caption = 'Microsoft (not redesigned)';
    }
    value(1; DVIGeneric)
    {
        Caption = 'Generic';
    }
    value(100; DVICDSAccount)
    {
        Caption = 'Customer/Vendor - Account';
        Implementation = "DVI IRecordSync" = "DVI Account Handler", "DVI IRecordCoupling" = "DVI Account Handler", "DVI IHandlerScope" = "DVI Account Handler", "DVI IStatisticsAction" = "DVI Account Statistics";
    }
    value(110; DVICDSContact)
    {
        Caption = 'Contact - Contact';
        Implementation = "DVI IRecordSync" = "DVI Contact Handler", "DVI IRecordCoupling" = "DVI Contact Handler", "DVI IRecordFilter" = "DVI Contact Handler", "DVI IHandlerScope" = "DVI Contact Handler";
    }
    value(120; DVICDSCurrency)
    {
        Caption = 'Currency - Transaction Currency';
        Implementation = "DVI IRecordSync" = "DVI Currency Handler", "DVI IRecordCoupling" = "DVI Currency Handler", "DVI IHandlerScope" = "DVI Currency Handler";
    }
    value(130; DVICDSSalesperson)
    {
        Caption = 'Salesperson - User';
        Implementation = "DVI IRecordSync" = "DVI Salesperson Handler", "DVI IHandlerScope" = "DVI Salesperson Handler";
    }
    value(200; DVICRMProduct)
    {
        Caption = 'Item/Resource - Product';
        Implementation = "DVI IRecordSync" = "DVI Product Handler", "DVI IRecordCoupling" = "DVI Product Handler", "DVI IRecordFilter" = "DVI Product Handler", "DVI IHandlerScope" = "DVI Product Handler";
    }
    value(210; DVICRMUnitGroup)
    {
        Caption = 'Unit Group - Unit Group';
        Implementation = "DVI IRecordSync" = "DVI Unit Group Handler", "DVI IRecordCoupling" = "DVI Unit Group Handler", "DVI IHandlerScope" = "DVI Unit Group Handler";
    }
    value(220; DVICRMUnit)
    {
        Caption = 'Item/Resource Unit of Measure - Unit';
        Implementation = "DVI IRecordSync" = "DVI Unit Handler", "DVI IRecordCoupling" = "DVI Unit Handler", "DVI IHandlerScope" = "DVI Unit Handler";
    }
    value(230; DVICRMPriceLevel)
    {
        Caption = 'Price Group/Price List - Price List';
        Implementation = "DVI IRecordSync" = "DVI Price Level Handler", "DVI IHandlerScope" = "DVI Price Level Handler";
    }
    value(240; DVICRMPriceLine)
    {
        Caption = 'Price/Price List Line - Price List Item';
        Implementation = "DVI IRecordSync" = "DVI Price Line Handler", "DVI IRecordCoupling" = "DVI Price Line Handler", "DVI IHandlerScope" = "DVI Price Line Handler";
    }
    value(250; DVICRMOpportunity)
    {
        Caption = 'Opportunity - Opportunity';
        Implementation = "DVI IRecordSync" = "DVI Opportunity Handler", "DVI IRecordCoupling" = "DVI Opportunity Handler", "DVI IRecordFilter" = "DVI Opportunity Handler", "DVI IHandlerScope" = "DVI Opportunity Handler";
    }
    value(260; DVICRMSalesOption)
    {
        Caption = 'Payment Terms/Shipping - Sales Document Options';
        Implementation = "DVI IRecordSync" = "DVI Sales Option Handler", "DVI IHandlerScope" = "DVI Sales Option Handler";
    }
    value(270; DVICRMSalesOrder)
    {
        Caption = 'Sales Order - Order';
        Implementation = "DVI IRecordSync" = "DVI Sales Order Handler", "DVI IRecordCoupling" = "DVI Sales Order Handler", "DVI IRecordFilter" = "DVI Sales Order Handler", "DVI IHandlerScope" = "DVI Sales Order Handler", "DVI IRecordCompletion" = "DVI Sales Order Handler";
    }
    value(280; DVICRMSalesOrderLine)
    {
        Caption = 'Sales Order Line - Order Product';
        Implementation = "DVI IRecordSync" = "DVI Sales Order Line Handler", "DVI IHandlerScope" = "DVI Sales Order Line Handler";
    }
    value(290; DVICRMInvoice)
    {
        Caption = 'Posted Sales Invoice - Invoice';
        Implementation = "DVI IRecordSync" = "DVI Invoice Handler", "DVI IRecordCoupling" = "DVI Invoice Handler", "DVI IRecordFilter" = "DVI Invoice Handler", "DVI IHandlerScope" = "DVI Invoice Handler", "DVI IRecordCompletion" = "DVI Invoice Handler";
    }
    value(300; DVICRMInvoiceLine)
    {
        Caption = 'Posted Sales Invoice Line - Invoice Product';
        Implementation = "DVI IRecordSync" = "DVI Invoice Line Handler", "DVI IRecordFilter" = "DVI Invoice Line Handler", "DVI IHandlerScope" = "DVI Invoice Line Handler";
    }
    value(400; DVIFSBookableResource)
    {
        Caption = 'Resource - Bookable Resource';
        Implementation = "DVI IRecordSync" = "DVI Bookable Resource Handler", "DVI IRecordCoupling" = "DVI Bookable Resource Handler", "DVI IRecordFilter" = "DVI Bookable Resource Handler", "DVI IHandlerScope" = "DVI Bookable Resource Handler";
    }
    value(410; DVIFSCustomerAsset)
    {
        Caption = 'Service Item - Customer Asset';
        Implementation = "DVI IRecordSync" = "DVI Customer Asset Handler", "DVI IRecordCoupling" = "DVI Customer Asset Handler", "DVI IRecordFilter" = "DVI Customer Asset Handler", "DVI IHandlerScope" = "DVI Customer Asset Handler";
    }
    value(420; DVIFSWarehouse)
    {
        Caption = 'Location - Warehouse';
        Implementation = "DVI IRecordSync" = "DVI Warehouse Handler", "DVI IRecordCoupling" = "DVI Warehouse Handler", "DVI IHandlerScope" = "DVI Warehouse Handler";
    }
    value(430; DVIFSWorkOrderType)
    {
        Caption = 'Service Order Type - Work Order Type';
        Implementation = "DVI IRecordSync" = "DVI Work Order Type Handler", "DVI IRecordCoupling" = "DVI Work Order Type Handler", "DVI IHandlerScope" = "DVI Work Order Type Handler";
    }
    value(440; DVIFSProjectTask)
    {
        Caption = 'Project Task - Project Task';
        Implementation = "DVI IRecordSync" = "DVI Project Task Handler", "DVI IRecordCoupling" = "DVI Project Task Handler", "DVI IRecordFilter" = "DVI Project Task Handler", "DVI IHandlerScope" = "DVI Project Task Handler";
    }
    value(450; DVIFSProjectLine)
    {
        Caption = 'Project Journal Line - Work Order Product/Service';
        Implementation = "DVI IRecordSync" = "DVI Project Line Handler", "DVI IRecordFilter" = "DVI Project Line Handler", "DVI IConflictPolicy" = "DVI Project Line Handler", "DVI IHandlerScope" = "DVI Project Line Handler", "DVI IRecordCompletion" = "DVI Project Line Handler";
    }
    value(460; DVIFSWorkOrder)
    {
        Caption = 'Service Order - Work Order';
        Implementation = "DVI IRecordSync" = "DVI Work Order Handler", "DVI IRecordCoupling" = "DVI Work Order Handler", "DVI IRecordFilter" = "DVI Work Order Handler", "DVI IHandlerScope" = "DVI Work Order Handler", "DVI IChangeDetection" = "DVI Work Order Handler", "DVI ILocalRecordView" = "DVI Work Order Handler";
    }
    value(470; DVIFSWorkOrderIncident)
    {
        Caption = 'Service Item Line - Work Order Incident';
        Implementation = "DVI IRecordSync" = "DVI Incident Handler", "DVI IHandlerScope" = "DVI Incident Handler";
    }
    value(480; DVIFSWorkOrderLine)
    {
        Caption = 'Service Line - Work Order Product/Service/Booking';
        Implementation = "DVI IRecordSync" = "DVI Work Order Line Handler", "DVI IRecordCoupling" = "DVI Work Order Line Handler", "DVI IRecordFilter" = "DVI Work Order Line Handler", "DVI IHandlerScope" = "DVI Work Order Line Handler";
    }
}
