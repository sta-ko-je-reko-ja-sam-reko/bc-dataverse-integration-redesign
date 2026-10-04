namespace DataverseIntegration.Core;

enum 80004 "DVI Value Converter" implements "DVI IValueConverter"
{
    Caption = 'Value Converter';
    Extensible = true;
    DefaultImplementation = "DVI IValueConverter" = "DVI Direct Converter";

    value(0; DVIDirect)
    {
        Caption = 'Direct';
        Implementation = "DVI IValueConverter" = "DVI Direct Converter";
    }
    value(10; DVIOwner)
    {
        Caption = 'Owner';
        Implementation = "DVI IValueConverter" = "DVI Owner Converter";
    }
    value(20; DVIPrimaryContact)
    {
        Caption = 'Primary contact';
        Implementation = "DVI IValueConverter" = "DVI Primary Contact Converter";
    }
    value(30; DVICurrency)
    {
        Caption = 'Currency';
        Implementation = "DVI IValueConverter" = "DVI Currency Converter";
    }
    value(40; DVIUnitOfMeasure)
    {
        Caption = 'Unit of measure';
        Implementation = "DVI IValueConverter" = "DVI Unit of Measure Converter";
    }
    value(50; DVIOptionValue)
    {
        Caption = 'Option value';
        Implementation = "DVI IValueConverter" = "DVI Option Value Converter";
    }
    value(60; DVICoupledRecordKey)
    {
        Caption = 'Coupled record key';
        Implementation = "DVI IValueConverter" = "DVI Coupled Key Converter";
    }
}
