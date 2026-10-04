namespace DataverseIntegration.Core;

using Microsoft.Integration.SyncEngine;

tableextension 80001 "DVI Integration Table Mapping" extends "Integration Table Mapping"
{
    fields
    {
        field(80000; "DVI Handler"; Enum "DVI Sync Handler")
        {
            CalcFormula = lookup("DVI Mapping Assignment".Handler where("Mapping Name" = field(Name)));
            Caption = 'Synchronization Handler';
            Editable = false;
            FieldClass = FlowField;
            ToolTip = 'Specifies which implementation synchronizes the records of this mapping. Microsoft (not redesigned) leaves the mapping to the standard synchronization.';
        }
        field(80001; "DVI Module"; Enum "DVI Integration Module")
        {
            CalcFormula = lookup("DVI Mapping Assignment".Module where("Mapping Name" = field(Name)));
            Caption = 'Integration Module';
            Editable = false;
            FieldClass = FlowField;
            ToolTip = 'Specifies which integration the mapping belongs to under the redesigned synchronization.';
        }
    }
}
