namespace DataverseIntegration.Test;

using DataverseIntegration.Core;
using Microsoft.Integration.D365Sales;
using Microsoft.Integration.SyncEngine;
using Microsoft.Sales.Customer;
using System.TestLibraries.Utilities;

codeunit 84010 "DVI Conflict Policy Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure UpdateConflictGetFromIntegrationOverwritesFromDataverse()
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        TempCRMAccount: Record "CRM Account" temporary;
        ConflictPolicy: Codeunit "DVI Mapping Conflict Policy";
        Context: Codeunit "DVI Sync Context";
        SourceRecordRef: RecordRef;
        DestinationRecordRef: RecordRef;
        SkipRecord: Boolean;
    begin
        // [GIVEN] A mapping that resolves update conflicts by getting the Dataverse value
        IntegrationTableMapping."Table ID" := Database::Customer;
        IntegrationTableMapping."Integration Table ID" := Database::"CRM Account";
        IntegrationTableMapping."Update-Conflict Resolution" := IntegrationTableMapping."Update-Conflict Resolution"::"Get Update from Integration";
        Context.SetMapping(IntegrationTableMapping);
        SourceRecordRef.GetTable(TempCRMAccount);

        // [WHEN] A Dataverse record conflicts with its coupled customer
        // [THEN] The conflict is resolved and the record is not skipped
        Assert.IsTrue(ConflictPolicy.ResolveUpdateConflict(Context, SourceRecordRef, DestinationRecordRef, SkipRecord), 'The conflict must be resolved.');
        Assert.IsFalse(SkipRecord, 'The Dataverse value must overwrite the Business Central value.');
    end;

    [Test]
    procedure UpdateConflictGetFromIntegrationSkipsBusinessCentralSource()
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        TempCustomer: Record Customer temporary;
        ConflictPolicy: Codeunit "DVI Mapping Conflict Policy";
        Context: Codeunit "DVI Sync Context";
        SourceRecordRef: RecordRef;
        DestinationRecordRef: RecordRef;
        SkipRecord: Boolean;
    begin
        // [GIVEN] A mapping that resolves update conflicts by getting the Dataverse value
        IntegrationTableMapping."Table ID" := Database::Customer;
        IntegrationTableMapping."Integration Table ID" := Database::"CRM Account";
        IntegrationTableMapping."Update-Conflict Resolution" := IntegrationTableMapping."Update-Conflict Resolution"::"Get Update from Integration";
        Context.SetMapping(IntegrationTableMapping);
        SourceRecordRef.GetTable(TempCustomer);

        // [WHEN] A customer conflicts with its coupled Dataverse account
        // [THEN] The conflict is resolved by skipping the customer
        Assert.IsTrue(ConflictPolicy.ResolveUpdateConflict(Context, SourceRecordRef, DestinationRecordRef, SkipRecord), 'The conflict must be resolved.');
        Assert.IsTrue(SkipRecord, 'The Business Central change must not overwrite Dataverse.');
    end;

    [Test]
    procedure UpdateConflictWithoutResolutionIsNotResolved()
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        TempCustomer: Record Customer temporary;
        ConflictPolicy: Codeunit "DVI Mapping Conflict Policy";
        Context: Codeunit "DVI Sync Context";
        SourceRecordRef: RecordRef;
        DestinationRecordRef: RecordRef;
        SkipRecord: Boolean;
    begin
        // [GIVEN] A mapping without an update-conflict resolution
        IntegrationTableMapping."Table ID" := Database::Customer;
        IntegrationTableMapping."Integration Table ID" := Database::"CRM Account";
        Context.SetMapping(IntegrationTableMapping);
        SourceRecordRef.GetTable(TempCustomer);

        // [WHEN] / [THEN] The conflict stays unresolved, so the record fails
        Assert.IsFalse(ConflictPolicy.ResolveUpdateConflict(Context, SourceRecordRef, DestinationRecordRef, SkipRecord), 'Without a resolution the conflict must not be resolved.');
    end;

    [Test]
    procedure DeletionConflictFollowsMappingSetting()
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        TempCustomer: Record Customer temporary;
        ConflictPolicy: Codeunit "DVI Mapping Conflict Policy";
        Context: Codeunit "DVI Sync Context";
        SourceRecordRef: RecordRef;
    begin
        SourceRecordRef.GetTable(TempCustomer);

        // [GIVEN] Each deletion-conflict resolution of the mapping
        // [WHEN] A source record is coupled to a deleted record
        // [THEN] The outcome matches the setting
        IntegrationTableMapping."Deletion-Conflict Resolution" := IntegrationTableMapping."Deletion-Conflict Resolution"::"Restore Records";
        Context.SetMapping(IntegrationTableMapping);
        Assert.AreEqual(Enum::"DVI Deletion Outcome"::DVIRestoreRecord, ConflictPolicy.ResolveDeletionConflict(Context, SourceRecordRef), 'Restore records');

        IntegrationTableMapping."Deletion-Conflict Resolution" := IntegrationTableMapping."Deletion-Conflict Resolution"::"Remove Coupling";
        Context.SetMapping(IntegrationTableMapping);
        Assert.AreEqual(Enum::"DVI Deletion Outcome"::DVIRemoveCoupling, ConflictPolicy.ResolveDeletionConflict(Context, SourceRecordRef), 'Remove coupling');

        IntegrationTableMapping."Deletion-Conflict Resolution" := IntegrationTableMapping."Deletion-Conflict Resolution"::None;
        Context.SetMapping(IntegrationTableMapping);
        Assert.AreEqual(Enum::"DVI Deletion Outcome"::DVIFail, ConflictPolicy.ResolveDeletionConflict(Context, SourceRecordRef), 'No resolution');
    end;
}
