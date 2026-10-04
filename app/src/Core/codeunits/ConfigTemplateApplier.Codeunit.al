namespace DataverseIntegration.Core;

using Microsoft.Finance.Dimension;
using Microsoft.Integration.SyncEngine;
using System.IO;

codeunit 80022 "DVI Config. Template Applier"
{
    Access = Internal;

    var
        LastError: Text;
        TemplateNotFoundErr: Label 'The %1 %2 was not found.', Comment = '%1 = configuration template table caption, %2 = template code';

    /// <summary>
    /// Applies the configuration template that the mapping's template rules select for a newly inserted destination record.
    /// </summary>
    /// <param name="IntegrationTableMapping">The mapping being run.</param>
    /// <param name="SourceRecordRef">The record being synchronized; the template rules filter on it.</param>
    /// <param name="DestinationRecordRef">The inserted record that receives the template values.</param>
    /// <returns>False when a rule names a template that does not exist; GetLastError then returns the reason.</returns>
    internal procedure Apply(IntegrationTableMapping: Record "Integration Table Mapping"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef): Boolean
    var
        ConfigTemplateHeader: Record "Config. Template Header";
        ConfigTemplateManagement: Codeunit "Config. Template Management";
        TemplateCode: Code[10];
    begin
        LastError := '';
        if DestinationRecordRef.Number() = IntegrationTableMapping."Integration Table ID" then
            TemplateCode := FindIntegrationTableTemplate(IntegrationTableMapping, SourceRecordRef)
        else
            TemplateCode := FindTableTemplate(IntegrationTableMapping, SourceRecordRef);
        if TemplateCode = '' then
            exit(true);
        if not ConfigTemplateHeader.Get(TemplateCode) then begin
            LastError := StrSubstNo(TemplateNotFoundErr, ConfigTemplateHeader.TableCaption(), TemplateCode);
            exit(false);
        end;
        ConfigTemplateManagement.UpdateRecord(ConfigTemplateHeader, DestinationRecordRef);
        if DestinationRecordRef.Number() <> IntegrationTableMapping."Integration Table ID" then
            InsertDimensions(ConfigTemplateHeader, DestinationRecordRef);
        exit(true);
    end;

    /// <summary>
    /// Returns why the last Apply failed.
    /// </summary>
    /// <returns>The error text, or an empty text after a successful Apply.</returns>
    internal procedure GetLastError(): Text
    begin
        exit(LastError);
    end;

    local procedure FindTableTemplate(IntegrationTableMapping: Record "Integration Table Mapping"; var SourceRecordRef: RecordRef): Code[10]
    var
        TableConfigTemplate: Record "Table Config Template";
        TemplateFilter: Text;
    begin
        TableConfigTemplate.SetRange("Integration Table Mapping Name", RuleOwnerName(IntegrationTableMapping));
        TableConfigTemplate.SetCurrentKey(Priority);
        TableConfigTemplate.SetAscending(Priority, true);
        if TableConfigTemplate.FindSet() then
            repeat
                TemplateFilter := TableConfigTemplate.GetIntegrationTableFilter();
                if TemplateFilter = '' then
                    exit(TableConfigTemplate."Table Config Template Code");
                if MatchesFilter(SourceRecordRef, TemplateFilter, IntegrationTableMapping."Integration Table UID Fld. No.") then
                    exit(TableConfigTemplate."Table Config Template Code");
            until TableConfigTemplate.Next() = 0;
        exit('');
    end;

    local procedure FindIntegrationTableTemplate(IntegrationTableMapping: Record "Integration Table Mapping"; var SourceRecordRef: RecordRef): Code[10]
    var
        IntTableConfigTemplate: Record "Int. Table Config Template";
        TemplateFilter: Text;
    begin
        IntTableConfigTemplate.SetRange("Integration Table Mapping Name", RuleOwnerName(IntegrationTableMapping));
        IntTableConfigTemplate.SetCurrentKey(Priority);
        IntTableConfigTemplate.SetAscending(Priority, true);
        if IntTableConfigTemplate.FindSet() then
            repeat
                TemplateFilter := IntTableConfigTemplate.GetTableFilter();
                if TemplateFilter = '' then
                    exit(IntTableConfigTemplate."Int. Tbl. Config Template Code");
                if MatchesFilter(SourceRecordRef, TemplateFilter, SourceRecordRef.SystemIdNo()) then
                    exit(IntTableConfigTemplate."Int. Tbl. Config Template Code");
            until IntTableConfigTemplate.Next() = 0;
        exit('');
    end;

    local procedure RuleOwnerName(IntegrationTableMapping: Record "Integration Table Mapping"): Code[20]
    begin
        if IntegrationTableMapping."Parent Name" <> '' then
            exit(IntegrationTableMapping."Parent Name");
        exit(IntegrationTableMapping.Name);
    end;

    local procedure MatchesFilter(var SourceRecordRef: RecordRef; TemplateFilter: Text; KeyFieldNo: Integer): Boolean
    var
        SearchRecordRef: RecordRef;
        SearchFieldRef: FieldRef;
    begin
        SearchRecordRef.Open(SourceRecordRef.Number());
        SearchRecordRef.SetView(TemplateFilter);
        SearchFieldRef := SearchRecordRef.Field(KeyFieldNo);
        SearchFieldRef.SetRange(SourceRecordRef.Field(KeyFieldNo).Value());
        exit(not SearchRecordRef.IsEmpty());
    end;

    local procedure InsertDimensions(ConfigTemplateHeader: Record "Config. Template Header"; var DestinationRecordRef: RecordRef)
    var
        DimensionsTemplate: Record "Dimensions Template";
        PrimaryKeyFieldRef: FieldRef;
        PrimaryKeyRef: KeyRef;
    begin
        PrimaryKeyRef := DestinationRecordRef.KeyIndex(1);
        if PrimaryKeyRef.FieldCount() <> 1 then
            exit;
        PrimaryKeyFieldRef := PrimaryKeyRef.FieldIndex(1);
        if PrimaryKeyFieldRef.Type() <> FieldType::Code then
            exit;
        DimensionsTemplate.InsertDimensionsFromTemplates(
          ConfigTemplateHeader, CopyStr(Format(PrimaryKeyFieldRef.Value()), 1, 20), DestinationRecordRef.Number());
        DestinationRecordRef.Get(DestinationRecordRef.RecordId());
    end;
}
