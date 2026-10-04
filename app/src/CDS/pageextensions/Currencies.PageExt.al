namespace DataverseIntegration.CDS;

using DataverseIntegration.Core;
using Microsoft.Finance.Currency;

pageextension 80207 "DVI Currencies" extends "Currencies"
{
    actions
    {
        modify(CRMGotoTransactionCurrency)
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
                    Caption = 'Transaction Currency';
                    Image = CoupledContactPerson;
                    ToolTip = 'Open the coupled Dataverse transaction currency.';
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
                    ToolTip = 'Send or get updated data to or from Dataverse for the selected currencies, in the directions the integration table mapping allows.';
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
                        ToolTip = 'Create or modify the coupling to a Dataverse transaction currency.';
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
                        ToolTip = 'Couple the selected currencies to Dataverse records by matching field values.';
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
                        ToolTip = 'Delete the couplings of the selected currencies.';
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
                    ToolTip = 'Create the selected currencies in Dataverse and couple them.';
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
                    ToolTip = 'Pick Dataverse records and create currencies from them.';
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
                    ToolTip = 'View the synchronization jobs of the currency.';
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
        SelectedRecord: Record Currency;
    begin
        CurrPage.SetSelectionFilter(SelectedRecord);
        SelectedRecordRef.GetTable(SelectedRecord);
    end;
}
