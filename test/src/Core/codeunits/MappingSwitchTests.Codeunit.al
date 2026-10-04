namespace DataverseIntegration.Test;

using DataverseIntegration.Core;
using Microsoft.Integration.D365Sales;
using Microsoft.Integration.SyncEngine;
using Microsoft.Sales.Customer;
using System.TestLibraries.Utilities;

codeunit 84012 "DVI Mapping Switch Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLibrary: Codeunit "DVI Test Library";
        NotStandardRunnerErr: Label 'instead of the standard Dataverse synchronization';

    [Test]
    procedure SwitchingAssignsGenericHandlerAndDataverseModule()
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        MappingAssignment: Record "DVI Mapping Assignment";
        DefaultAssignment: Codeunit "DVI Default Assignment";
    begin
        // [GIVEN] A Dataverse mapping run by the standard runner
        IntegrationTableMapping := TestLibrary.CreateDataverseMapping('DVITEST', Database::Customer, Database::"CRM Account", IntegrationTableMapping.Direction::Bidirectional);

        // [WHEN] It is switched to the redesigned synchronization
        DefaultAssignment.SwitchToRedesigned(IntegrationTableMapping);

        // [THEN] It gets the Generic handler and the Dataverse module
        MappingAssignment.Get('DVITEST');
        Assert.AreEqual(Enum::"DVI Sync Handler"::DVIGeneric, MappingAssignment.Handler, 'Handler');
        Assert.AreEqual(Enum::"DVI Integration Module"::DVIDataverse, MappingAssignment.Module, 'Module');
    end;

    [Test]
    procedure SwitchingBackKeepsTheAssignmentWithMicrosoftHandler()
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        MappingAssignment: Record "DVI Mapping Assignment";
        DefaultAssignment: Codeunit "DVI Default Assignment";
    begin
        // [GIVEN] A switched mapping
        IntegrationTableMapping := TestLibrary.CreateDataverseMapping('DVITEST', Database::Customer, Database::"CRM Account", IntegrationTableMapping.Direction::Bidirectional);
        DefaultAssignment.SwitchToRedesigned(IntegrationTableMapping);

        // [WHEN] It is switched back to the standard synchronization
        DefaultAssignment.SwitchToStandard(IntegrationTableMapping);

        // [THEN] The assignment stays and names the Microsoft handler
        MappingAssignment.Get('DVITEST');
        Assert.AreEqual(Enum::"DVI Sync Handler"::DVIMicrosoft, MappingAssignment.Handler, 'Handler');
    end;

    [Test]
    procedure MappingWithCustomRunnerCannotBeSwitched()
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        DefaultAssignment: Codeunit "DVI Default Assignment";
    begin
        // [GIVEN] A Dataverse mapping that runs a custom synchronization codeunit
        IntegrationTableMapping := TestLibrary.CreateDataverseMapping('DVITEST', Database::Customer, Database::"CRM Account", IntegrationTableMapping.Direction::Bidirectional);
        IntegrationTableMapping."Synch. Codeunit ID" := Codeunit::"DVI Fake Table Synch.";
        IntegrationTableMapping.Modify(false);

        // [WHEN] It is switched
        asserterror DefaultAssignment.SwitchToRedesigned(IntegrationTableMapping);

        // [THEN] The switch is refused, because the takeover hooks only the standard runner
        Assert.ExpectedError(NotStandardRunnerErr);
    end;

    [Test]
    procedure TemporaryMappingResolvesToItsParentAssignment()
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        TempChildMapping: Record "Integration Table Mapping" temporary;
        MappingResolver: Codeunit "DVI Mapping Resolver";
    begin
        // [GIVEN] A switched mapping and the temporary copy Synchronize now creates from it
        IntegrationTableMapping := TestLibrary.CreateDataverseMapping('DVITEST', Database::Customer, Database::"CRM Account", IntegrationTableMapping.Direction::Bidirectional);
        TestLibrary.AssignHandler('DVITEST', Enum::"DVI Sync Handler"::DVIGeneric);
        TempChildMapping.Name := 'DVITEST-COPY';
        TempChildMapping."Parent Name" := 'DVITEST';

        // [WHEN] / [THEN] The copy runs the parent's handler and couplings carry the parent's name
        Assert.IsTrue(MappingResolver.IsSwitched(TempChildMapping), 'The copy must be switched like its parent.');
        Assert.AreEqual('DVITEST', MappingResolver.GetCouplingMappingName(TempChildMapping), 'Coupling mapping name');
    end;

    [Test]
    procedure MappingWithoutAssignmentIsNotSwitched()
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        MappingResolver: Codeunit "DVI Mapping Resolver";
    begin
        // [GIVEN] A mapping nobody switched
        IntegrationTableMapping := TestLibrary.CreateDataverseMapping('DVITEST', Database::Customer, Database::"CRM Account", IntegrationTableMapping.Direction::Bidirectional);

        // [WHEN] / [THEN] It stays with the Microsoft handler
        Assert.IsFalse(MappingResolver.IsSwitched(IntegrationTableMapping), 'Unassigned mappings must stay standard.');
        Assert.AreEqual(Enum::"DVI Sync Handler"::DVIMicrosoft, MappingResolver.GetHandler(IntegrationTableMapping), 'Handler');
    end;
}
