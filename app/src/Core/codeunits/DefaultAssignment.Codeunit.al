namespace DataverseIntegration.Core;

using Microsoft.Integration.Dataverse;
using Microsoft.Integration.SyncEngine;

codeunit 80017 "DVI Default Assignment"
{
    Access = Internal;

    /// <summary>
    /// Switches a mapping to the redesigned synchronization with its default handler: the first handler value that serves the mapping's table pair, or Generic.
    /// </summary>
    /// <param name="IntegrationTableMapping">The mapping to switch.</param>
    internal procedure SwitchToRedesigned(IntegrationTableMapping: Record "Integration Table Mapping")
    var
        MappingAssignment: Record "DVI Mapping Assignment";
        Context: Codeunit "DVI Sync Context";
        HandlerScope: Interface "DVI IHandlerScope";
        Handler: Enum "DVI Sync Handler";
    begin
        Context.SetMapping(IntegrationTableMapping);
        Handler := FindDefaultHandler(Context);
        HandlerScope := Handler;
        if not MappingAssignment.Get(IntegrationTableMapping.Name) then begin
            MappingAssignment.Init();
            MappingAssignment."Mapping Name" := IntegrationTableMapping.Name;
            MappingAssignment.Insert(true);
        end;
        MappingAssignment.Validate(Handler, Handler);
        MappingAssignment.Validate(Module, HandlerScope.DefaultModule(Context));
        MappingAssignment.Modify(true);
    end;

    /// <summary>
    /// Returns a mapping to the standard synchronization. The assignment is kept, with the Microsoft handler.
    /// </summary>
    /// <param name="IntegrationTableMapping">The mapping to switch back.</param>
    internal procedure SwitchToStandard(IntegrationTableMapping: Record "Integration Table Mapping")
    var
        MappingAssignment: Record "DVI Mapping Assignment";
    begin
        if not MappingAssignment.Get(IntegrationTableMapping.Name) then
            exit;
        MappingAssignment.Validate(Handler, Enum::"DVI Sync Handler"::DVIMicrosoft);
        MappingAssignment.Modify(true);
    end;

    /// <summary>
    /// Switches every mapping that the redesigned synchronization can run to its default handler.
    /// </summary>
    /// <returns>The number of mappings switched.</returns>
    internal procedure SwitchAllToRedesigned() SwitchedCount: Integer
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
    begin
        IntegrationTableMapping.SetRange(Type, IntegrationTableMapping.Type::Dataverse);
        IntegrationTableMapping.SetRange("Synch. Codeunit ID", Codeunit::"CRM Integration Table Synch.");
        IntegrationTableMapping.SetRange("Delete After Synchronization", false);
        if IntegrationTableMapping.FindSet() then
            repeat
                SwitchToRedesigned(IntegrationTableMapping);
                SwitchedCount += 1;
            until IntegrationTableMapping.Next() = 0;
    end;

    local procedure FindDefaultHandler(var Context: Codeunit "DVI Sync Context"): Enum "DVI Sync Handler"
    var
        HandlerScope: Interface "DVI IHandlerScope";
        Candidate: Enum "DVI Sync Handler";
        Ordinal: Integer;
    begin
        foreach Ordinal in Enum::"DVI Sync Handler".Ordinals() do
            if not (Ordinal in [Enum::"DVI Sync Handler"::DVIMicrosoft.AsInteger(), Enum::"DVI Sync Handler"::DVIGeneric.AsInteger()]) then begin
                Candidate := Enum::"DVI Sync Handler".FromInteger(Ordinal);
                HandlerScope := Candidate;
                if HandlerScope.Serves(Context) then
                    exit(Candidate);
            end;
        exit(Enum::"DVI Sync Handler"::DVIGeneric);
    end;
}
