namespace DataverseIntegration.Core;

using DataverseIntegration.CRM;
using DataverseIntegration.FieldService;

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
    value(5; DVIFieldServiceValue)
    {
        Caption = 'Field Service value';
        Implementation = "DVI IValueConverter" = "DVI FS Value Converter";
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
    value(55; DVIWriteInProduct)
    {
        Caption = 'Write-in product';
        Implementation = "DVI IValueConverter" = "DVI Write-in Product Converter";
    }
    value(60; DVICoupledRecordKey)
    {
        Caption = 'Coupled record key';
        Implementation = "DVI IValueConverter" = "DVI Coupled Key Converter";
    }
}
