namespace DataverseIntegration.Core;

using Microsoft.Integration.SyncEngine;

pageextension 80000 "DVI Int. Table Mapping List" extends "Integration Table Mapping List"
{
    layout
    {
        addafter(Name)
        {
            field(DVIHandler; Rec."DVI Handler")
            {
                ApplicationArea = DVIRedesign;
            }
            field(DVIModule; Rec."DVI Module")
            {
                ApplicationArea = DVIRedesign;
            }
        }
    }

    actions
    {
        addlast(Navigation)
        {
            action(DVISwitchToRedesigned)
            {
                ApplicationArea = DVIRedesign;
                Caption = 'Use Redesigned Synchronization';
                Image = Apply;
                ToolTip = 'Switch the selected mappings to the redesigned synchronization with their default handler.';

                trigger OnAction()
                var
                    IntegrationTableMapping: Record "Integration Table Mapping";
                    DefaultAssignment: Codeunit "DVI Default Assignment";
                begin
                    CurrPage.SetSelectionFilter(IntegrationTableMapping);
                    if IntegrationTableMapping.FindSet() then
                        repeat
                            DefaultAssignment.SwitchToRedesigned(IntegrationTableMapping);
                        until IntegrationTableMapping.Next() = 0;
                    CurrPage.Update(false);
                end;
            }
            action(DVISwitchToStandard)
            {
                ApplicationArea = DVIRedesign;
                Caption = 'Use Standard Synchronization';
                Image = Undo;
                ToolTip = 'Return the selected mappings to the standard synchronization that Microsoft ships.';

                trigger OnAction()
                var
                    IntegrationTableMapping: Record "Integration Table Mapping";
                    DefaultAssignment: Codeunit "DVI Default Assignment";
                begin
                    CurrPage.SetSelectionFilter(IntegrationTableMapping);
                    if IntegrationTableMapping.FindSet() then
                        repeat
                            DefaultAssignment.SwitchToStandard(IntegrationTableMapping);
                        until IntegrationTableMapping.Next() = 0;
                    CurrPage.Update(false);
                end;
            }
            action(DVIAssignments)
            {
                ApplicationArea = DVIRedesign;
                Caption = 'Redesigned Mappings';
                Image = Setup;
                RunObject = page "DVI Mapping Assignments";
                ToolTip = 'View and change which handler and module the redesigned synchronization uses for each mapping.';
            }
        }
    }
}
