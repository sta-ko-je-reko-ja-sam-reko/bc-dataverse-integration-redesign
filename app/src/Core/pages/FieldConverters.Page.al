namespace DataverseIntegration.Core;

page 80002 "DVI Field Converters"
{
    ApplicationArea = DVIRedesign;
    Caption = 'Integration Field Converters';
    PageType = List;
    SourceTable = "DVI Field Converter";
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            repeater(Converters)
            {
                field("Mapping Name"; Rec."Mapping Name")
                {
                }
                field("Field No."; Rec."Field No.")
                {
                }
                field("Integration Table Field No."; Rec."Integration Table Field No.")
                {
                }
                field(Converter; Rec.Converter)
                {
                }
            }
        }
    }
}
