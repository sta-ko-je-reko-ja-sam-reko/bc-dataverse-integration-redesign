namespace DataverseIntegration.Core;

using Microsoft.CRM.Outlook;
using Microsoft.Integration.SyncEngine;
using System.Reflection;
using System.Utilities;

codeunit 80008 "DVI Field Transfer"
{
    Access = Internal;

    var
        TempIntegrationFieldMapping: Record "Temp Integration Field Mapping" temporary;
        OutlookSynchTypeConv: Codeunit "Outlook Synch. Type Conv";
        AnyFieldModified: Boolean;
        BidirectionalFieldModified: Boolean;
        ConflictSourceFieldNo: Integer;
        ConflictDestinationFieldNo: Integer;

    /// <summary>
    /// Loads the enabled field mappings of a mapping for one direction.
    /// </summary>
    /// <param name="IntegrationTableMapping">The mapping.</param>
    /// <param name="ToIntegrationTable">True for Business Central to Dataverse, false for Dataverse to Business Central.</param>
    /// <returns>False when the mapping has no enabled field mappings in this direction.</returns>
    internal procedure LoadFieldMappings(IntegrationTableMapping: Record "Integration Table Mapping"; ToIntegrationTable: Boolean): Boolean
    var
        IntegrationFieldMapping: Record "Integration Field Mapping";
        Direction: Option Bidirectional,ToIntegrationTable,FromIntegrationTable;
    begin
        TempIntegrationFieldMapping.Reset();
        TempIntegrationFieldMapping.DeleteAll(false);
        if ToIntegrationTable then
            Direction := Direction::ToIntegrationTable
        else
            Direction := Direction::FromIntegrationTable;
        IntegrationFieldMapping.SetLoadFields("No.", "Integration Table Mapping Name", "Field No.", "Integration Table Field No.", Direction,
          "Constant Value", "Not Null", "Validate Field", "Validate Integration Table Fld", Status);
        IntegrationFieldMapping.SetRange("Integration Table Mapping Name", IntegrationTableMapping.Name);
        IntegrationFieldMapping.SetFilter(Direction, '%1|%2', Direction, IntegrationFieldMapping.Direction::Bidirectional);
        IntegrationFieldMapping.SetFilter(Status, '<>%1', IntegrationFieldMapping.Status::Disabled);
        if not IntegrationFieldMapping.FindSet() then
            exit(false);
        repeat
            AddFieldMapping(IntegrationFieldMapping, ToIntegrationTable);
        until IntegrationFieldMapping.Next() = 0;
        exit(true);
    end;

    /// <summary>
    /// Transfers the loaded field mappings from the source record to the destination record.
    /// </summary>
    /// <param name="SourceRecordRef">The record being synchronized.</param>
    /// <param name="DestinationRecordRef">The record that receives the values.</param>
    /// <param name="OnlyModified">True to transfer only values that differ; false for a new destination, where every value is set.</param>
    internal procedure TransferFields(var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef; OnlyModified: Boolean)
    begin
        AnyFieldModified := false;
        BidirectionalFieldModified := false;
        ConflictSourceFieldNo := 0;
        ConflictDestinationFieldNo := 0;
        TempIntegrationFieldMapping.Reset();
        if not TempIntegrationFieldMapping.FindSet() then
            exit;
        repeat
            if TransferField(SourceRecordRef, DestinationRecordRef, OnlyModified) then begin
                AnyFieldModified := true;
                if TempIntegrationFieldMapping.Bidirectional and not BidirectionalFieldModified then begin
                    BidirectionalFieldModified := true;
                    ConflictSourceFieldNo := TempIntegrationFieldMapping."Source Field No.";
                    ConflictDestinationFieldNo := TempIntegrationFieldMapping."Destination Field No.";
                end;
            end;
        until TempIntegrationFieldMapping.Next() = 0;
    end;

    /// <summary>
    /// Returns whether the last transfer changed any destination field.
    /// </summary>
    /// <returns>True when at least one field changed.</returns>
    internal procedure WasModified(): Boolean
    begin
        exit(AnyFieldModified);
    end;

    /// <summary>
    /// Returns whether the last transfer changed a field whose mapping is bidirectional.
    /// </summary>
    /// <returns>True when a bidirectional field changed.</returns>
    internal procedure WasBidirectionalFieldModified(): Boolean
    begin
        exit(BidirectionalFieldModified);
    end;

    /// <summary>
    /// Returns the first bidirectional field pair that changed, for the conflict message.
    /// </summary>
    /// <param name="SourceFieldNo">Receives the source field number.</param>
    /// <param name="DestinationFieldNo">Receives the destination field number.</param>
    internal procedure GetConflictFields(var SourceFieldNo: Integer; var DestinationFieldNo: Integer)
    begin
        SourceFieldNo := ConflictSourceFieldNo;
        DestinationFieldNo := ConflictDestinationFieldNo;
    end;

    local procedure AddFieldMapping(IntegrationFieldMapping: Record "Integration Field Mapping"; ToIntegrationTable: Boolean)
    begin
        TempIntegrationFieldMapping.Init();
        TempIntegrationFieldMapping."No." := IntegrationFieldMapping."No.";
        TempIntegrationFieldMapping."Integration Table Mapping Name" := IntegrationFieldMapping."Integration Table Mapping Name";
        TempIntegrationFieldMapping."Constant Value" := IntegrationFieldMapping."Constant Value";
        TempIntegrationFieldMapping."Not Null" := IntegrationFieldMapping."Not Null";
        TempIntegrationFieldMapping.Bidirectional := IntegrationFieldMapping.Direction = IntegrationFieldMapping.Direction::Bidirectional;
        if ToIntegrationTable then begin
            TempIntegrationFieldMapping."Source Field No." := IntegrationFieldMapping."Field No.";
            TempIntegrationFieldMapping."Destination Field No." := IntegrationFieldMapping."Integration Table Field No.";
            TempIntegrationFieldMapping."Validate Destination Field" := IntegrationFieldMapping."Validate Integration Table Fld";
        end else begin
            TempIntegrationFieldMapping."Source Field No." := IntegrationFieldMapping."Integration Table Field No.";
            TempIntegrationFieldMapping."Destination Field No." := IntegrationFieldMapping."Field No.";
            TempIntegrationFieldMapping."Validate Destination Field" := IntegrationFieldMapping."Validate Field";
        end;
        TempIntegrationFieldMapping.Insert(false);
    end;

    local procedure TransferField(var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef; OnlyModified: Boolean): Boolean
    var
        SourceFieldRef: FieldRef;
        DestinationFieldRef: FieldRef;
        PreviousValue: Text;
    begin
        DestinationFieldRef := DestinationRecordRef.Field(TempIntegrationFieldMapping."Destination Field No.");
        if UsesConstantValue(SourceRecordRef, DestinationRecordRef) then begin
            if OnlyModified and not IsConstantDifferent(TempIntegrationFieldMapping."Constant Value", DestinationFieldRef) then
                exit(false);
            PreviousValue := GetTextValue(DestinationFieldRef);
            if not EvaluateTextToFieldRef(TempIntegrationFieldMapping."Constant Value", DestinationFieldRef, true) then
                exit(false);
            exit((PreviousValue <> GetTextValue(DestinationFieldRef)) or not OnlyModified);
        end;
        SourceFieldRef := SourceRecordRef.Field(TempIntegrationFieldMapping."Source Field No.");
        if (SourceFieldRef.Class() = FieldClass::FlowField) or
           ((SourceFieldRef.Type() = FieldType::Blob) and not IsExternalTable(SourceRecordRef.Number()))
        then
            SourceFieldRef.CalcField();
        if OnlyModified and not IsFieldModified(SourceFieldRef, DestinationFieldRef) then
            exit(false);
        exit(TransferFieldValue(SourceFieldRef, DestinationFieldRef, OnlyModified));
    end;

    local procedure UsesConstantValue(var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef): Boolean
    begin
        if TempIntegrationFieldMapping."Source Field No." < 1 then
            exit(true);
        exit((TempIntegrationFieldMapping."Constant Value" <> '') and
          (SourceRecordRef.Number() = DestinationRecordRef.Number()) and
          (TempIntegrationFieldMapping."Source Field No." = TempIntegrationFieldMapping."Destination Field No."));
    end;

    local procedure TransferFieldValue(var SourceFieldRef: FieldRef; var DestinationFieldRef: FieldRef; OnlyModified: Boolean): Boolean
    var
        NewValue: Variant;
        PreviousValue: Text;
    begin
        if SourceFieldRef.Type() = FieldType::Blob then
            NewValue := GetTextValue(SourceFieldRef)
        else
            NewValue := SourceFieldRef.Value();
        if TempIntegrationFieldMapping."Not Null" and NewValue.IsGuid() then
            if IsNullGuid(NewValue) then
                exit(false);
        if CanAssignDirectly(SourceFieldRef, DestinationFieldRef, NewValue) then
            exit(SetDestinationValue(DestinationFieldRef, NewValue, OnlyModified));
        PreviousValue := GetTextValue(DestinationFieldRef);
        if not EvaluateTextToFieldRef(Format(NewValue), DestinationFieldRef, TempIntegrationFieldMapping."Validate Destination Field") then
            exit(false);
        exit((PreviousValue <> GetTextValue(DestinationFieldRef)) or not OnlyModified);
    end;

    local procedure CanAssignDirectly(var SourceFieldRef: FieldRef; var DestinationFieldRef: FieldRef; NewValue: Variant): Boolean
    begin
        if DestinationFieldRef.Type() in [FieldType::Date, FieldType::DateTime] then
            if Format(NewValue) = '' then
                exit(false);
        exit((SourceFieldRef.Type() = DestinationFieldRef.Type()) and (DestinationFieldRef.Length() >= SourceFieldRef.Length()));
    end;

    local procedure SetDestinationValue(var DestinationFieldRef: FieldRef; NewValue: Variant; OnlyModified: Boolean): Boolean
    var
        NewValueGuid: Guid;
        IsModified: Boolean;
    begin
        IsModified := (GetTextValue(DestinationFieldRef) <> Format(NewValue)) or not OnlyModified;
        case DestinationFieldRef.Type() of
            FieldType::Blob:
                SetTextValue(DestinationFieldRef, Format(NewValue));
            FieldType::Media:
                begin
                    Evaluate(NewValueGuid, Format(NewValue));
                    DestinationFieldRef.Value(NewValueGuid);
                end;
            else
                if IsModified and TempIntegrationFieldMapping."Validate Destination Field" then
                    DestinationFieldRef.Validate(NewValue)
                else
                    DestinationFieldRef.Value(NewValue);
        end;
        exit(IsModified);
    end;

    local procedure IsFieldModified(var SourceFieldRef: FieldRef; var DestinationFieldRef: FieldRef): Boolean
    begin
        if DestinationFieldRef.Type() = FieldType::Code then
            exit(Format(DestinationFieldRef.Value()) <> UpperCase(DelChr(Format(SourceFieldRef.Value()), '<>')));
        if (SourceFieldRef.Type() = FieldType::Blob) or (DestinationFieldRef.Type() = FieldType::Blob) then
            exit(GetTextValue(DestinationFieldRef) <> GetTextValue(SourceFieldRef));
        if DestinationFieldRef.Length() < SourceFieldRef.Length() then
            exit(Format(DestinationFieldRef.Value()) <> CopyStr(Format(SourceFieldRef.Value()), 1, DestinationFieldRef.Length()));
        if DestinationFieldRef.Length() > SourceFieldRef.Length() then
            exit(CopyStr(Format(DestinationFieldRef.Value()), 1, SourceFieldRef.Length()) <> Format(SourceFieldRef.Value()));
        exit(Format(DestinationFieldRef.Value()) <> Format(SourceFieldRef.Value()));
    end;

    local procedure IsConstantDifferent(ConstantValue: Text; var DestinationFieldRef: FieldRef): Boolean
    begin
        if DestinationFieldRef.Type() = FieldType::Option then
            exit(TextToOptionValue(ConstantValue, DestinationFieldRef) <> TextToOptionValue(Format(DestinationFieldRef.Value()), DestinationFieldRef));
        exit(GetTextValue(DestinationFieldRef) <> ConstantValue);
    end;

    local procedure EvaluateTextToFieldRef(InputText: Text; var FieldRef: FieldRef; ToValidate: Boolean): Boolean
    begin
        case FieldRef.Type() of
            FieldType::Option:
                exit(EvaluateTextToOptionFieldRef(InputText, FieldRef, ToValidate));
            FieldType::Blob:
                begin
                    SetTextValue(FieldRef, InputText);
                    exit(true);
                end;
        end;
        exit(OutlookSynchTypeConv.EvaluateTextToFieldRef(InputText, FieldRef, ToValidate));
    end;

    local procedure EvaluateTextToOptionFieldRef(InputText: Text; var FieldRef: FieldRef; ToValidate: Boolean): Boolean
    var
        NewValue: Integer;
        OldValue: Integer;
    begin
        if FieldRef.Class() in [FieldClass::FlowField, FieldClass::FlowFilter] then
            exit(true);
        if not Evaluate(NewValue, InputText) then
            NewValue := TextToOptionValue(InputText, FieldRef);
        if NewValue < 0 then
            exit(false);
        if ToValidate then begin
            OldValue := FieldRef.Value();
            if OldValue <> NewValue then
                FieldRef.Validate(NewValue);
        end else
            FieldRef.Value(NewValue);
        exit(true);
    end;

    local procedure TextToOptionValue(InputText: Text; var FieldRef: FieldRef): Integer
    var
        OptionValue: Integer;
    begin
        OptionValue := OutlookSynchTypeConv.TextToOptionValue(InputText, FieldRef.OptionCaption());
        if OptionValue < 0 then
            OptionValue := OutlookSynchTypeConv.TextToOptionValue(InputText, FieldRef.OptionMembers());
        exit(OptionValue);
    end;

    local procedure GetTextValue(var FieldRef: FieldRef): Text
    var
        TempBlob: Codeunit "Temp Blob";
        InStream: InStream;
        FieldValue: Text;
    begin
        if FieldRef.Type() <> FieldType::Blob then
            exit(Format(FieldRef.Value()));
        TempBlob.FromFieldRef(FieldRef);
        if TempBlob.HasValue() then begin
            TempBlob.CreateInStream(InStream, BlobEncoding(FieldRef));
            InStream.Read(FieldValue);
        end;
        exit(FieldValue);
    end;

    local procedure SetTextValue(var FieldRef: FieldRef; FieldValue: Text)
    var
        TempBlob: Codeunit "Temp Blob";
        OutStream: OutStream;
    begin
        if FieldRef.Type() <> FieldType::Blob then begin
            FieldRef.Value(FieldValue);
            exit;
        end;
        if FieldValue <> '' then begin
            TempBlob.CreateOutStream(OutStream, BlobEncoding(FieldRef));
            OutStream.Write(FieldValue);
        end;
        TempBlob.ToFieldRef(FieldRef);
    end;

    local procedure BlobEncoding(var FieldRef: FieldRef): TextEncoding
    begin
        if IsExternalTable(FieldRef.Record().Number()) then
            exit(TextEncoding::UTF16);
        exit(TextEncoding::UTF8);
    end;

    local procedure IsExternalTable(TableId: Integer): Boolean
    var
        TableMetadata: Record "Table Metadata";
    begin
        TableMetadata.SetLoadFields(TableType);
        if TableMetadata.Get(TableId) then
            exit(TableMetadata.TableType <> TableMetadata.TableType::Normal);
        exit(false);
    end;
}
