namespace DataverseIntegration.Core;

using Microsoft.Integration.Dataverse;

codeunit 80034 "DVI UI Events"
{
    Access = Internal;
    SingleInstance = true;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"CRM Integration Management", OnBeforeOpenCoupledNavRecordPage, '', true, true)]
    local procedure OnBeforeOpenCoupledRecordPage(CRMID: Guid; CRMEntityTypeName: Text; var Result: Boolean; var IsHandled: Boolean)
    var
        ServiceLocator: Codeunit "DVI Service Locator";
    begin
        ServiceLocator.RedirectTarget().OpenCoupledRecord(CRMID, CRMEntityTypeName, Result, IsHandled);
    end;
}
