namespace DataverseIntegration.Core;

using Microsoft.Integration.Dataverse;
using Microsoft.Integration.SyncEngine;
using System.Reflection;

codeunit 80032 "DVI Standard Record Actions" implements "DVI IIntegrationRecordView", "DVI ISynchronizeAction", "DVI ICouplingAction", "DVI ICreateAction", "DVI ISynchLogView", "DVI IStatisticsAction"
{
    Access = Public;

    var
        DirectionQst: Label 'Send data update to Dataverse,Get data update from Dataverse';
        SynchronizationQueuedMsg: Label 'The synchronization of %1 records has been scheduled. You can follow it in the synchronization log.', Comment = '%1 = number of records';
        NothingToSynchronizeMsg: Label 'None of the selected records is coupled, so there is nothing to synchronize.';
        NoListPageErr: Label 'There is no list page for the Dataverse table %1.', Comment = '%1 = table caption';

    procedure CanOpenIntegrationRecord(var Context: Codeunit "DVI Record Action Context"): Boolean
    begin
        exit(Context.IsCoupled() and Context.AllowsToIntegrationTable());
    end;

    procedure OpenIntegrationRecord(var Context: Codeunit "DVI Record Action Context")
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        CRMIntegrationManagement: Codeunit "CRM Integration Management";
    begin
        Context.GetMapping(IntegrationTableMapping);
        Hyperlink(CRMIntegrationManagement.GetCRMEntityUrlFromCRMID(
          IntegrationTableMapping."Table ID", IntegrationTableMapping."Integration Table ID", Context.GetIntegrationId()));
    end;

    procedure CanSynchronize(var Context: Codeunit "DVI Record Action Context"): Boolean
    begin
        exit(Context.HasMapping());
    end;

    procedure Synchronize(var Context: Codeunit "DVI Record Action Context"; var SelectedRecordRef: RecordRef)
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        CRMIntegrationManagement: Codeunit "CRM Integration Management";
        SystemIds: List of [Guid];
        IntegrationIds: List of [Guid];
        Direction: Integer;
    begin
        Context.GetMapping(IntegrationTableMapping);
        if (SelectedRecordRef.Count() = 1) and not Context.IsCoupled() then begin
            CRMIntegrationManagement.DefineCoupling(Context.GetRecordId());
            exit;
        end;
        CollectCoupledRecords(SelectedRecordRef, SystemIds, IntegrationIds);
        if SystemIds.Count() = 0 then begin
            Message(NothingToSynchronizeMsg);
            exit;
        end;
        if not ChooseDirection(IntegrationTableMapping, Direction) then
            exit;
        CRMIntegrationManagement.EnqueueSyncJob(IntegrationTableMapping, SystemIds, IntegrationIds, Direction, true);
        Message(SynchronizationQueuedMsg, SystemIds.Count());
    end;

    procedure CanSetUpCoupling(var Context: Codeunit "DVI Record Action Context"): Boolean
    begin
        exit(Context.HasMapping());
    end;

    procedure SetUpCoupling(var Context: Codeunit "DVI Record Action Context")
    var
        CRMIntegrationManagement: Codeunit "CRM Integration Management";
    begin
        CRMIntegrationManagement.DefineCoupling(Context.GetRecordId());
    end;

    procedure CanDeleteCoupling(var Context: Codeunit "DVI Record Action Context"): Boolean
    begin
        exit(Context.IsCoupled());
    end;

    procedure DeleteCoupling(var Context: Codeunit "DVI Record Action Context"; var SelectedRecordRef: RecordRef)
    var
        CRMCouplingManagement: Codeunit "CRM Coupling Management";
    begin
        CRMCouplingManagement.RemoveCoupling(SelectedRecordRef);
    end;

    procedure CanMatchBasedCoupling(var Context: Codeunit "DVI Record Action Context"): Boolean
    begin
        exit(Context.HasMapping());
    end;

    procedure MatchBasedCoupling(var Context: Codeunit "DVI Record Action Context"; var SelectedRecordRef: RecordRef)
    var
        CRMIntegrationManagement: Codeunit "CRM Integration Management";
    begin
        CRMIntegrationManagement.MatchBasedCoupling(SelectedRecordRef);
    end;

    procedure CanCreateInDataverse(var Context: Codeunit "DVI Record Action Context"): Boolean
    begin
        exit(Context.AllowsToIntegrationTable() and not Context.IsCoupled());
    end;

    procedure CreateInDataverse(var Context: Codeunit "DVI Record Action Context"; var SelectedRecordRef: RecordRef)
    var
        CRMIntegrationManagement: Codeunit "CRM Integration Management";
    begin
        CRMIntegrationManagement.CreateNewRecordsInCRM(SelectedRecordRef);
    end;

    procedure CanCreateInBusinessCentral(var Context: Codeunit "DVI Record Action Context"): Boolean
    begin
        exit(Context.AllowsFromIntegrationTable());
    end;

    procedure CreateInBusinessCentral(var Context: Codeunit "DVI Record Action Context")
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        TableMetadata: Record "Table Metadata";
    begin
        Context.GetMapping(IntegrationTableMapping);
        TableMetadata.SetLoadFields(Caption, LookupPageID);
        TableMetadata.Get(IntegrationTableMapping."Integration Table ID");
        if TableMetadata.LookupPageID = 0 then
            Error(NoListPageErr, TableMetadata.Caption);
        Page.Run(TableMetadata.LookupPageID);
    end;

    procedure CanShowLog(var Context: Codeunit "DVI Record Action Context"): Boolean
    begin
        exit(Context.HasMapping());
    end;

    procedure ShowLog(var Context: Codeunit "DVI Record Action Context")
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        CRMIntegrationRecord: Record "CRM Integration Record";
    begin
        Context.GetMapping(IntegrationTableMapping);
        if CRMIntegrationRecord.FindByRecordID(Context.GetRecordId()) then
            IntegrationTableMapping.ShowLog(CRMIntegrationRecord.GetLatestJobIDFilter())
        else
            IntegrationTableMapping.ShowLog('');
    end;

    procedure CanUpdateStatistics(var Context: Codeunit "DVI Record Action Context"): Boolean
    begin
        exit(false);
    end;

    procedure UpdateStatistics(var Context: Codeunit "DVI Record Action Context")
    begin
    end;

    local procedure CollectCoupledRecords(var SelectedRecordRef: RecordRef; var SystemIds: List of [Guid]; var IntegrationIds: List of [Guid])
    var
        CRMIntegrationRecord: Record "CRM Integration Record";
        IntegrationId: Guid;
    begin
        if not SelectedRecordRef.FindSet() then
            exit;
        repeat
            if CRMIntegrationRecord.FindIDFromRecordID(SelectedRecordRef.RecordId(), IntegrationId) then begin
                SystemIds.Add(SelectedRecordRef.Field(SelectedRecordRef.SystemIdNo()).Value());
                IntegrationIds.Add(IntegrationId);
            end;
        until SelectedRecordRef.Next() = 0;
    end;

    local procedure ChooseDirection(IntegrationTableMapping: Record "Integration Table Mapping"; var Direction: Integer): Boolean
    begin
        if IntegrationTableMapping.Direction <> IntegrationTableMapping.Direction::Bidirectional then begin
            Direction := IntegrationTableMapping.Direction;
            exit(true);
        end;
        case StrMenu(DirectionQst, 1) of
            1:
                Direction := IntegrationTableMapping.Direction::ToIntegrationTable;
            2:
                Direction := IntegrationTableMapping.Direction::FromIntegrationTable;
            else
                exit(false);
        end;
        exit(true);
    end;
}
