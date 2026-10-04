namespace DataverseIntegration.Core;

codeunit 80040 "DVI Direct Converter" implements "DVI IValueConverter"
{
    Access = Public;

    procedure AppliesTo(var Context: Codeunit "DVI Sync Context"; var SourceFieldRef: FieldRef; var DestinationFieldRef: FieldRef): Boolean
    begin
        exit(false);
    end;

    procedure Convert(var Context: Codeunit "DVI Sync Context"; var SourceFieldRef: FieldRef; var DestinationFieldRef: FieldRef; var NewValue: Variant; var NeedsConversion: Boolean): Boolean
    begin
        NeedsConversion := false;
        exit(false);
    end;
}
