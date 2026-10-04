namespace DataverseIntegration.Core;

using Microsoft.Integration.Dataverse;
using Microsoft.Integration.SyncEngine;

tableextension 80002 "DVI CRM Integration Record" extends "CRM Integration Record"
{
    fields
    {
        field(80000; "DVI Mapping Name"; Code[20])
        {
            Caption = 'Integration Table Mapping';
            DataClassification = SystemMetadata;
            TableRelation = "Integration Table Mapping".Name;
            ToolTip = 'Specifies the integration table mapping that created the coupling, so that a table with several mappings resolves to the right one.';
        }
    }
}
