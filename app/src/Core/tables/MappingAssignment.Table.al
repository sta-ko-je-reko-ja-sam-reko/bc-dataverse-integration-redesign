namespace DataverseIntegration.Core;

using Microsoft.Integration.SyncEngine;

table 80003 "DVI Mapping Assignment"
{
    Caption = 'Integration Mapping Assignment';
    DataClassification = SystemMetadata;
    DrillDownPageId = "DVI Mapping Assignments";
    LookupPageId = "DVI Mapping Assignments";

    fields
    {
        field(1; "Mapping Name"; Code[20])
        {
            Caption = 'Integration Table Mapping';
            NotBlank = true;
            TableRelation = "Integration Table Mapping".Name where("Delete After Synchronization" = const(false));
            ToolTip = 'Specifies the integration table mapping. The assignment is kept by name, so it still applies after the standard setup re-creates the mapping.';
        }
        field(2; Handler; Enum "DVI Sync Handler")
        {
            Caption = 'Synchronization Handler';
            ToolTip = 'Specifies which implementation synchronizes the records of the mapping. Microsoft (not redesigned) leaves the mapping to the standard synchronization.';

            trigger OnValidate()
            begin
                Logic().Validate_Handler(Rec, xRec);
            end;
        }
        field(3; Module; Enum "DVI Integration Module")
        {
            Caption = 'Integration Module';
            ToolTip = 'Specifies which integration the mapping belongs to: Dataverse, Dynamics 365 Sales or Dynamics 365 Field Service. Its connection must be enabled for the redesigned synchronization to run.';
        }
    }

    keys
    {
        key(PK; "Mapping Name")
        {
            Clustered = true;
        }
    }

    var
        MappingLogic: Interface "DVI IMappingLogic";
        MappingLogicDefined: Boolean;

    local procedure Logic(): Interface "DVI IMappingLogic"
    var
        DefaultMappingLogic: Codeunit "DVI Mapping Logic";
    begin
        if not MappingLogicDefined then
            Define(DefaultMappingLogic);
        exit(MappingLogic);
    end;

    /// <summary>
    /// Injects an alternative implementation of the assignment logic, for tests and dependent apps.
    /// </summary>
    /// <param name="Implementation">The implementation to use.</param>
    procedure Define(Implementation: Interface "DVI IMappingLogic")
    begin
        MappingLogic := Implementation;
        MappingLogicDefined := true;
    end;
}
