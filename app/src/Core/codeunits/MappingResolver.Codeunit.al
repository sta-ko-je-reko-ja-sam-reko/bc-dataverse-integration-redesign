namespace DataverseIntegration.Core;

using Microsoft.Integration.SyncEngine;

codeunit 80020 "DVI Mapping Resolver"
{
    Access = Internal;

    /// <summary>
    /// Returns the name of the mapping that owns the assignment. A temporary mapping created for a single synchronization (Synchronize now) belongs to its parent.
    /// </summary>
    /// <param name="IntegrationTableMapping">The mapping that is being run.</param>
    /// <returns>The parent name for a temporary mapping, otherwise the mapping's own name.</returns>
    internal procedure GetCouplingMappingName(IntegrationTableMapping: Record "Integration Table Mapping"): Code[20]
    begin
        if IntegrationTableMapping."Parent Name" <> '' then
            exit(IntegrationTableMapping."Parent Name");
        exit(IntegrationTableMapping.Name);
    end;

    /// <summary>
    /// Returns whether a mapping runs the redesigned synchronization.
    /// </summary>
    /// <param name="IntegrationTableMapping">The mapping that is being run.</param>
    /// <returns>True when the owning mapping is assigned a handler other than Microsoft.</returns>
    internal procedure IsSwitched(IntegrationTableMapping: Record "Integration Table Mapping"): Boolean
    begin
        exit(GetHandler(IntegrationTableMapping) <> Enum::"DVI Sync Handler"::DVIMicrosoft);
    end;

    /// <summary>
    /// Returns the synchronization handler assigned to a mapping.
    /// </summary>
    /// <param name="IntegrationTableMapping">The mapping that is being run.</param>
    /// <returns>The assigned handler, or Microsoft when the mapping has no assignment.</returns>
    internal procedure GetHandler(IntegrationTableMapping: Record "Integration Table Mapping"): Enum "DVI Sync Handler"
    var
        MappingAssignment: Record "DVI Mapping Assignment";
    begin
        MappingAssignment.SetLoadFields(Handler);
        if MappingAssignment.Get(GetCouplingMappingName(IntegrationTableMapping)) then
            exit(MappingAssignment.Handler);
        exit(Enum::"DVI Sync Handler"::DVIMicrosoft);
    end;

    /// <summary>
    /// Returns the integration module assigned to a mapping.
    /// </summary>
    /// <param name="IntegrationTableMapping">The mapping that is being run.</param>
    /// <returns>The assigned module, or Dataverse when the mapping has no assignment.</returns>
    internal procedure GetModule(IntegrationTableMapping: Record "Integration Table Mapping"): Enum "DVI Integration Module"
    var
        MappingAssignment: Record "DVI Mapping Assignment";
    begin
        MappingAssignment.SetLoadFields(Module);
        if MappingAssignment.Get(GetCouplingMappingName(IntegrationTableMapping)) then
            exit(MappingAssignment.Module);
        exit(Enum::"DVI Integration Module"::DVIDataverse);
    end;
}
