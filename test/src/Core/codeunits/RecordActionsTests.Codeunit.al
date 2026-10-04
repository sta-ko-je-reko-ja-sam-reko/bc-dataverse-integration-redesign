namespace DataverseIntegration.Test;

using DataverseIntegration.Core;
using Microsoft.Integration.D365Sales;
using Microsoft.Integration.Dataverse;
using Microsoft.Integration.SyncEngine;
using Microsoft.Sales.Customer;
using System.TestLibraries.Utilities;

codeunit 84015 "DVI Record Actions Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLibrary: Codeunit "DVI Test Library";

    [Test]
    procedure OpenIsOfferedOnlyForCoupledRecordsSentToDataverse()
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        StandardRecordActions: Codeunit "DVI Standard Record Actions";
        Context: Codeunit "DVI Record Action Context";
    begin
        // [GIVEN] A coupled record on a mapping that only gets data from Dataverse
        IntegrationTableMapping.Direction := IntegrationTableMapping.Direction::FromIntegrationTable;
        Context.SetMapping(IntegrationTableMapping);
        Context.SetCoupling(CreateGuid());

        // [WHEN] / [THEN] Opening the Dataverse record is not offered
        Assert.IsFalse(StandardRecordActions.CanOpenIntegrationRecord(Context), 'From Integration Table mappings do not open Dataverse records.');

        // [GIVEN] The same record on a bidirectional mapping
        IntegrationTableMapping.Direction := IntegrationTableMapping.Direction::Bidirectional;
        Context.SetMapping(IntegrationTableMapping);
        Context.SetCoupling(CreateGuid());

        // [THEN] It is offered
        Assert.IsTrue(StandardRecordActions.CanOpenIntegrationRecord(Context), 'Bidirectional mappings open coupled Dataverse records.');
    end;

    [Test]
    procedure UncoupledRecordIsNotOpenedInDataverse()
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        StandardRecordActions: Codeunit "DVI Standard Record Actions";
        Context: Codeunit "DVI Record Action Context";
    begin
        // [GIVEN] An uncoupled record on a bidirectional mapping
        IntegrationTableMapping.Direction := IntegrationTableMapping.Direction::Bidirectional;
        Context.SetMapping(IntegrationTableMapping);

        // [WHEN] / [THEN] Opening is not offered, creating in Dataverse is
        Assert.IsFalse(StandardRecordActions.CanOpenIntegrationRecord(Context), 'Nothing to open.');
        Assert.IsTrue(StandardRecordActions.CanCreateInDataverse(Context), 'An uncoupled record can be created in Dataverse.');
        Assert.IsFalse(StandardRecordActions.CanDeleteCoupling(Context), 'No coupling to delete.');
    end;

    [Test]
    procedure CreateActionsFollowTheMappingDirection()
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        StandardRecordActions: Codeunit "DVI Standard Record Actions";
        Context: Codeunit "DVI Record Action Context";
    begin
        // [GIVEN] A mapping that only sends data to Dataverse
        IntegrationTableMapping.Direction := IntegrationTableMapping.Direction::ToIntegrationTable;
        Context.SetMapping(IntegrationTableMapping);

        // [THEN] Records can be created in Dataverse but not from it
        Assert.IsTrue(StandardRecordActions.CanCreateInDataverse(Context), 'Create in Dataverse');
        Assert.IsFalse(StandardRecordActions.CanCreateInBusinessCentral(Context), 'Create in Business Central');

        // [GIVEN] A mapping that only gets data from Dataverse
        IntegrationTableMapping.Direction := IntegrationTableMapping.Direction::FromIntegrationTable;
        Context.SetMapping(IntegrationTableMapping);

        // [THEN] Records can be created from Dataverse but not in it
        Assert.IsFalse(StandardRecordActions.CanCreateInDataverse(Context), 'Create in Dataverse');
        Assert.IsTrue(StandardRecordActions.CanCreateInBusinessCentral(Context), 'Create in Business Central');
    end;

    [Test]
    procedure RecordWithoutMappingOffersNothing()
    var
        StandardRecordActions: Codeunit "DVI Standard Record Actions";
        Context: Codeunit "DVI Record Action Context";
    begin
        // [GIVEN] A record whose table has no integration table mapping
        // [WHEN] / [THEN] No action is offered
        Assert.IsFalse(StandardRecordActions.CanSynchronize(Context), 'Synchronize');
        Assert.IsFalse(StandardRecordActions.CanSetUpCoupling(Context), 'Set up coupling');
        Assert.IsFalse(StandardRecordActions.CanShowLog(Context), 'Log');
        Assert.IsFalse(StandardRecordActions.CanCreateInDataverse(Context), 'Create in Dataverse');
        Assert.IsFalse(StandardRecordActions.CanCreateInBusinessCentral(Context), 'Create in Business Central');
    end;

    [Test]
    procedure CouplingMappingWinsOverTableMappings()
    var
        Customer: Record Customer;
        IntegrationTableMapping: Record "Integration Table Mapping";
        CRMIntegrationRecord: Record "CRM Integration Record";
        RecordMappingResolver: Codeunit "DVI Record Mapping Resolver";
        Context: Codeunit "DVI Record Action Context";
        IntegrationId: Guid;
    begin
        // [GIVEN] Two mappings on the Customer table and a customer coupled through the second one
        TestLibrary.CreateDataverseMapping('DVIFIRST', Database::Customer, Database::"CRM Account", IntegrationTableMapping.Direction::Bidirectional);
        TestLibrary.CreateDataverseMapping('DVISECOND', Database::Customer, Database::"CRM Account", IntegrationTableMapping.Direction::ToIntegrationTable);
        Customer.Init();
        Customer."No." := 'DVITEST01';
        Customer.Insert(false);
        IntegrationId := CreateGuid();
        CRMIntegrationRecord.Init();
        CRMIntegrationRecord."CRM ID" := IntegrationId;
        CRMIntegrationRecord."Integration ID" := Customer.SystemId;
        CRMIntegrationRecord."Table ID" := Database::Customer;
        CRMIntegrationRecord."DVI Mapping Name" := 'DVISECOND';
        CRMIntegrationRecord.Insert(false);

        // [WHEN] The customer's actions are resolved
        Assert.IsTrue(RecordMappingResolver.Resolve(Customer.RecordId(), 0, Context), 'A mapping must be found.');

        // [THEN] The mapping stamped on the coupling is used, not the first mapping of the table
        Context.GetMapping(IntegrationTableMapping);
        Assert.AreEqual('DVISECOND', IntegrationTableMapping.Name, 'Mapping');
        Assert.IsTrue(Context.IsCoupled(), 'Coupled');
        Assert.AreEqual(IntegrationId, Context.GetIntegrationId(), 'Dataverse record');
    end;

    [Test]
    procedure DisabledFeatureShowsOnlyStandardActions()
    var
        Customer: Record Customer;
        IntegrationTableMapping: Record "Integration Table Mapping";
        RecordActions: Codeunit "DVI Record Actions";
    begin
        // [GIVEN] The feature is off and the customer table has a mapping
        TestLibrary.SetFeatureEnabled(false);
        TestLibrary.CreateDataverseMapping('DVITEST', Database::Customer, Database::"CRM Account", IntegrationTableMapping.Direction::Bidirectional);
        Customer.Init();
        Customer."No." := 'DVITEST01';
        Customer.Insert(false);

        // [WHEN] A page refreshes its actions
        RecordActions.Refresh(Customer.RecordId());

        // [THEN] The redesigned group is hidden and the standard actions stay
        Assert.IsFalse(RecordActions.IsActive(), 'Standard actions must stay visible.');
        Assert.IsFalse(RecordActions.ShowGroup(), 'The redesigned group must be hidden.');
    end;

    [Test]
    procedure EnabledFeatureReplacesStandardActions()
    var
        Customer: Record Customer;
        IntegrationTableMapping: Record "Integration Table Mapping";
        RecordActions: Codeunit "DVI Record Actions";
    begin
        // [GIVEN] The feature is on and the customer table has a bidirectional mapping left on Microsoft
        TestLibrary.SetFeatureEnabled(true);
        TestLibrary.CreateDataverseMapping('DVITEST', Database::Customer, Database::"CRM Account", IntegrationTableMapping.Direction::Bidirectional);
        Customer.Init();
        Customer."No." := 'DVITEST01';
        Customer.Insert(false);

        // [WHEN] A page refreshes its actions
        RecordActions.Refresh(Customer.RecordId());

        // [THEN] The redesigned group replaces the standard actions, also for an unswitched mapping
        Assert.IsTrue(RecordActions.IsActive(), 'The standard actions must be hidden.');
        Assert.IsTrue(RecordActions.ShowGroup(), 'The redesigned group must be shown.');
        Assert.IsTrue(RecordActions.CanSynchronize(), 'Synchronize');
        Assert.IsFalse(RecordActions.CanOpen(), 'An uncoupled record has nothing to open.');
    end;
}
