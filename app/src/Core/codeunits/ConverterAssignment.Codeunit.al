namespace DataverseIntegration.Core;

using Microsoft.Integration.SyncEngine;

codeunit 80047 "DVI Converter Assignment"
{
    Access = Internal;

    /// <summary>
    /// Assigns a converter to every field mapping of a mapping that has none yet: the first converter value that applies to the field pair, or Direct.
    /// </summary>
    /// <param name="IntegrationTableMapping">The mapping.</param>
    internal procedure AssignDefaults(IntegrationTableMapping: Record "Integration Table Mapping")
    var
        IntegrationFieldMapping: Record "Integration Field Mapping";
        FieldConverter: Record "DVI Field Converter";
    begin
        IntegrationFieldMapping.SetRange("Integration Table Mapping Name", IntegrationTableMapping.Name);
        if not IntegrationFieldMapping.FindSet() then
            exit;
        repeat
            if not FieldConverter.Get(IntegrationTableMapping.Name, IntegrationFieldMapping."Field No.", IntegrationFieldMapping."Integration Table Field No.") then begin
                FieldConverter.Init();
                FieldConverter."Mapping Name" := IntegrationTableMapping.Name;
                FieldConverter."Field No." := IntegrationFieldMapping."Field No.";
                FieldConverter."Integration Table Field No." := IntegrationFieldMapping."Integration Table Field No.";
                FieldConverter.Converter := FindDefaultConverter(IntegrationTableMapping, IntegrationFieldMapping);
                FieldConverter.Insert(true);
            end;
        until IntegrationFieldMapping.Next() = 0;
    end;

    /// <summary>
    /// Returns the converter assigned to a field mapping.
    /// </summary>
    /// <param name="MappingName">The owning mapping.</param>
    /// <param name="FieldNo">The Business Central field.</param>
    /// <param name="IntegrationTableFieldNo">The Dataverse field.</param>
    /// <returns>The assigned converter, or Direct.</returns>
    internal procedure GetConverter(MappingName: Code[20]; FieldNo: Integer; IntegrationTableFieldNo: Integer): Enum "DVI Value Converter"
    var
        FieldConverter: Record "DVI Field Converter";
    begin
        FieldConverter.SetLoadFields(Converter);
        if FieldConverter.Get(MappingName, FieldNo, IntegrationTableFieldNo) then
            exit(FieldConverter.Converter);
        exit(Enum::"DVI Value Converter"::DVIDirect);
    end;

    local procedure FindDefaultConverter(IntegrationTableMapping: Record "Integration Table Mapping"; IntegrationFieldMapping: Record "Integration Field Mapping"): Enum "DVI Value Converter"
    var
        Context: Codeunit "DVI Sync Context";
        LocalRecordRef: RecordRef;
        IntegrationRecordRef: RecordRef;
        SourceFieldRef: FieldRef;
        DestinationFieldRef: FieldRef;
        ValueConverter: Interface "DVI IValueConverter";
        Candidate: Enum "DVI Value Converter";
        Ordinal: Integer;
    begin
        if (IntegrationFieldMapping."Field No." <= 0) or (IntegrationFieldMapping."Integration Table Field No." <= 0) then
            exit(Enum::"DVI Value Converter"::DVIDirect);
        LocalRecordRef.Open(IntegrationTableMapping."Table ID", true);
        IntegrationRecordRef.Open(IntegrationTableMapping."Integration Table ID", true);
        if not (LocalRecordRef.FieldExist(IntegrationFieldMapping."Field No.") and IntegrationRecordRef.FieldExist(IntegrationFieldMapping."Integration Table Field No.")) then
            exit(Enum::"DVI Value Converter"::DVIDirect);
        Context.SetMapping(IntegrationTableMapping);
        Context.SetToIntegrationTable(SendsToIntegrationTable(IntegrationTableMapping, IntegrationFieldMapping));
        if Context.IsToIntegrationTable() then begin
            SourceFieldRef := LocalRecordRef.Field(IntegrationFieldMapping."Field No.");
            DestinationFieldRef := IntegrationRecordRef.Field(IntegrationFieldMapping."Integration Table Field No.");
        end else begin
            SourceFieldRef := IntegrationRecordRef.Field(IntegrationFieldMapping."Integration Table Field No.");
            DestinationFieldRef := LocalRecordRef.Field(IntegrationFieldMapping."Field No.");
        end;
        foreach Ordinal in Enum::"DVI Value Converter".Ordinals() do
            if Ordinal <> Enum::"DVI Value Converter"::DVIDirect.AsInteger() then begin
                Candidate := Enum::"DVI Value Converter".FromInteger(Ordinal);
                ValueConverter := Candidate;
                if ValueConverter.AppliesTo(Context, SourceFieldRef, DestinationFieldRef) then
                    exit(Candidate);
            end;
        exit(Enum::"DVI Value Converter"::DVIDirect);
    end;

    local procedure SendsToIntegrationTable(IntegrationTableMapping: Record "Integration Table Mapping"; IntegrationFieldMapping: Record "Integration Field Mapping"): Boolean
    begin
        if IntegrationTableMapping.Direction = IntegrationTableMapping.Direction::FromIntegrationTable then
            exit(false);
        exit(IntegrationFieldMapping.Direction <> IntegrationFieldMapping.Direction::FromIntegrationTable);
    end;
}
