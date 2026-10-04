namespace DataverseIntegration.Core;

page 80000 "DVI Setup"
{
    ApplicationArea = All;
    Caption = 'Dataverse Integration Redesign Setup';
    DeleteAllowed = false;
    InsertAllowed = false;
    PageType = Card;
    SourceTable = "DVI Setup";
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

                field(Enabled; Rec."DVI Enabled")
                {
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.Reset();
        if not Rec.Get() then begin
            Rec.Init();
            Rec.Insert(true);
        end;
        EnabledOnOpen := Rec."DVI Enabled";
    end;

    trigger OnQueryClosePage(CloseAction: Action): Boolean
    var
        FeatureMgt: Codeunit "DVI Feature Mgt.";
    begin
        if Rec."DVI Enabled" <> EnabledOnOpen then
            FeatureMgt.ApplyExperienceChange(Rec."DVI Enabled");
        exit(true);
    end;

    var
        EnabledOnOpen: Boolean;
}
