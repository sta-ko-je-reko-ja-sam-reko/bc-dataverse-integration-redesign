namespace DataverseIntegration.Test;

using DataverseIntegration.CDS;
using DataverseIntegration.Core;
using DataverseIntegration.FieldService;
using Microsoft.CRM.Team;
using Microsoft.Foundation.PaymentTerms;
using Microsoft.Integration.D365Sales;
using Microsoft.Integration.Dataverse;
using Microsoft.Integration.DynamicsFieldService;
using Microsoft.Integration.SyncEngine;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Resources.Resource;
using Microsoft.Sales.Customer;
using Microsoft.Service.Document;
using Microsoft.Service.Item;
using System.TestLibraries.Utilities;

codeunit 84022 "DVI Microsoft Defect Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLibrary: Codeunit "DVI Test Library";

    [Test]
    procedure UncouplingLeavesCouplingsOfOtherMappingsAlone()
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        CRMIntegrationRecord: Record "CRM Integration Record";
        CouplingRunner: Codeunit "DVI Coupling Runner";
    begin
        // [GIVEN] Couplings of one table: one of mapping A, one of mapping B, one without mapping name
        // Microsoft: CDS Int. Table Uncouple without filters uncouples all three
        IntegrationTableMapping := TestLibrary.CreateDataverseMapping('DVIUNCA', Database::Customer, Database::"CRM Account", IntegrationTableMapping.Direction::Bidirectional);
        InsertCoupling(Database::Customer, 'DVIUNCA');
        InsertCoupling(Database::Customer, 'DVIUNCB');
        InsertCoupling(Database::Customer, '');

        // [WHEN] Mapping A is uncoupled
        CouplingRunner.SetCouplingFilter(IntegrationTableMapping, CRMIntegrationRecord);

        // [THEN] Only its own couplings and those without mapping name are selected
        Assert.IsTrue(CountCouplings(CRMIntegrationRecord, 'DVIUNCA') = 1, 'The coupling of mapping A is uncoupled.');
        Assert.IsTrue(CountCouplings(CRMIntegrationRecord, '') >= 1, 'Couplings without mapping name are uncoupled.');
        Assert.IsTrue(CountCouplings(CRMIntegrationRecord, 'DVIUNCB') = 0, 'The coupling of mapping B must stay.');
    end;

    [Test]
    procedure OrphanCouplingIsDeletedByItsPrimaryKey()
    var
        CRMIntegrationRecord: Record "CRM Integration Record";
        CouplingRunner: Codeunit "DVI Coupling Runner";
        CRMId: Guid;
        IntegrationId: Guid;
    begin
        // [GIVEN] A coupling whose records no longer exist
        // Microsoft: Get("Integration ID", "CRM ID") against the key (CRM ID, Integration ID) never finds it
        CRMId := CreateGuid();
        IntegrationId := CreateGuid();
        CRMIntegrationRecord.Init();
        CRMIntegrationRecord."CRM ID" := CRMId;
        CRMIntegrationRecord."Integration ID" := IntegrationId;
        CRMIntegrationRecord."Table ID" := Database::Customer;
        CRMIntegrationRecord.Insert(false);

        // [WHEN] The orphan is deleted
        CouplingRunner.DeleteOrphanCoupling(CRMIntegrationRecord);

        // [THEN] It is gone
        Assert.IsFalse(CRMIntegrationRecord.Get(CRMId, IntegrationId), 'The orphan coupling must be deleted.');
    end;

    [Test]
    procedure OptionChangeIsDetectedOnTheOptionCoupling()
    var
        PaymentTerms: Record "Payment Terms";
        CRMOptionMapping: Record "CRM Option Mapping";
        OptionCouplingStore: Codeunit "DVI Option Coupling Store";
        PaymentTermsRecordRef: RecordRef;
    begin
        // [GIVEN] A payment term coupled to an option, synchronized after its last change
        // Microsoft: Int. Option Synch. Invoke looks for the change in CRM Integration Record, which option couplings never use
        PaymentTerms.Init();
        PaymentTerms.Code := 'DVIPT';
        PaymentTerms.Insert(false);
        PaymentTermsRecordRef.GetTable(PaymentTerms);
        CRMOptionMapping."Record ID" := PaymentTerms.RecordId();
        CRMOptionMapping."Last Synch. Modified On" := PaymentTerms.SystemModifiedAt + 1000;

        // [WHEN] / [THEN] It is unchanged
        Assert.IsTrue(OptionCouplingStore.IsUnchangedSinceLastSynch(PaymentTermsRecordRef, CRMOptionMapping), 'Synchronized after the last change.');

        // [GIVEN] / [WHEN] / [THEN] Changed after the last synchronization, it is sent again
        CRMOptionMapping."Last Synch. Modified On" := PaymentTerms.SystemModifiedAt - 1000;
        Assert.IsFalse(OptionCouplingStore.IsUnchangedSinceLastSynch(PaymentTermsRecordRef, CRMOptionMapping), 'Changed after the last synchronization.');
    end;

    [Test]
    procedure ResourceResolvesToTheMappingOfTheRequestedTable()
    var
        ProductMapping: Record "Integration Table Mapping";
        BookableResourceMapping: Record "Integration Table Mapping";
        Resource: Record Resource;
        IntegrationTableMapping: Record "Integration Table Mapping";
        RecordMappingResolver: Codeunit "DVI Record Mapping Resolver";
        Context: Codeunit "DVI Record Action Context";
        ProductId: Guid;
    begin
        // [GIVEN] A resource coupled to a product and to a bookable resource
        // Microsoft: GetIntegrationTableMapping takes the first mapping of the table, so Sales actions open the bookable resource
        ProductMapping := TestLibrary.CreateDataverseMapping('DVIRESPROD', Database::Resource, Database::"CRM Product", ProductMapping.Direction::Bidirectional);
        BookableResourceMapping := TestLibrary.CreateDataverseMapping('DVIRESBOOK', Database::Resource, Database::"FS Bookable Resource", BookableResourceMapping.Direction::Bidirectional);
        Resource.Init();
        Resource."No." := 'DVIRES1';
        Resource.Insert(false);
        InsertCouplingOf(Resource.SystemId, Database::Resource, 'DVIRESBOOK');
        ProductId := InsertCouplingOf(Resource.SystemId, Database::Resource, 'DVIRESPROD');

        // [WHEN] The resource is resolved for the product table
        Assert.IsTrue(RecordMappingResolver.Resolve(Resource.RecordId(), Database::"CRM Product", Context), 'A mapping must be found.');

        // [THEN] The product mapping and the product coupling are used
        Context.GetMapping(IntegrationTableMapping);
        Assert.AreEqual('DVIRESPROD', IntegrationTableMapping.Name, 'Mapping');
        Assert.AreEqual(ProductId, Context.GetIntegrationId(), 'Coupling');
    end;

    [Test]
    procedure CoupledServiceItemCanBeUncoupled()
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        ServiceItem: Record "Service Item";
        RecordActions: Codeunit "DVI Record Actions";
    begin
        // [GIVEN] A service item coupled to a customer asset, and the redesigned integration enabled
        // Microsoft: the FS Service Item Card never assigns CRMIsCoupledToRecord, so Delete Coupling is always disabled
        TestLibrary.SetFeatureEnabled(true);
        IntegrationTableMapping := TestLibrary.CreateDataverseMapping('DVISVCASSET', Database::"Service Item", Database::"FS Customer Asset", IntegrationTableMapping.Direction::Bidirectional);
        ServiceItem.Init();
        ServiceItem."No." := 'DVISI1';
        ServiceItem.Insert(false);
        InsertCouplingOf(ServiceItem.SystemId, Database::"Service Item", 'DVISVCASSET');

        // [WHEN] The service item card refreshes its Field Service actions
        RecordActions.Refresh(ServiceItem.RecordId(), Database::"FS Customer Asset");

        // [THEN] Delete Coupling is available
        Assert.IsTrue(RecordActions.CanDeleteCoupling(), 'A coupled service item can be uncoupled.');
        TestLibrary.SetFeatureEnabled(false);
    end;

    [Test]
    procedure RelatedMappingPrefersTheSwitchedMapping()
    var
        FirstMapping: Record "Integration Table Mapping";
        SwitchedMapping: Record "Integration Table Mapping";
        FoundMapping: Record "Integration Table Mapping";
        CDSRelations: Codeunit "DVI CDS Relations";
    begin
        // [GIVEN] Two mappings of the same table pair, the second one switched
        // Microsoft: several subscribers take FindFirst on (Table ID, Integration Table ID), an arbitrary mapping
        FirstMapping := TestLibrary.CreateDataverseMapping('DVIAREL1', Database::"Payment Terms", Database::"CRM Product", FirstMapping.Direction::Bidirectional);
        SwitchedMapping := TestLibrary.CreateDataverseMapping('DVIAREL2', Database::"Payment Terms", Database::"CRM Product", SwitchedMapping.Direction::Bidirectional);
        TestLibrary.AssignHandler('DVIAREL2', Enum::"DVI Sync Handler"::DVIGeneric);

        // [WHEN] The mapping of the pair is looked up
        Assert.IsTrue(CDSRelations.FindMapping(Database::"Payment Terms", Database::"CRM Product", FoundMapping), 'A mapping must be found.');

        // [THEN] The switched mapping wins
        Assert.AreEqual('DVIAREL2', FoundMapping.Name, 'Mapping');
    end;

    [Test]
    procedure ServiceLinesWithoutServiceItemLineAreRejected()
    var
        ServiceHeader: Record "Service Header";
        ServiceLine: Record "Service Line";
        FSServiceOrders: Codeunit "DVI FS Service Orders";
        ServiceHeaderRecordRef: RecordRef;
    begin
        // [GIVEN] A service order with a line that has no service item line
        // Microsoft: the unchanged-record branch checks a Service Header variable that was never loaded, so nothing is checked
        ServiceHeader."Document Type" := ServiceHeader."Document Type"::Order;
        ServiceHeader."No." := 'DVISVO2';
        ServiceHeader.Insert(false);
        ServiceLine."Document Type" := ServiceLine."Document Type"::Order;
        ServiceLine."Document No." := 'DVISVO2';
        ServiceLine."Line No." := 10000;
        ServiceLine.Insert(false);
        ServiceHeaderRecordRef.GetTable(ServiceHeader);

        // [WHEN] / [THEN] The order is rejected
        asserterror FSServiceOrders.CheckLinesAssigned(ServiceHeaderRecordRef);
        Assert.ExpectedError(ServiceLine.FieldCaption("Service Item Line No."));
    end;

    [Test]
    procedure UncoupledSellToCustomerIsNamedInTheError()
    var
        Customer: Record Customer;
        Job: Record Job;
        JobTask: Record "Job Task";
        TempFSProjectTask: Record "FS Project Task" temporary;
        ProjectTaskHandler: Codeunit "DVI Project Task Handler";
        Context: Codeunit "DVI Sync Context";
        SourceRecordRef: RecordRef;
        DestinationRecordRef: RecordRef;
    begin
        // [GIVEN] A project whose sell-to customer is not coupled
        // Microsoft: the error for the sell-to customer names the bill-to customer
        Customer.Init();
        Customer."No." := 'DVISELL';
        Customer.Insert(false);
        Job.Init();
        Job."No." := 'DVIJOB2';
        Job."Sell-to Customer No." := 'DVISELL';
        Job.Insert(false);
        JobTask."Job No." := 'DVIJOB2';
        JobTask."Job Task No." := 'T1';
        SourceRecordRef.GetTable(JobTask);
        DestinationRecordRef.GetTable(TempFSProjectTask);
        Context.SetToIntegrationTable(true);

        // [WHEN] The project task is sent to Field Service
        asserterror ProjectTaskHandler.BeforeInsert(Context, SourceRecordRef, DestinationRecordRef);

        // [THEN] The error names the sell-to customer
        Assert.ExpectedError('DVISELL');
    end;

    [Test]
    procedure MatchBasedCouplingHonoursTheMappingSettingForSalespeople()
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        GenericHandler: Codeunit "DVI Generic Handler";
        Context: Codeunit "DVI Sync Context";
    begin
        // [GIVEN] The SALESPEOPLE mapping set to create records without a match
        // Microsoft: ShouldCreateNewRecordsInCaseOfNoMatch hard-codes SALESPEOPLE and SALESORDER-ORDER
        if IntegrationTableMapping.Get('SALESPEOPLE') then
            IntegrationTableMapping.Delete(false);
        IntegrationTableMapping := TestLibrary.CreateDataverseMapping('SALESPEOPLE', Database::"Salesperson/Purchaser", Database::"CRM Systemuser", IntegrationTableMapping.Direction::FromIntegrationTable);
        IntegrationTableMapping."Create New in Case of No Match" := true;
        IntegrationTableMapping.Modify(false);
        Context.SetMapping(IntegrationTableMapping);

        // [WHEN] / [THEN] The setting decides
        Assert.IsTrue(GenericHandler.CreateNewOnNoMatch(Context), 'The mapping setting decides, not its name.');
    end;

    local procedure InsertCoupling(TableId: Integer; MappingName: Code[20])
    begin
        InsertCouplingOf(CreateGuid(), TableId, MappingName);
    end;

    local procedure InsertCouplingOf(IntegrationId: Guid; TableId: Integer; MappingName: Code[20]) CRMId: Guid
    var
        CRMIntegrationRecord: Record "CRM Integration Record";
    begin
        CRMId := CreateGuid();
        CRMIntegrationRecord.Init();
        CRMIntegrationRecord."CRM ID" := CRMId;
        CRMIntegrationRecord."Integration ID" := IntegrationId;
        CRMIntegrationRecord."Table ID" := TableId;
        CRMIntegrationRecord."DVI Mapping Name" := MappingName;
        CRMIntegrationRecord.Insert(false);
    end;

    local procedure CountCouplings(var CRMIntegrationRecord: Record "CRM Integration Record"; MappingName: Code[20]): Integer
    var
        FilteredCRMIntegrationRecord: Record "CRM Integration Record";
    begin
        FilteredCRMIntegrationRecord.CopyFilters(CRMIntegrationRecord);
        FilteredCRMIntegrationRecord.FilterGroup(2);
        FilteredCRMIntegrationRecord.SetRange("DVI Mapping Name", MappingName);
        FilteredCRMIntegrationRecord.FilterGroup(0);
        exit(FilteredCRMIntegrationRecord.Count());
    end;
}
