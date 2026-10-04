namespace DataverseIntegration.Core;

using Microsoft.Integration.SyncEngine;

tableextension 80001 "DVI Integration Table Mapping" extends "Integration Table Mapping"
{
    fields
    {
        field(80000; "DVI Handler"; Enum "DVI Sync Handler")
        {
            Caption = 'Synchronization Handler';
            DataClassification = SystemMetadata;
            ToolTip = 'Specifies which implementation synchronizes the records of this mapping. Microsoft (not redesigned) leaves the mapping to the standard synchronization; any other value runs the redesigned synchronization with that implementation.';

            trigger OnValidate()
            begin
                DVILogic().Validate_Handler(Rec, xRec);
            end;
        }
        field(80001; "DVI Module"; Enum "DVI Integration Module")
        {
            Caption = 'Integration Module';
            DataClassification = SystemMetadata;
            ToolTip = 'Specifies which integration the mapping belongs to: Dataverse, Dynamics 365 Sales or Dynamics 365 Field Service. Its connection must be enabled for the redesigned synchronization to run.';
        }
    }

    var
        DVIMappingLogic: Interface "DVI IMappingLogic";
        DVIMappingLogicDefined: Boolean;

    local procedure DVILogic(): Interface "DVI IMappingLogic"
    var
        DefaultMappingLogic: Codeunit "DVI Mapping Logic";
    begin
        if not DVIMappingLogicDefined then
            DVIDefineLogic(DefaultMappingLogic);
        exit(DVIMappingLogic);
    end;

    /// <summary>
    /// Injects an alternative implementation of the mapping logic, for tests and dependent apps.
    /// </summary>
    /// <param name="Implementation">The implementation to use.</param>
    procedure DVIDefineLogic(Implementation: Interface "DVI IMappingLogic")
    begin
        DVIMappingLogic := Implementation;
        DVIMappingLogicDefined := true;
    end;
}
