namespace DataverseIntegration.CDS;

using DataverseIntegration.Core;
using Microsoft.Sales.Customer;

pageextension 80200 "DVI Customer Card" extends "Customer Card"
{
    actions
    {
        modify(CRMGotoAccount)
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
        modify(UpdateStatisticsInCRM)
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
                    Caption = 'Account';
                    Image = CoupledCustomer;
                    ToolTip = 'Open the coupled Dataverse account.';
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
                    ToolTip = 'Send or get updated data to or from Dataverse, in the directions the integration table mapping allows.';
                    Visible = DVIShowSynchronize;

                    trigger OnAction()
                    var
                        SelectedRecordRef: RecordRef;
                    begin
                        DVICurrentRecord(SelectedRecordRef);
                        DVIRecordActions.Synchronize(SelectedRecordRef);
                    end;
                }
                action(DVIUpdateStatistics)
                {
                    ApplicationArea = DVIRedesign;
                    Caption = 'Update Account Statistics';
                    Image = UpdateXML;
                    ToolTip = 'Send customer statistics data to Dataverse to update the Account Statistics FactBox.';
                    Visible = DVIShowUpdateStatistics;

                    trigger OnAction()
                    begin
                        DVIRecordActions.UpdateStatistics();
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
                        ToolTip = 'Create or modify the coupling to a Dataverse account.';
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
                        ToolTip = 'Delete the coupling to a Dataverse account.';
                        Visible = DVIShowDeleteCoupling;

                        trigger OnAction()
                        var
                            SelectedRecordRef: RecordRef;
                        begin
                            DVICurrentRecord(SelectedRecordRef);
                            DVIRecordActions.DeleteCoupling(SelectedRecordRef);
                        end;
                    }
                }
                action(DVICreateInDataverse)
                {
                    ApplicationArea = DVIRedesign;
                    Caption = 'Create Account in Dataverse';
                    Image = NewCustomer;
                    ToolTip = 'Create the customer as an account in Dataverse and couple them.';
                    Visible = DVIShowCreateInDataverse;

                    trigger OnAction()
                    var
                        SelectedRecordRef: RecordRef;
                    begin
                        DVICurrentRecord(SelectedRecordRef);
                        DVIRecordActions.CreateInDataverse(SelectedRecordRef);
                    end;
                }
                action(DVIShowLog)
                {
                    ApplicationArea = DVIRedesign;
                    Caption = 'Synchronization Log';
                    Image = Log;
                    ToolTip = 'View the synchronization jobs of the customer.';
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
        DVIShowUpdateStatistics: Boolean;

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
        DVIShowUpdateStatistics := DVIRecordActions.CanUpdateStatistics();
    end;

    local procedure DVICurrentRecord(var SelectedRecordRef: RecordRef)
    var
        Customer: Record Customer;
    begin
        Customer := Rec;
        Customer.SetRecFilter();
        SelectedRecordRef.GetTable(Customer);
    end;
}
