namespace DataverseIntegration.FieldService;

using DataverseIntegration.Core;
using Microsoft.Integration.DynamicsFieldService;

pageextension 80811 "DVI FS Connection Setup" extends "FS Connection Setup"
{
    actions
    {
        modify(ResetConfiguration)
        {
            Visible = not DVIActive;
        }
        addafter(ResetConfiguration)
        {
            action(DVIResetConfiguration)
            {
                ApplicationArea = DVIRedesign;
                Caption = 'Use Default Synchronization Setup';
                Image = ResetStatus;
                ToolTip = 'Resets the Field Service integration table mappings and synchronization jobs to the default values, with the redesigned synchronization handlers. All current Field Service mappings are deleted.';
                Visible = DVIActive;

                trigger OnAction()
                var
                    FSMappingDefaults: Codeunit "DVI FS Mapping Defaults";
                begin
                    Rec.TestField("Is Enabled");
                    if not Confirm(ResetQst, false) then
                        exit;
                    FSMappingDefaults.ResetConfiguration(Rec);
                    Message(ResetDoneMsg);
                end;
            }
        }
    }

    trigger OnOpenPage()
    var
        FeatureMgt: Codeunit "DVI Feature Mgt.";
    begin
        DVIActive := FeatureMgt.IsEnabled();
    end;

    var
        DVIActive: Boolean;
        ResetQst: Label 'This will delete the Field Service integration table mappings and synchronization jobs and create them again with the default values and the redesigned handlers. Do you want to continue?';
        ResetDoneMsg: Label 'The Field Service synchronization setup was reset.';
}
