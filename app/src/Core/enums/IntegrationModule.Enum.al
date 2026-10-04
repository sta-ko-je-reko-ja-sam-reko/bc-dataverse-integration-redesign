namespace DataverseIntegration.Core;

enum 80001 "DVI Integration Module" implements "DVI IConnection"
{
    Caption = 'Integration Module';
    Extensible = true;
    DefaultImplementation = "DVI IConnection" = "DVI Dataverse Connection";

    value(0; DVIDataverse)
    {
        Caption = 'Dataverse';
        Implementation = "DVI IConnection" = "DVI Dataverse Connection";
    }
    value(1; DVISales)
    {
        Caption = 'Dynamics 365 Sales';
        Implementation = "DVI IConnection" = "DVI Sales Connection";
    }
    value(2; DVIFieldService)
    {
        Caption = 'Dynamics 365 Field Service';
        Implementation = "DVI IConnection" = "DVI Field Service Connection";
    }
}
