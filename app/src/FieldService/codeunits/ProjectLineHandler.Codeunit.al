namespace DataverseIntegration.FieldService;

using DataverseIntegration.Core;
using Microsoft.Integration.DynamicsFieldService;
using Microsoft.Integration.SyncEngine;
using Microsoft.Projects.Project.Journal;

codeunit 80815 "DVI Project Line Handler" implements "DVI IRecordSync", "DVI IRecordFilter", "DVI IConflictPolicy", "DVI IHandlerScope", "DVI IRecordCompletion"
{
    Access = Public;

    procedure Serves(var Context: Codeunit "DVI Sync Context"): Boolean
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
    begin
        Context.GetMapping(IntegrationTableMapping);
        exit((IntegrationTableMapping."Table ID" = Database::"Job Journal Line") and
          (IntegrationTableMapping."Integration Table ID" in [Database::"FS Work Order Product", Database::"FS Work Order Service"]));
    end;

    procedure DefaultModule(var Context: Codeunit "DVI Sync Context"): Enum "DVI Integration Module"
    begin
        exit(Enum::"DVI Integration Module"::DVIFieldService);
    end;

    procedure IgnoreRecord(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef): Boolean
    var
        FSProjects: Codeunit "DVI FS Projects";
    begin
        exit(FSProjects.IgnoreLine(SourceRecordRef));
    end;

    procedure BeforeTransferFields(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    var
        FSProjects: Codeunit "DVI FS Projects";
    begin
        if not Context.IsToIntegrationTable() then
            FSProjects.SetProjectTask(SourceRecordRef, DestinationRecordRef);
    end;

    procedure AfterTransferFields(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef; var AdditionalFieldsModified: Boolean)
    begin
        AdditionalFieldsModified := false;
    end;

    procedure BeforeInsert(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    var
        FSProjects: Codeunit "DVI FS Projects";
    begin
        if not Context.IsToIntegrationTable() then
            FSProjects.SetUpNewLine(SourceRecordRef, DestinationRecordRef);
    end;

    procedure AfterInsert(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    var
        FSProjects: Codeunit "DVI FS Projects";
    begin
        if Context.IsToIntegrationTable() then
            exit;
        FSProjects.InsertBudgetLine(SourceRecordRef, DestinationRecordRef);
        QueuePosting(Context, SourceRecordRef, DestinationRecordRef, Enum::"DVI Synch Action"::DVIInsert);
    end;

    procedure BeforeModify(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    var
        FSProjects: Codeunit "DVI FS Projects";
    begin
        if not Context.IsToIntegrationTable() then
            FSProjects.UpdateCorrelatedLine(SourceRecordRef, DestinationRecordRef);
    end;

    procedure AfterModify(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    begin
        if not Context.IsToIntegrationTable() then
            QueuePosting(Context, SourceRecordRef, DestinationRecordRef, Enum::"DVI Synch Action"::DVIModify);
    end;

    procedure Unchanged(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef)
    var
        FSProjects: Codeunit "DVI FS Projects";
    begin
        if Context.IsToIntegrationTable() then
            exit;
        FSProjects.UpdateCorrelatedLine(SourceRecordRef, DestinationRecordRef);
        QueuePosting(Context, SourceRecordRef, DestinationRecordRef, Enum::"DVI Synch Action"::DVIIgnoreUnchanged);
    end;

    procedure Complete(var Context: Codeunit "DVI Sync Context"; var LocalRecordRef: RecordRef; var IntegrationRecordRef: RecordRef)
    var
        FSProjects: Codeunit "DVI FS Projects";
    begin
        if FSProjects.IsDueForPosting(IntegrationRecordRef) then
            FSProjects.Post(IntegrationRecordRef, LocalRecordRef);
    end;

    procedure ResolveUpdateConflict(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef; var SkipRecord: Boolean): Boolean
    var
        MappingConflictPolicy: Codeunit "DVI Mapping Conflict Policy";
    begin
        exit(MappingConflictPolicy.ResolveUpdateConflict(Context, SourceRecordRef, DestinationRecordRef, SkipRecord));
    end;

    procedure ResolveDeletionConflict(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef): Enum "DVI Deletion Outcome"
    var
        FSProjects: Codeunit "DVI FS Projects";
    begin
        exit(FSProjects.ResolveDeletedLine(SourceRecordRef));
    end;

    local procedure QueuePosting(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef; SynchAction: Enum "DVI Synch Action")
    var
        FSProjects: Codeunit "DVI FS Projects";
    begin
        if not FSProjects.IsDueForPosting(SourceRecordRef) then
            exit;
        Context.AddCompletion(Context.GetMappingName(), DestinationRecordRef.Field(DestinationRecordRef.SystemIdNo()).Value(), false, SynchAction);
    end;
}
