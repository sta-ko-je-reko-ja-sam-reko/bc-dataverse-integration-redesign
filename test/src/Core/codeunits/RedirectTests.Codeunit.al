namespace DataverseIntegration.Test;

using DataverseIntegration.Core;
using Microsoft.Integration.D365Sales;
using Microsoft.Integration.SyncEngine;
using Microsoft.Sales.Customer;
using System.TestLibraries.Utilities;

codeunit 84016 "DVI Redirect Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TestLibrary: Codeunit "DVI Test Library";

    [Test]
    procedure DisabledFeatureLeavesRedirectToMicrosoft()
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        Redirect: Codeunit "DVI Redirect";
        Opened: Boolean;
        Handled: Boolean;
    begin
        // [GIVEN] A switched account mapping and the feature off
        TestLibrary.SetFeatureEnabled(false);
        TestLibrary.CreateDataverseMapping('DVITEST', Database::Customer, Database::"CRM Account", IntegrationTableMapping.Direction::Bidirectional);
        TestLibrary.AssignHandler('DVITEST', Enum::"DVI Sync Handler"::DVIGeneric);

        // [WHEN] A Dataverse link to an account arrives
        Redirect.OpenCoupledRecord(CreateGuid(), 'account', Opened, Handled);

        // [THEN] The standard redirect handles it
        Assert.IsFalse(Handled, 'A disabled feature must not handle links.');
    end;

    [Test]
    procedure UnswitchedMappingLeavesRedirectToMicrosoft()
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        Redirect: Codeunit "DVI Redirect";
        Opened: Boolean;
        Handled: Boolean;
    begin
        // [GIVEN] The feature on and an account mapping left on Microsoft
        TestLibrary.SetFeatureEnabled(true);
        TestLibrary.CreateDataverseMapping('DVITEST', Database::Customer, Database::"CRM Account", IntegrationTableMapping.Direction::Bidirectional);

        // [WHEN] A Dataverse link to an account arrives
        Redirect.OpenCoupledRecord(CreateGuid(), 'account', Opened, Handled);

        // [THEN] The standard redirect handles it
        Assert.IsFalse(Handled, 'Links of unswitched mappings stay with the standard redirect.');
    end;

    [Test]
    procedure LinkHandledByAnotherAppIsLeftAlone()
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        Redirect: Codeunit "DVI Redirect";
        Opened: Boolean;
        Handled: Boolean;
    begin
        // [GIVEN] A switched account mapping and a link another app already handled
        TestLibrary.SetFeatureEnabled(true);
        TestLibrary.CreateDataverseMapping('DVITEST', Database::Customer, Database::"CRM Account", IntegrationTableMapping.Direction::Bidirectional);
        TestLibrary.AssignHandler('DVITEST', Enum::"DVI Sync Handler"::DVIGeneric);
        Handled := true;
        Opened := true;

        // [WHEN] The redirect is reached
        Redirect.OpenCoupledRecord(CreateGuid(), 'account', Opened, Handled);

        // [THEN] The other app's result is kept
        Assert.IsTrue(Opened, 'The result of the other app must be kept.');
    end;
}
