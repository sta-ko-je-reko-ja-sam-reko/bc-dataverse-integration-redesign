namespace DataverseIntegration.FieldService;

using DataverseIntegration.Core;
using Microsoft.Integration.DynamicsFieldService;
using Microsoft.Projects.Project.Job;

pageextension 80807 "DVI FS Project Task Lines" extends "Job Task Lines"
{
    actions
    {
        modify(ActionFS)
        {
            Visible = DVIFSShowStandard;
        }
        modify(Category_FS_Synchronize)
        {
            Visible = DVIFSShowStandard;
        }
        addafter("&Job Task")
        {
            group(DVIFieldService)
            {
                Caption = 'Field Service';
                Visible = DVIFSShowGroup;

                action(DVIFSOpenIntegrationRecord)
                {
                    ApplicationArea = DVIRedesign;
                    Caption = 'Project Task';
                    Image = CoupledItem;
                    ToolTip = 'Open the coupled Field Service project task.';
                    Visible = DVIFSShowOpen;

                    trigger OnAction()
                    begin
                        DVIFSRecordActions.OpenIntegrationRecord();
                    end;
                }
                action(DVIFSSynchronize)
                {
                    ApplicationArea = DVIRedesign;
                    Caption = 'Synchronize';
                    Image = Refresh;
                    ToolTip = 'Send or get updated data to or from Field Service for the selected project tasks, in the directions the integration table mapping allows.';
                    Visible = DVIFSShowSynchronize;

                    trigger OnAction()
                    var
                        SelectedRecordRef: RecordRef;
                    begin
                        DVIFSSelection(SelectedRecordRef);
                        DVIFSRecordActions.Synchronize(SelectedRecordRef);
                    end;
                }
                group(DVIFSCoupling)
                {
                    Caption = 'Coupling', Comment = 'Coupling is a noun';

                    action(DVIFSSetUpCoupling)
                    {
                        ApplicationArea = DVIRedesign;
                        Caption = 'Set Up Coupling';
                        Image = LinkAccount;
                        ToolTip = 'Create or modify the coupling to a Field Service project task.';
                        Visible = DVIFSShowSetUpCoupling;

                        trigger OnAction()
                        begin
                            DVIFSRecordActions.SetUpCoupling();
                        end;
                    }
                    action(DVIFSMatchBasedCoupling)
                    {
                        ApplicationArea = DVIRedesign;
                        Caption = 'Match-Based Coupling';
                        Image = CoupledItem;
                        ToolTip = 'Couple the selected project tasks to Field Service records by matching field values.';
                        Visible = DVIFSShowMatchBasedCoupling;

                        trigger OnAction()
                        var
                            SelectedRecordRef: RecordRef;
                        begin
                            DVIFSSelection(SelectedRecordRef);
                            DVIFSRecordActions.MatchBasedCoupling(SelectedRecordRef);
                        end;
                    }
                    action(DVIFSDeleteCoupling)
                    {
                        ApplicationArea = DVIRedesign;
                        Caption = 'Delete Coupling';
                        Image = UnLinkAccount;
                        ToolTip = 'Delete the Field Service couplings of the selected project tasks.';
                        Visible = DVIFSShowDeleteCoupling;

                        trigger OnAction()
                        var
                            SelectedRecordRef: RecordRef;
                        begin
                            DVIFSSelection(SelectedRecordRef);
                            DVIFSRecordActions.DeleteCoupling(SelectedRecordRef);
                        end;
                    }
                }
                action(DVIFSCreateInDataverse)
                {
                    ApplicationArea = DVIRedesign;
                    Caption = 'Create in Field Service';
                    Image = NewDocument;
                    ToolTip = 'Create the selected project tasks in Field Service and couple them.';
                    Visible = DVIFSShowCreateInDataverse;

                    trigger OnAction()
                    var
                        SelectedRecordRef: RecordRef;
                    begin
                        DVIFSSelection(SelectedRecordRef);
                        DVIFSRecordActions.CreateInDataverse(SelectedRecordRef);
                    end;
                }
                action(DVIFSCreateInBusinessCentral)
                {
                    ApplicationArea = DVIRedesign;
                    Caption = 'Create in Business Central';
                    Image = NewDocument;
                    ToolTip = 'Pick Field Service records and create project tasks from them.';
                    Visible = DVIFSShowCreateInBusinessCentral;

                    trigger OnAction()
                    begin
                        DVIFSRecordActions.CreateInBusinessCentral();
                    end;
                }
                action(DVIFSShowLog)
                {
                    ApplicationArea = DVIRedesign;
                    Caption = 'Synchronization Log';
                    Image = Log;
                    ToolTip = 'View the Field Service synchronization jobs of the project task.';
                    Visible = DVIFSShowLogAction;

                    trigger OnAction()
                    begin
                        DVIFSRecordActions.ShowLog();
                    end;
                }
            }
        }
        addlast(Promoted)
        {
            group(DVIFSCategory)
            {
                Caption = 'Field Service';
                Visible = DVIFSShowGroup;

                actionref(DVIFSSynchronize_Promoted; DVIFSSynchronize)
                {
                }
                actionref(DVIFSOpenIntegrationRecord_Promoted; DVIFSOpenIntegrationRecord)
                {
                }
            }
        }
    }

    trigger OnAfterGetCurrRecord()
    begin
        DVIFSRefresh();
    end;

    var
        DVIFSRecordActions: Codeunit "DVI Record Actions";
        DVIFSActive: Boolean;
        DVIFSShowGroup: Boolean;
        DVIFSShowOpen: Boolean;
        DVIFSShowSynchronize: Boolean;
        DVIFSShowSetUpCoupling: Boolean;
        DVIFSShowDeleteCoupling: Boolean;
        DVIFSShowCreateInDataverse: Boolean;
        DVIFSShowMatchBasedCoupling: Boolean;
        DVIFSShowCreateInBusinessCentral: Boolean;
        DVIFSShowLogAction: Boolean;
        DVIFSShowStandard: Boolean;

    local procedure DVIFSRefresh()
    var
        FieldServiceConnection: Codeunit "DVI Field Service Connection";
    begin
        DVIFSRecordActions.Refresh(Rec.RecordId(), Database::"FS Project Task");
        DVIFSActive := DVIFSRecordActions.IsActive();
        DVIFSShowGroup := DVIFSRecordActions.ShowGroup();
        DVIFSShowOpen := DVIFSRecordActions.CanOpen();
        DVIFSShowSynchronize := DVIFSRecordActions.CanSynchronize();
        DVIFSShowSetUpCoupling := DVIFSRecordActions.CanSetUpCoupling();
        DVIFSShowDeleteCoupling := DVIFSRecordActions.CanDeleteCoupling();
        DVIFSShowCreateInDataverse := DVIFSRecordActions.CanCreateInDataverse();
        DVIFSShowMatchBasedCoupling := DVIFSRecordActions.CanMatchBasedCoupling();
        DVIFSShowCreateInBusinessCentral := DVIFSRecordActions.CanCreateInBusinessCentral();
        DVIFSShowLogAction := DVIFSRecordActions.CanShowLog();
        DVIFSShowStandard := (not DVIFSActive) and FieldServiceConnection.IsEnabled();
    end;

    local procedure DVIFSSelection(var SelectedRecordRef: RecordRef)
    var
        SelectedRecord: Record "Job Task";
    begin
        CurrPage.SetSelectionFilter(SelectedRecord);
        SelectedRecordRef.GetTable(SelectedRecord);
    end;
}
