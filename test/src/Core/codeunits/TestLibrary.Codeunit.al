namespace DataverseIntegration.Test;

using DataverseIntegration.Core;
using Microsoft.Integration.Dataverse;
using Microsoft.Integration.SyncEngine;

codeunit 84000 "DVI Test Library"
{
    /// <summary>
    /// Creates a Dataverse integration table mapping that the standard runner would run.
    /// </summary>
    /// <param name="MappingName">The mapping name.</param>
    /// <param name="TableId">The Business Central table.</param>
    /// <param name="IntegrationTableId">The Dataverse table.</param>
    /// <param name="Direction">The synchronization direction.</param>
    /// <returns>The created mapping.</returns>
    internal procedure CreateDataverseMapping(MappingName: Code[20]; TableId: Integer; IntegrationTableId: Integer; Direction: Option Bidirectional,ToIntegrationTable,FromIntegrationTable) IntegrationTableMapping: Record "Integration Table Mapping"
    begin
        IntegrationTableMapping.Init();
        IntegrationTableMapping.Name := MappingName;
        IntegrationTableMapping."Table ID" := TableId;
        IntegrationTableMapping."Integration Table ID" := IntegrationTableId;
        IntegrationTableMapping.Type := IntegrationTableMapping.Type::Dataverse;
        IntegrationTableMapping."Synch. Codeunit ID" := Codeunit::"CRM Integration Table Synch.";
        IntegrationTableMapping.Direction := Direction;
        IntegrationTableMapping.Insert(false);
    end;

    /// <summary>
    /// Creates a field mapping on a mapping.
    /// </summary>
    /// <param name="MappingName">The mapping.</param>
    /// <param name="FieldNo">The Business Central field, or 0 for a constant.</param>
    /// <param name="IntegrationFieldNo">The Dataverse field.</param>
    /// <param name="Direction">The field's synchronization direction.</param>
    /// <param name="ConstantValue">The constant written when FieldNo is 0.</param>
    internal procedure CreateFieldMapping(MappingName: Code[20]; FieldNo: Integer; IntegrationFieldNo: Integer; Direction: Option Bidirectional,ToIntegrationTable,FromIntegrationTable; ConstantValue: Text[100])
    var
        IntegrationFieldMapping: Record "Integration Field Mapping";
    begin
        IntegrationFieldMapping.Init();
        IntegrationFieldMapping."Integration Table Mapping Name" := MappingName;
        IntegrationFieldMapping."Field No." := FieldNo;
        IntegrationFieldMapping."Integration Table Field No." := IntegrationFieldNo;
        IntegrationFieldMapping.Direction := Direction;
        IntegrationFieldMapping."Constant Value" := ConstantValue;
        IntegrationFieldMapping.Status := IntegrationFieldMapping.Status::Enabled;
        IntegrationFieldMapping.Insert(true);
    end;

    /// <summary>
    /// Assigns a handler to a mapping directly, without the validation of the assignment.
    /// </summary>
    /// <param name="MappingName">The mapping.</param>
    /// <param name="Handler">The handler.</param>
    internal procedure AssignHandler(MappingName: Code[20]; Handler: Enum "DVI Sync Handler")
    var
        MappingAssignment: Record "DVI Mapping Assignment";
    begin
        MappingAssignment.Init();
        MappingAssignment."Mapping Name" := MappingName;
        MappingAssignment.Handler := Handler;
        MappingAssignment.Insert(false);
    end;

    /// <summary>
    /// Turns the redesigned integration on or off and clears the session cache of the flag.
    /// </summary>
    /// <param name="Enabled">The new value.</param>
    internal procedure SetFeatureEnabled(Enabled: Boolean)
    var
        Setup: Record "DVI Setup";
        FeatureMgt: Codeunit "DVI Feature Mgt.";
    begin
        if not Setup.Get() then begin
            Setup.Init();
            Setup.Insert(false);
        end;
        Setup."DVI Enabled" := Enabled;
        Setup.Modify(false);
        FeatureMgt.ClearCache();
    end;
}
