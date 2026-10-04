namespace DataverseIntegration.Core;

using Microsoft.Integration.Dataverse;
using Microsoft.Integration.SyncEngine;
using System.Reflection;

codeunit 80025 "DVI Standard Option Source" implements "DVI IOptionSource"
{
    Access = Public;

    procedure GetOptionSetField(var Context: Codeunit "DVI Sync Context"; var EntityName: Text; var FieldName: Text)
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        TableMetadata: Record "Table Metadata";
        "Field": Record "Field";
    begin
        EntityName := '';
        FieldName := '';
        Context.GetMapping(IntegrationTableMapping);
        TableMetadata.SetLoadFields(ExternalName);
        if TableMetadata.Get(IntegrationTableMapping."Integration Table ID") then
            EntityName := TableMetadata.ExternalName;
        Field.SetLoadFields(ExternalName);
        if Field.Get(IntegrationTableMapping."Integration Table ID", IntegrationTableMapping."Integration Table UID Fld. No.") then
            FieldName := Field.ExternalName;
    end;

    procedure LoadOptions(var Context: Codeunit "DVI Sync Context"; var TempOptionValue: Record "DVI Option Value" temporary)
    var
        CDSIntegrationMgt: Codeunit "CDS Integration Mgt.";
        OptionLabels: Dictionary of [Integer, Text];
        EntityName: Text;
        FieldName: Text;
        OptionId: Integer;
    begin
        TempOptionValue.Reset();
        TempOptionValue.DeleteAll(false);
        GetOptionSetField(Context, EntityName, FieldName);
        if (EntityName = '') or (FieldName = '') then
            exit;
        OptionLabels := CDSIntegrationMgt.GetOptionSetMetadata(EntityName, FieldName);
        foreach OptionId in OptionLabels.Keys() do begin
            TempOptionValue.Init();
            TempOptionValue."Option Id" := OptionId;
            TempOptionValue."Code" := CopyStr(OptionLabels.Get(OptionId), 1, MaxStrLen(TempOptionValue."Code"));
            TempOptionValue.Insert(false);
        end;
    end;
}
