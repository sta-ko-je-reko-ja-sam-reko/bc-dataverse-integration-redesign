namespace DataverseIntegration.Core;

page 80001 "DVI Mapping Assignments"
{
    ApplicationArea = DVIRedesign;
    Caption = 'Redesigned Integration Mappings';
    PageType = List;
    SourceTable = "DVI Mapping Assignment";
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            repeater(Assignments)
            {
                field("Mapping Name"; Rec."Mapping Name")
                {
                }
                field(Handler; Rec.Handler)
                {
                }
                field(Module; Rec.Module)
                {
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(SwitchAll)
            {
                Caption = 'Switch All Mappings';
                Image = Apply;
                ToolTip = 'Switch every Dataverse integration table mapping to the redesigned synchronization with its default handler.';

                trigger OnAction()
                var
                    DefaultAssignment: Codeunit "DVI Default Assignment";
                begin
                    Message(SwitchedMsg, DefaultAssignment.SwitchAllToRedesigned());
                end;
            }
        }
        area(Promoted)
        {
            actionref(SwitchAll_Promoted; SwitchAll)
            {
            }
        }
    }

    var
        SwitchedMsg: Label '%1 integration table mappings now use the redesigned synchronization.', Comment = '%1 = number of mappings';
}
