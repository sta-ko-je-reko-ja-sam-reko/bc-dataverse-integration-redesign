namespace DataverseIntegration.Core;

using Microsoft.Integration.SyncEngine;

tableextension 80003 "DVI Integration Field Mapping" extends "Integration Field Mapping"
{
    fields
    {
        field(80000; "DVI Value Converter"; Enum "DVI Value Converter")
        {
            CalcFormula = lookup("DVI Field Converter".Converter where("Mapping Name" = field("Integration Table Mapping Name"),
                                                                       "Field No." = field("Field No."),
                                                                       "Integration Table Field No." = field("Integration Table Field No.")));
            Caption = 'Value Converter';
            Editable = false;
            FieldClass = FlowField;
            ToolTip = 'Specifies how the redesigned synchronization converts the value between the two fields.';
        }
    }
}
