namespace DataverseIntegration.Core;

using Microsoft.CRM.Contact;
using Microsoft.Integration.Dataverse;

codeunit 80042 "DVI Primary Contact Converter" implements "DVI IValueConverter"
{
    Access = Public;

    var
        PrimaryContactFieldTok: Label 'Primary Contact No.', Locked = true;

    procedure AppliesTo(var Context: Codeunit "DVI Sync Context"; var SourceFieldRef: FieldRef; var DestinationFieldRef: FieldRef): Boolean
    begin
        exit((SourceFieldRef.Name() = PrimaryContactFieldTok) or (DestinationFieldRef.Name() = PrimaryContactFieldTok));
    end;

    procedure Convert(var Context: Codeunit "DVI Sync Context"; var SourceFieldRef: FieldRef; var DestinationFieldRef: FieldRef; var NewValue: Variant; var NeedsConversion: Boolean): Boolean
    var
        CoupledKeyConverter: Codeunit "DVI Coupled Key Converter";
    begin
        NeedsConversion := false;
        if (DestinationFieldRef.Name() = PrimaryContactFieldTok) and IsBlank(SourceFieldRef) and KeepsUncoupledContact(DestinationFieldRef) then begin
            NewValue := DestinationFieldRef.Value();
            exit(true);
        end;
        exit(CoupledKeyConverter.Convert(Context, SourceFieldRef, DestinationFieldRef, NewValue, NeedsConversion));
    end;

    local procedure IsBlank(var SourceFieldRef: FieldRef): Boolean
    var
        EmptyId: Guid;
    begin
        exit((Format(SourceFieldRef.Value()) = '') or (Format(SourceFieldRef.Value()) = Format(EmptyId)));
    end;

    local procedure KeepsUncoupledContact(var DestinationFieldRef: FieldRef): Boolean
    var
        Contact: Record Contact;
        CRMIntegrationRecord: Record "CRM Integration Record";
        ContactNo: Code[20];
    begin
        ContactNo := CopyStr(Format(DestinationFieldRef.Value()), 1, MaxStrLen(ContactNo));
        if ContactNo = '' then
            exit(false);
        Contact.SetLoadFields("No.");
        if not Contact.Get(ContactNo) then
            exit(false);
        exit(not CRMIntegrationRecord.FindByRecordID(Contact.RecordId()));
    end;
}
