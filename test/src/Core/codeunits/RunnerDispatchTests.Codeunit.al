namespace DataverseIntegration.Test;

using DataverseIntegration.Core;
using Microsoft.Integration.D365Sales;
using Microsoft.Integration.SyncEngine;
using Microsoft.Sales.Customer;
using System.TestLibraries.Utilities;

codeunit 84013 "DVI Runner Dispatch Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLibrary: Codeunit "DVI Test Library";

    [Test]
    procedure SwitchedMappingIsTakenOver()
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        FakeTableSynch: Codeunit "DVI Fake Table Synch.";
        Handled: Boolean;
    begin
        // [GIVEN] The feature is on and the mapping is switched; the engine is a fake
        Initialize(FakeTableSynch);
        TestLibrary.SetFeatureEnabled(true);
        IntegrationTableMapping := TestLibrary.CreateDataverseMapping('DVITEST', Database::Customer, Database::"CRM Account", IntegrationTableMapping.Direction::Bidirectional);
        TestLibrary.AssignHandler('DVITEST', Enum::"DVI Sync Handler"::DVIGeneric);

        // [WHEN] The standard runner is about to run the mapping
        RunDispatch(IntegrationTableMapping, Handled);

        // [THEN] The redesigned engine ran it and the standard runner is told to do nothing
        Assert.IsTrue(Handled, 'The run must be marked as handled.');
        Assert.AreEqual(1, FakeTableSynch.GetCallCount(), 'The redesigned engine must run once.');
        Assert.AreEqual('DVITEST', FakeTableSynch.GetLastMappingName(), 'Mapping');
    end;

    [Test]
    procedure UnswitchedMappingIsLeftToMicrosoft()
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        FakeTableSynch: Codeunit "DVI Fake Table Synch.";
        Handled: Boolean;
    begin
        // [GIVEN] The feature is on but the mapping is not switched
        Initialize(FakeTableSynch);
        TestLibrary.SetFeatureEnabled(true);
        IntegrationTableMapping := TestLibrary.CreateDataverseMapping('DVITEST', Database::Customer, Database::"CRM Account", IntegrationTableMapping.Direction::Bidirectional);

        // [WHEN] The standard runner is about to run the mapping
        RunDispatch(IntegrationTableMapping, Handled);

        // [THEN] The standard runner keeps the run
        Assert.IsFalse(Handled, 'An unswitched mapping must not be taken over.');
        Assert.AreEqual(0, FakeTableSynch.GetCallCount(), 'The redesigned engine must not run.');
    end;

    [Test]
    procedure DisabledFeatureTakesNothingOver()
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        FakeTableSynch: Codeunit "DVI Fake Table Synch.";
        Handled: Boolean;
    begin
        // [GIVEN] The mapping is switched but the feature is off
        Initialize(FakeTableSynch);
        TestLibrary.SetFeatureEnabled(false);
        IntegrationTableMapping := TestLibrary.CreateDataverseMapping('DVITEST', Database::Customer, Database::"CRM Account", IntegrationTableMapping.Direction::Bidirectional);
        TestLibrary.AssignHandler('DVITEST', Enum::"DVI Sync Handler"::DVIGeneric);

        // [WHEN] The standard runner is about to run the mapping
        RunDispatch(IntegrationTableMapping, Handled);

        // [THEN] Everything behaves exactly as Microsoft ships it
        Assert.IsFalse(Handled, 'A disabled feature must not take runs over.');
        Assert.AreEqual(0, FakeTableSynch.GetCallCount(), 'The redesigned engine must not run.');
    end;

    [Test]
    procedure RunHandledByAnotherAppIsNotTakenOver()
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        FakeTableSynch: Codeunit "DVI Fake Table Synch.";
        Handled: Boolean;
    begin
        // [GIVEN] A switched mapping whose run another subscriber already handled
        Initialize(FakeTableSynch);
        TestLibrary.SetFeatureEnabled(true);
        IntegrationTableMapping := TestLibrary.CreateDataverseMapping('DVITEST', Database::Customer, Database::"CRM Account", IntegrationTableMapping.Direction::Bidirectional);
        TestLibrary.AssignHandler('DVITEST', Enum::"DVI Sync Handler"::DVIGeneric);
        Handled := true;

        // [WHEN] The dispatch is reached
        RunDispatch(IntegrationTableMapping, Handled);

        // [THEN] It does not run the mapping a second time
        Assert.AreEqual(0, FakeTableSynch.GetCallCount(), 'An already handled run must be left alone.');
    end;

    local procedure Initialize(var FakeTableSynch: Codeunit "DVI Fake Table Synch.")
    var
        ServiceLocator: Codeunit "DVI Service Locator";
    begin
        FakeTableSynch.Reset();
        ServiceLocator.ImplementTableSynch(FakeTableSynch);
    end;

    local procedure RunDispatch(IntegrationTableMapping: Record "Integration Table Mapping"; var Handled: Boolean)
    var
        ServiceLocator: Codeunit "DVI Service Locator";
    begin
        ServiceLocator.RunnerDispatch().OnBeforeSynchRun(IntegrationTableMapping, Handled);
    end;
}
