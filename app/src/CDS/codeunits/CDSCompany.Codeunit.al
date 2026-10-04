namespace DataverseIntegration.CDS;

using Microsoft.Integration.D365Sales;
using Microsoft.Integration.Dataverse;

codeunit 80220 "DVI CDS Company"
{
    Access = Internal;

    /// <summary>
    /// Stamps the Business Central company on a Dataverse record that does not carry it yet.
    /// </summary>
    /// <param name="IntegrationRecordRef">The Dataverse record, before it is inserted or modified.</param>
    internal procedure SetCompanyId(var IntegrationRecordRef: RecordRef)
    var
        CDSIntegrationMgt: Codeunit "CDS Integration Mgt.";
    begin
        if CDSIntegrationMgt.CheckCompanyId(IntegrationRecordRef) then
            exit;
        CDSIntegrationMgt.SetCompanyId(IntegrationRecordRef);
    end;

    /// <summary>
    /// Sets the owner of a new Dataverse record by the ownership model: the default owning team, or the user coupled to the record's salesperson.
    /// </summary>
    /// <param name="LocalRecordRef">The Business Central record.</param>
    /// <param name="IntegrationRecordRef">The new Dataverse record.</param>
    internal procedure SetOwner(var LocalRecordRef: RecordRef; var IntegrationRecordRef: RecordRef)
    var
        CDSConnectionSetup: Record "CDS Connection Setup";
        CDSIntegrationMgt: Codeunit "CDS Integration Mgt.";
        CRMSynchHelper: Codeunit "CRM Synch. Helper";
        UserId: Guid;
    begin
        CDSConnectionSetup.SetLoadFields("Ownership Model");
        if not CDSConnectionSetup.Get() then
            exit;
        case CDSConnectionSetup."Ownership Model" of
            CDSConnectionSetup."Ownership Model"::Team:
                CDSIntegrationMgt.SetOwningTeam(IntegrationRecordRef);
            CDSConnectionSetup."Ownership Model"::Person:
                begin
                    UserId := CRMSynchHelper.GetCoupledCDSUserId(LocalRecordRef);
                    if IsNullGuid(UserId) then
                        CDSIntegrationMgt.SetOwningTeam(IntegrationRecordRef)
                    else
                        CDSIntegrationMgt.SetOwningUser(IntegrationRecordRef, UserId, true);
                end;
        end;
    end;

    /// <summary>
    /// Removes the Business Central company from a Dataverse record whose coupling is being removed.
    /// </summary>
    /// <param name="IntegrationRecordRef">The Dataverse record; ignored when it is closed or empty.</param>
    internal procedure ResetCompanyId(var IntegrationRecordRef: RecordRef)
    var
        CDSIntegrationMgt: Codeunit "CDS Integration Mgt.";
    begin
        if IntegrationRecordRef.Number() = 0 then
            exit;
        if not CDSIntegrationMgt.HasCompanyIdField(IntegrationRecordRef.Number()) then
            exit;
        if IntegrationRecordRef.IsEmpty() then
            exit;
        CDSIntegrationMgt.ResetCompanyId(IntegrationRecordRef);
    end;

    /// <summary>
    /// Writes the Business Central company back to a Dataverse account that was just created in Business Central.
    /// </summary>
    /// <param name="AccountRecordRef">The Dataverse account.</param>
    internal procedure StampCompanyIdOnAccount(var AccountRecordRef: RecordRef)
    var
        CRMAccount: Record "CRM Account";
        CDSIntegrationMgt: Codeunit "CDS Integration Mgt.";
        StampRecordRef: RecordRef;
    begin
        if CDSIntegrationMgt.CheckCompanyId(AccountRecordRef) then
            exit;
        AccountRecordRef.SetTable(CRMAccount);
        CRMAccount.SetAutoCalcFields(CreatedByName, ModifiedByName, TransactionCurrencyIdName);
        CRMAccount.Find();
        StampRecordRef.GetTable(CRMAccount);
        CDSIntegrationMgt.SetCompanyId(StampRecordRef);
        StampRecordRef.Modify();
        CRMAccount.Find();
        AccountRecordRef.GetTable(CRMAccount);
    end;

    /// <summary>
    /// Writes the Business Central company back to a Dataverse contact that was just created in Business Central.
    /// </summary>
    /// <param name="ContactRecordRef">The Dataverse contact.</param>
    internal procedure StampCompanyIdOnContact(var ContactRecordRef: RecordRef)
    var
        CRMContact: Record "CRM Contact";
        CDSIntegrationMgt: Codeunit "CDS Integration Mgt.";
        StampRecordRef: RecordRef;
    begin
        if CDSIntegrationMgt.CheckCompanyId(ContactRecordRef) then
            exit;
        ContactRecordRef.SetTable(CRMContact);
        CRMContact.SetAutoCalcFields(CreatedByName, ModifiedByName, TransactionCurrencyIdName);
        CRMContact.Find();
        StampRecordRef.GetTable(CRMContact);
        CDSIntegrationMgt.SetCompanyId(StampRecordRef);
        StampRecordRef.Modify();
        CRMContact.Find();
        ContactRecordRef.GetTable(CRMContact);
    end;
}
