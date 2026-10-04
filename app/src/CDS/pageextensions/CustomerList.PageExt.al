namespace DataverseIntegration.CDS;

using DataverseIntegration.Core;
using Microsoft.Sales.Customer;

pageextension 80201 "DVI Customer List" extends "Customer List"
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
        modify(MatchBasedCoupling)
        {
            Visible = not DVIActive;
        }
        modify(DeleteCRMCoupling)
        {
            Visible = not DVIActive;
        }
        modify(CreateInCRM)
        {
            Visible = not DVIActive;
        }
        modify(CreateFromCRM)
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
                    ToolTip = 'Send or get updated data to or from Dataverse for the selected customers, in the directions the integration table mapping allows.';
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
                        ToolTip = 'Create or modify the coupling to a Dataverse account.';
                        Visible = DVIShowSetUpCoupling;

                        trigger OnAction()
                        begin
                            DVIRecordActions.SetUpCoupling();
                        end;
                    }
                    action(DVIMatchBasedCoupling)
                    {
                        ApplicationArea = DVIRedesign;
                        Caption = 'Match-Based Coupling';
                        Image = CoupledCustomer;
                        ToolTip = 'Couple the selected customers to Dataverse accounts by matching field values.';
                        Visible = DVIShowMatchBasedCoupling;

                        trigger OnAction()
                        var
                            SelectedRecordRef: RecordRef;
                        begin
                            DVISelection(SelectedRecordRef);
                            DVIRecordActions.MatchBasedCoupling(SelectedRecordRef);
                        end;
                    }
                    action(DVIDeleteCoupling)
                    {
                        ApplicationArea = DVIRedesign;
                        Caption = 'Delete Coupling';
                        Image = UnLinkAccount;
                        ToolTip = 'Delete the couplings of the selected customers.';
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
                group(DVICreate)
                {
                    Caption = 'Create';

                    action(DVICreateInDataverse)
                    {
                        ApplicationArea = DVIRedesign;
                        Caption = 'Create Account in Dataverse';
                        Image = NewCustomer;
                        ToolTip = 'Create the selected customers as accounts in Dataverse and couple them.';
                        Visible = DVIShowCreateInDataverse;

                        trigger OnAction()
                        var
                            SelectedRecordRef: RecordRef;
                        begin
                            DVISelection(SelectedRecordRef);
                            DVIRecordActions.CreateInDataverse(SelectedRecordRef);
                        end;
                    }
                    action(DVICreateInBusinessCentral)
                    {
                        ApplicationArea = DVIRedesign;
                        Caption = 'Create Customer in Business Central';
                        Image = NewCustomer;
                        ToolTip = 'Pick Dataverse accounts and create customers from them.';
                        Visible = DVIShowCreateInBusinessCentral;

                        trigger OnAction()
                        begin
                            DVIRecordActions.CreateInBusinessCentral();
                        end;
                    }
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
        DVIShowMatchBasedCoupling: Boolean;
        DVIShowCreateInDataverse: Boolean;
        DVIShowCreateInBusinessCentral: Boolean;
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
        DVIShowMatchBasedCoupling := DVIRecordActions.CanMatchBasedCoupling();
        DVIShowCreateInDataverse := DVIRecordActions.CanCreateInDataverse();
        DVIShowCreateInBusinessCentral := DVIRecordActions.CanCreateInBusinessCentral();
        DVIShowLogAction := DVIRecordActions.CanShowLog();
    end;

    local procedure DVISelection(var SelectedRecordRef: RecordRef)
    var
        Customer: Record Customer;
    begin
        CurrPage.SetSelectionFilter(Customer);
        SelectedRecordRef.GetTable(Customer);
    end;
}
