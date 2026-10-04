namespace DataverseIntegration.Core;

using Microsoft.Integration.SyncEngine;

codeunit 80048 "DVI Completion Runner"
{
    Access = Internal;

    trigger OnRun()
    var
        RecordCompletion: Interface "DVI IRecordCompletion";
    begin
        RecordCompletion := Handler;
        RecordCompletion.Complete(Context, LocalRecordRef, IntegrationRecordRef);
    end;

    var
        Context: Codeunit "DVI Sync Context";
        LocalRecordRef: RecordRef;
        IntegrationRecordRef: RecordRef;
        Handler: Enum "DVI Sync Handler";

    /// <summary>
    /// Runs the completion step of one queued record, logs a failure on the job that queued it, and re-stamps the coupling.
    /// </summary>
    /// <param name="TempFollowUpBuffer">The queued completion.</param>
    internal procedure Process(TempFollowUpBuffer: Record "DVI Follow-up Buffer" temporary)
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        MappingResolver: Codeunit "DVI Mapping Resolver";
        CouplingStore: Codeunit "DVI Coupling Store";
        JobLog: Codeunit "DVI Synch. Job Log";
        CompletionRunner: Codeunit "DVI Completion Runner";
        DestinationIsDeleted: Boolean;
    begin
        if not IntegrationTableMapping.Get(TempFollowUpBuffer."Mapping Name") then
            exit;
        LocalRecordRef.Open(IntegrationTableMapping."Table ID");
        if not LocalRecordRef.GetBySystemId(TempFollowUpBuffer."Source System Id") then
            exit;
        if not CouplingStore.FindCoupledRecord(IntegrationTableMapping, LocalRecordRef, IntegrationRecordRef, DestinationIsDeleted) then
            exit;
        if DestinationIsDeleted then
            exit;
        Context.SetMapping(IntegrationTableMapping);
        Context.SetJobId(TempFollowUpBuffer."Job Id");
        Context.SetToIntegrationTable(TempFollowUpBuffer."To Integration Table");
        Context.SetSynchAction(TempFollowUpBuffer."Synch Action");
        Context.SetDestinationInserted(TempFollowUpBuffer."Synch Action" = Enum::"DVI Synch Action"::DVIInsert);
        Handler := MappingResolver.GetHandler(IntegrationTableMapping);
        CompletionRunner.SetState(Context, LocalRecordRef, IntegrationRecordRef, Handler);
        Commit();
        if not CompletionRunner.Run() then begin
            JobLog.LogError(TempFollowUpBuffer."Job Id", LocalRecordRef, IntegrationRecordRef, GetLastErrorText());
            JobLog.Count(TempFollowUpBuffer."Job Id", Enum::"DVI Synch Action"::DVIFail);
            Commit();
            exit;
        end;
        if not LocalRecordRef.GetBySystemId(TempFollowUpBuffer."Source System Id") then
            exit;
        if not CouplingStore.FindCoupledRecord(IntegrationTableMapping, LocalRecordRef, IntegrationRecordRef, DestinationIsDeleted) then
            exit;
        if DestinationIsDeleted then
            exit;
        CouplingStore.UpdateTimestamp(IntegrationTableMapping, LocalRecordRef, IntegrationRecordRef, TempFollowUpBuffer."Job Id", false);
        Commit();
    end;

    /// <summary>
    /// Hands the records and the handler to the instance that runs the completion step.
    /// </summary>
    /// <param name="NewContext">The synchronization context.</param>
    /// <param name="NewLocalRecordRef">The Business Central record.</param>
    /// <param name="NewIntegrationRecordRef">The coupled Dataverse record.</param>
    /// <param name="NewHandler">The handler of the mapping.</param>
    internal procedure SetState(var NewContext: Codeunit "DVI Sync Context"; var NewLocalRecordRef: RecordRef; var NewIntegrationRecordRef: RecordRef; NewHandler: Enum "DVI Sync Handler")
    begin
        Context := NewContext;
        LocalRecordRef := NewLocalRecordRef;
        IntegrationRecordRef := NewIntegrationRecordRef;
        Handler := NewHandler;
    end;
}
