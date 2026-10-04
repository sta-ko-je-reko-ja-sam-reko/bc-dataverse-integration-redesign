namespace DataverseIntegration.Core;

using Microsoft.Integration.SyncEngine;

table 80004 "DVI Field Converter"
{
    Caption = 'Integration Field Converter';
    DataClassification = SystemMetadata;
    DrillDownPageId = "DVI Field Converters";
    LookupPageId = "DVI Field Converters";

    fields
    {
        field(1; "Mapping Name"; Code[20])
        {
            Caption = 'Integration Table Mapping';
            TableRelation = "Integration Table Mapping".Name;
            ToolTip = 'Specifies the integration table mapping. The converter is kept by mapping name and field numbers, so it still applies after the standard setup re-creates the field mappings.';
        }
        field(2; "Field No."; Integer)
        {
            Caption = 'Field No.';
            ToolTip = 'Specifies the Business Central field of the field mapping.';
        }
        field(3; "Integration Table Field No."; Integer)
        {
            Caption = 'Integration Table Field No.';
            ToolTip = 'Specifies the Dataverse field of the field mapping.';
        }
        field(4; Converter; Enum "DVI Value Converter")
        {
            Caption = 'Value Converter';
            ToolTip = 'Specifies how the value is converted between the two fields. Direct copies the value as it is.';
        }
    }

    keys
    {
        key(PK; "Mapping Name", "Field No.", "Integration Table Field No.")
        {
            Clustered = true;
        }
    }
}
