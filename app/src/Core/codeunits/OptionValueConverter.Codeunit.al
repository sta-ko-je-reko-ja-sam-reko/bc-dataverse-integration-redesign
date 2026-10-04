namespace DataverseIntegration.Core;

using Microsoft.Integration.Dataverse;
using Microsoft.Integration.SyncEngine;
using System.Reflection;

codeunit 80045 "DVI Option Value Converter" implements "DVI IValueConverter"
{
    Access = Public;

    procedure AppliesTo(var Context: Codeunit "DVI Sync Context"; var SourceFieldRef: FieldRef; var DestinationFieldRef: FieldRef): Boolean
    begin
        if (SourceFieldRef.Type() = FieldType::Option) and (DestinationFieldRef.Relation() <> 0) then
            exit(IsOptionMappedTable(DestinationFieldRef.Relation()));
        if (DestinationFieldRef.Type() = FieldType::Option) and (SourceFieldRef.Relation() <> 0) then
            exit(IsOptionMappedTable(SourceFieldRef.Relation()));
        exit(false);
    end;

    procedure Convert(var Context: Codeunit "DVI Sync Context"; var SourceFieldRef: FieldRef; var DestinationFieldRef: FieldRef; var NewValue: Variant; var NeedsConversion: Boolean): Boolean
    var
        CRMSynchHelper: Codeunit "CRM Synch. Helper";
        OptionValue: Integer;
        TableValue: Text;
    begin
        NeedsConversion := false;
        if CRMSynchHelper.ConvertTableToOption(SourceFieldRef, DestinationFieldRef, OptionValue) then begin
            NewValue := OptionValue;
            NeedsConversion := true;
            exit(true);
        end;
        if CRMSynchHelper.ConvertOptionToTable(SourceFieldRef, DestinationFieldRef, TableValue) then begin
            NewValue := TableValue;
            exit(true);
        end;
        exit(false);
    end;

    local procedure IsOptionMappedTable(TableId: Integer): Boolean
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        "Field": Record "Field";
    begin
        IntegrationTableMapping.SetRange(Type, IntegrationTableMapping.Type::Dataverse);
        IntegrationTableMapping.SetRange("Table ID", TableId);
        IntegrationTableMapping.SetRange("Int. Table UID Field Type", Field.Type::Option);
        exit(not IntegrationTableMapping.IsEmpty());
    end;
}
