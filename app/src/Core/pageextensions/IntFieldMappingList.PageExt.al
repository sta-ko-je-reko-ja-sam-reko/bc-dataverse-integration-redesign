namespace DataverseIntegration.Core;

using Microsoft.Integration.SyncEngine;

pageextension 80001 "DVI Int. Field Mapping List" extends "Integration Field Mapping List"
{
    layout
    {
        addafter(Direction)
        {
            field(DVIValueConverter; Rec."DVI Value Converter")
            {
                ApplicationArea = DVIRedesign;
            }
        }
    }
}
