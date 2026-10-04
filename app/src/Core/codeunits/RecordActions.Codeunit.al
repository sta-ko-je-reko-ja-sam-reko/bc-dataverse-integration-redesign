namespace DataverseIntegration.Core;

using Microsoft.Integration.SyncEngine;

codeunit 80033 "DVI Record Actions"
{
    Access = Public;

    var
        Context: Codeunit "DVI Record Action Context";
        IntegrationRecordView: Interface "DVI IIntegrationRecordView";
        SynchronizeAction: Interface "DVI ISynchronizeAction";
        CouplingAction: Interface "DVI ICouplingAction";
        CreateAction: Interface "DVI ICreateAction";
        SynchLogView: Interface "DVI ISynchLogView";
        StatisticsAction: Interface "DVI IStatisticsAction";
        Active: Boolean;
        ShowOpen: Boolean;
        ShowSynchronize: Boolean;
        ShowSetUpCoupling: Boolean;
        ShowDeleteCoupling: Boolean;
        ShowMatchBasedCoupling: Boolean;
        ShowCreateInDataverse: Boolean;
        ShowCreateInBusinessCentral: Boolean;
        ShowLogAction: Boolean;
        ShowUpdateStatistics: Boolean;

    /// <summary>
    /// Resolves the mapping, coupling and handler of the record a page shows, and computes which actions are available. Call it from OnAfterGetCurrRecord.
    /// </summary>
    /// <param name="RecordId">The record the page shows.</param>
    procedure Refresh(RecordId: RecordId)
    begin
        Refresh(RecordId, 0);
    end;

    /// <summary>
    /// Resolves the mapping to one Dataverse table, the coupling to that table and the handler of the record a page shows, and computes which actions are available. Used where a table has mappings to several Dataverse tables, such as resources to products and to bookable resources.
    /// </summary>
    /// <param name="RecordId">The record the page shows.</param>
    /// <param name="IntegrationTableId">The Dataverse table of the mapping, or 0 for any.</param>
    procedure Refresh(RecordId: RecordId; IntegrationTableId: Integer)
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        FeatureMgt: Codeunit "DVI Feature Mgt.";
        RecordMappingResolver: Codeunit "DVI Record Mapping Resolver";
        MappingResolver: Codeunit "DVI Mapping Resolver";
        Handler: Enum "DVI Sync Handler";
    begin
        ClearAvailability();
        Active := FeatureMgt.IsEnabled();
        if not Active then
            exit;
        if not RecordMappingResolver.Resolve(RecordId, IntegrationTableId, Context) then
            exit;
        Context.GetMapping(IntegrationTableMapping);
        Handler := MappingResolver.GetHandler(IntegrationTableMapping);
        IntegrationRecordView := Handler;
        SynchronizeAction := Handler;
        CouplingAction := Handler;
        CreateAction := Handler;
        SynchLogView := Handler;
        StatisticsAction := Handler;
        ComputeAvailability();
    end;

    /// <summary>
    /// Returns whether the redesigned actions replace the standard ones on the page.
    /// </summary>
    /// <returns>True while the redesigned integration is enabled.</returns>
    procedure IsActive(): Boolean
    begin
        exit(Active);
    end;

    /// <summary>
    /// Returns whether the redesigned action group has at least one available action.
    /// </summary>
    /// <returns>True to show the group.</returns>
    procedure ShowGroup(): Boolean
    begin
        exit(ShowOpen or ShowSynchronize or ShowSetUpCoupling or ShowDeleteCoupling or ShowMatchBasedCoupling or
          ShowCreateInDataverse or ShowCreateInBusinessCentral or ShowLogAction or ShowUpdateStatistics);
    end;

    /// <summary>Returns whether opening the coupled Dataverse record is available.</summary>
    /// <returns>True to show the action.</returns>
    procedure CanOpen(): Boolean
    begin
        exit(ShowOpen);
    end;

    /// <summary>Returns whether synchronizing now is available.</summary>
    /// <returns>True to show the action.</returns>
    procedure CanSynchronize(): Boolean
    begin
        exit(ShowSynchronize);
    end;

    /// <summary>Returns whether setting up a coupling is available.</summary>
    /// <returns>True to show the action.</returns>
    procedure CanSetUpCoupling(): Boolean
    begin
        exit(ShowSetUpCoupling);
    end;

    /// <summary>Returns whether deleting the coupling is available.</summary>
    /// <returns>True to show the action.</returns>
    procedure CanDeleteCoupling(): Boolean
    begin
        exit(ShowDeleteCoupling);
    end;

    /// <summary>Returns whether match-based coupling is available.</summary>
    /// <returns>True to show the action.</returns>
    procedure CanMatchBasedCoupling(): Boolean
    begin
        exit(ShowMatchBasedCoupling);
    end;

    /// <summary>Returns whether creating records in Dataverse is available.</summary>
    /// <returns>True to show the action.</returns>
    procedure CanCreateInDataverse(): Boolean
    begin
        exit(ShowCreateInDataverse);
    end;

    /// <summary>Returns whether creating records from Dataverse is available.</summary>
    /// <returns>True to show the action.</returns>
    procedure CanCreateInBusinessCentral(): Boolean
    begin
        exit(ShowCreateInBusinessCentral);
    end;

    /// <summary>Returns whether the synchronization log is available.</summary>
    /// <returns>True to show the action.</returns>
    procedure CanShowLog(): Boolean
    begin
        exit(ShowLogAction);
    end;

    /// <summary>Returns whether sending statistics to Dataverse is available.</summary>
    /// <returns>True to show the action.</returns>
    procedure CanUpdateStatistics(): Boolean
    begin
        exit(ShowUpdateStatistics);
    end;

    /// <summary>Opens the coupled Dataverse record.</summary>
    procedure OpenIntegrationRecord()
    begin
        IntegrationRecordView.OpenIntegrationRecord(Context);
    end;

    /// <summary>Synchronizes the selected records now.</summary>
    /// <param name="SelectedRecordRef">The records selected on the page.</param>
    procedure Synchronize(var SelectedRecordRef: RecordRef)
    begin
        SynchronizeAction.Synchronize(Context, SelectedRecordRef);
    end;

    /// <summary>Lets the user couple the current record.</summary>
    procedure SetUpCoupling()
    begin
        CouplingAction.SetUpCoupling(Context);
    end;

    /// <summary>Deletes the coupling of the selected records.</summary>
    /// <param name="SelectedRecordRef">The records selected on the page.</param>
    procedure DeleteCoupling(var SelectedRecordRef: RecordRef)
    begin
        CouplingAction.DeleteCoupling(Context, SelectedRecordRef);
    end;

    /// <summary>Couples the selected records by matching field values.</summary>
    /// <param name="SelectedRecordRef">The records selected on the page.</param>
    procedure MatchBasedCoupling(var SelectedRecordRef: RecordRef)
    begin
        CouplingAction.MatchBasedCoupling(Context, SelectedRecordRef);
    end;

    /// <summary>Creates the selected records in Dataverse.</summary>
    /// <param name="SelectedRecordRef">The records selected on the page.</param>
    procedure CreateInDataverse(var SelectedRecordRef: RecordRef)
    begin
        CreateAction.CreateInDataverse(Context, SelectedRecordRef);
    end;

    /// <summary>Lets the user create Business Central records from Dataverse records.</summary>
    procedure CreateInBusinessCentral()
    begin
        CreateAction.CreateInBusinessCentral(Context);
    end;

    /// <summary>Shows the synchronization log of the current record.</summary>
    procedure ShowLog()
    begin
        SynchLogView.ShowLog(Context);
    end;

    /// <summary>Sends statistics of the current record to Dataverse.</summary>
    procedure UpdateStatistics()
    begin
        StatisticsAction.UpdateStatistics(Context);
    end;

    local procedure ComputeAvailability()
    begin
        ShowOpen := IntegrationRecordView.CanOpenIntegrationRecord(Context);
        ShowSynchronize := SynchronizeAction.CanSynchronize(Context);
        ShowSetUpCoupling := CouplingAction.CanSetUpCoupling(Context);
        ShowDeleteCoupling := CouplingAction.CanDeleteCoupling(Context);
        ShowMatchBasedCoupling := CouplingAction.CanMatchBasedCoupling(Context);
        ShowCreateInDataverse := CreateAction.CanCreateInDataverse(Context);
        ShowCreateInBusinessCentral := CreateAction.CanCreateInBusinessCentral(Context);
        ShowLogAction := SynchLogView.CanShowLog(Context);
        ShowUpdateStatistics := StatisticsAction.CanUpdateStatistics(Context);
    end;

    local procedure ClearAvailability()
    begin
        ShowOpen := false;
        ShowSynchronize := false;
        ShowSetUpCoupling := false;
        ShowDeleteCoupling := false;
        ShowMatchBasedCoupling := false;
        ShowCreateInDataverse := false;
        ShowCreateInBusinessCentral := false;
        ShowLogAction := false;
        ShowUpdateStatistics := false;
    end;
}
