namespace DataverseIntegration.CRM;

using DataverseIntegration.Core;
using Microsoft.Sales.Document;

pageextension 80409 "DVI Sales Order" extends "Sales Order"
{
    actions
    {
        modify(CRMGoToSalesOrder)
        {
            Visible = not DVIActive;
        }
        modify(CRMSynchronizeNow)
        {
            Visible = not DVIActive;
        }
        modify(ManageCRMCoupling)
        {
            Visible = not DVIActive;
        }
        modify(DeleteCRMCoupling)
        {
            Visible = not DVIActive;
        }
        modify(ShowLog)
        {
            Visible = not DVIActive;
        }
        addafter(ActionGroupCRM)
        {
            group(DVIDataverse)
            {
                Caption = 'Dataverse';
                Visible = DVIShowGroup;

                action(DVIOpenIntegrationRecord)
                {
                    ApplicationArea = DVIRedesign;
                    Caption = 'Sales Order';
                    Image = CoupledContactPerson;
                    ToolTip = 'Open the coupled Dataverse sales order.';
                    Visible = DVIShowOpen;

                    trigger OnAction()
                    begin
                        DVIRecordActions.OpenIntegrationRecord();
                    end;
                }
                action(DVISynchronize)
                {
                    ApplicationArea = DVIRedesign;
                    Caption = 'Synchronize';
                    Image = Refresh;
                    ToolTip = 'Send or get updated data to or from Dataverse for the sales order, in the directions the integration table mapping allows.';
                    Visible = DVIShowSynchronize;

                    trigger OnAction()
                    var
                        SelectedRecordRef: RecordRef;
                    begin
                        DVISelection(SelectedRecordRef);
                        DVIRecordActions.Synchronize(SelectedRecordRef);
                    end;
                }
                group(DVICoupling)
                {
                    Caption = 'Coupling', Comment = 'Coupling is a noun';

                    action(DVISetUpCoupling)
                    {
                        ApplicationArea = DVIRedesign;
                        Caption = 'Set Up Coupling';
                        Image = LinkAccount;
                        ToolTip = 'Create or modify the coupling to a Dataverse sales order.';
                        Visible = DVIShowSetUpCoupling;

                        trigger OnAction()
                        begin
                            DVIRecordActions.SetUpCoupling();
                        end;
                    }
                    action(DVIDeleteCoupling)
                    {
                        ApplicationArea = DVIRedesign;
                        Caption = 'Delete Coupling';
                        Image = UnLinkAccount;
                        ToolTip = 'Delete the couplings of the sales order.';
                        Visible = DVIShowDeleteCoupling;

                        trigger OnAction()
                        var
                            SelectedRecordRef: RecordRef;
                        begin
                            DVISelection(SelectedRecordRef);
                            DVIRecordActions.DeleteCoupling(SelectedRecordRef);
                        end;
                    }
                }
                action(DVICreateInDataverse)
                {
                    ApplicationArea = DVIRedesign;
                    Caption = 'Create in Dataverse';
                    Image = NewDocument;
                    ToolTip = 'Create the sales order in Dataverse and couple them.';
                    Visible = DVIShowCreateInDataverse;

                    trigger OnAction()
                    var
                        SelectedRecordRef: RecordRef;
                    begin
                        DVISelection(SelectedRecordRef);
                        DVIRecordActions.CreateInDataverse(SelectedRecordRef);
                    end;
                }
                action(DVIShowLog)
                {
                    ApplicationArea = DVIRedesign;
                    Caption = 'Synchronization Log';
                    Image = Log;
                    ToolTip = 'View the synchronization jobs of the sales order.';
                    Visible = DVIShowLogAction;

                    trigger OnAction()
                    begin
                        DVIRecordActions.ShowLog();
                    end;
                }
            }
        }
        addlast(Category_Synchronize)
        {
            actionref(DVISynchronize_Promoted; DVISynchronize)
            {
            }
            actionref(DVIOpenIntegrationRecord_Promoted; DVIOpenIntegrationRecord)
            {
            }
        }
    }

    trigger OnAfterGetCurrRecord()
    begin
        DVIRefresh();
    end;

    var
        DVIRecordActions: Codeunit "DVI Record Actions";
        DVIActive: Boolean;
        DVIShowGroup: Boolean;
        DVIShowOpen: Boolean;
        DVIShowSynchronize: Boolean;
        DVIShowSetUpCoupling: Boolean;
        DVIShowDeleteCoupling: Boolean;
        DVIShowCreateInDataverse: Boolean;
        DVIShowLogAction: Boolean;

    local procedure DVIRefresh()
    begin
        DVIRecordActions.Refresh(Rec.RecordId());
        DVIActive := DVIRecordActions.IsActive();
        DVIShowGroup := DVIRecordActions.ShowGroup();
        DVIShowOpen := DVIRecordActions.CanOpen();
        DVIShowSynchronize := DVIRecordActions.CanSynchronize();
        DVIShowSetUpCoupling := DVIRecordActions.CanSetUpCoupling();
        DVIShowDeleteCoupling := DVIRecordActions.CanDeleteCoupling();
        DVIShowCreateInDataverse := DVIRecordActions.CanCreateInDataverse();
        DVIShowLogAction := DVIRecordActions.CanShowLog();
    end;

    local procedure DVISelection(var SelectedRecordRef: RecordRef)
    var
        SelectedRecord: Record "Sales Header";
    begin
        SelectedRecord := Rec;
        SelectedRecord.SetRecFilter();
        SelectedRecordRef.GetTable(SelectedRecord);
    end;
}
