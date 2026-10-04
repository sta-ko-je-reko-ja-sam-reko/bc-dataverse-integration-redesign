namespace DataverseIntegration.CRM;

using DataverseIntegration.Core;
using Microsoft.Sales.History;

pageextension 80412 "DVI Posted Sales Invoices" extends "Posted Sales Invoices"
{
    actions
    {
        modify(CRMGotoInvoice)
        {
            Visible = not DVIActive;
        }
        modify(CreateInCRM)
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
                    Caption = 'Invoice';
                    Image = CoupledContactPerson;
                    ToolTip = 'Open the coupled Dataverse invoice.';
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
                    ToolTip = 'Send or get updated data to or from Dataverse for the selected posted sales invoices, in the directions the integration table mapping allows.';
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
                        ToolTip = 'Create or modify the coupling to a Dataverse invoice.';
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
                        Image = CoupledContactPerson;
                        ToolTip = 'Couple the selected posted sales invoices to Dataverse records by matching field values.';
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
                        ToolTip = 'Delete the couplings of the selected posted sales invoices.';
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
                    ToolTip = 'Create the selected posted sales invoices in Dataverse and couple them.';
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
                    Caption = 'Create in Business Central';
                    Image = NewDocument;
                    ToolTip = 'Pick Dataverse records and create posted sales invoices from them.';
                    Visible = DVIShowCreateInBusinessCentral;

                    trigger OnAction()
                    begin
                        DVIRecordActions.CreateInBusinessCentral();
                    end;
                }
                action(DVIShowLog)
                {
                    ApplicationArea = DVIRedesign;
                    Caption = 'Synchronization Log';
                    Image = Log;
                    ToolTip = 'View the synchronization jobs of the posted sales invoice.';
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
        DVIShowMatchBasedCoupling: Boolean;
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
        DVIShowCreateInDataverse := DVIRecordActions.CanCreateInDataverse();
        DVIShowMatchBasedCoupling := DVIRecordActions.CanMatchBasedCoupling();
        DVIShowCreateInBusinessCentral := DVIRecordActions.CanCreateInBusinessCentral();
        DVIShowLogAction := DVIRecordActions.CanShowLog();
    end;

    local procedure DVISelection(var SelectedRecordRef: RecordRef)
    var
        SelectedRecord: Record "Sales Invoice Header";
    begin
        CurrPage.SetSelectionFilter(SelectedRecord);
        SelectedRecordRef.GetTable(SelectedRecord);
    end;
}
