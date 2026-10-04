namespace DataverseIntegration.Core;

using Microsoft.Integration.SyncEngine;

codeunit 80020 "DVI Mapping Resolver"
{
    Access = Internal;

    /// <summary>
    /// Returns the mapping that owns the handler and module. A temporary mapping created for a single synchronization (Synchronize now) inherits them from its parent.
    /// </summary>
    /// <param name="IntegrationTableMapping">The mapping that is being run.</param>
    /// <param name="OwningIntegrationTableMapping">Receives the mapping that holds the handler and module.</param>
    internal procedure GetOwningMapping(IntegrationTableMapping: Record "Integration Table Mapping"; var OwningIntegrationTableMapping: Record "Integration Table Mapping")
    begin
        OwningIntegrationTableMapping := IntegrationTableMapping;
        if IntegrationTableMapping."Parent Name" = '' then
            exit;
        OwningIntegrationTableMapping.SetLoadFields(Name, "DVI Handler", "DVI Module");
        if not OwningIntegrationTableMapping.Get(IntegrationTableMapping."Parent Name") then
            OwningIntegrationTableMapping := IntegrationTableMapping;
    end;

    /// <summary>
    /// Returns whether a mapping runs the redesigned synchronization.
    /// </summary>
    /// <param name="IntegrationTableMapping">The mapping that is being run.</param>
    /// <returns>True when the owning mapping has a handler other than Microsoft.</returns>
    internal procedure IsSwitched(IntegrationTableMapping: Record "Integration Table Mapping"): Boolean
    begin
        exit(GetHandler(IntegrationTableMapping) <> Enum::"DVI Sync Handler"::DVIMicrosoft);
    end;

    /// <summary>
    /// Returns the synchronization handler of a mapping.
    /// </summary>
    /// <param name="IntegrationTableMapping">The mapping that is being run.</param>
    /// <returns>The handler of the owning mapping.</returns>
    internal procedure GetHandler(IntegrationTableMapping: Record "Integration Table Mapping"): Enum "DVI Sync Handler"
    var
        OwningIntegrationTableMapping: Record "Integration Table Mapping";
    begin
        GetOwningMapping(IntegrationTableMapping, OwningIntegrationTableMapping);
        exit(OwningIntegrationTableMapping."DVI Handler");
    end;

    /// <summary>
    /// Returns the integration module of a mapping.
    /// </summary>
    /// <param name="IntegrationTableMapping">The mapping that is being run.</param>
    /// <returns>The module of the owning mapping.</returns>
    internal procedure GetModule(IntegrationTableMapping: Record "Integration Table Mapping"): Enum "DVI Integration Module"
    var
        OwningIntegrationTableMapping: Record "Integration Table Mapping";
    begin
        GetOwningMapping(IntegrationTableMapping, OwningIntegrationTableMapping);
        exit(OwningIntegrationTableMapping."DVI Module");
    end;

    /// <summary>
    /// Returns the name stored on couplings created through a mapping: the owning mapping, never a temporary copy.
    /// </summary>
    /// <param name="IntegrationTableMapping">The mapping that is being run.</param>
    /// <returns>The name of the owning mapping.</returns>
    internal procedure GetCouplingMappingName(IntegrationTableMapping: Record "Integration Table Mapping"): Code[20]
    var
        OwningIntegrationTableMapping: Record "Integration Table Mapping";
    begin
        GetOwningMapping(IntegrationTableMapping, OwningIntegrationTableMapping);
        exit(OwningIntegrationTableMapping.Name);
    end;
}
