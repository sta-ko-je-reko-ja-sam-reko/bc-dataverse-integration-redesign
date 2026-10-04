namespace DataverseIntegration.CDS;

using DataverseIntegration.Core;
using Microsoft.CRM.BusinessRelation;
using Microsoft.CRM.Contact;
using Microsoft.Integration.D365Sales;
using Microsoft.Integration.Dataverse;
using Microsoft.Integration.SyncEngine;
using Microsoft.Purchases.Vendor;
using Microsoft.Sales.Customer;

codeunit 80221 "DVI CDS Relations"
{
    Access = Internal;

    var
        RecordNotFoundErr: Label 'The %1 %2 related to the contact was not found.', Comment = '%1 = table caption, %2 = number';
        ContactMustBeRelatedErr: Label 'The contact %1 must have a contact company that has a business relation to a customer or vendor.', Comment = '%1 = contact number';
        ContactMissingCompanyErr: Label 'The contact cannot be created because the company does not exist.';

    /// <summary>
    /// Finds the Dataverse mapping between two tables, preferring one that runs the redesigned synchronization.
    /// </summary>
    /// <param name="TableId">The Business Central table.</param>
    /// <param name="IntegrationTableId">The Dataverse table.</param>
    /// <param name="IntegrationTableMapping">Receives the mapping.</param>
    /// <returns>True when a mapping exists.</returns>
    internal procedure FindMapping(TableId: Integer; IntegrationTableId: Integer; var IntegrationTableMapping: Record "Integration Table Mapping"): Boolean
    var
        MappingResolver: Codeunit "DVI Mapping Resolver";
    begin
        IntegrationTableMapping.Reset();
        IntegrationTableMapping.SetRange(Type, IntegrationTableMapping.Type::Dataverse);
        IntegrationTableMapping.SetRange("Delete After Synchronization", false);
        IntegrationTableMapping.SetRange("Table ID", TableId);
        IntegrationTableMapping.SetRange("Integration Table ID", IntegrationTableId);
        if IntegrationTableMapping.FindSet() then
            repeat
                if MappingResolver.IsSwitched(IntegrationTableMapping) then
                    exit(true);
            until IntegrationTableMapping.Next() = 0;
        exit(IntegrationTableMapping.FindFirst());
    end;

    /// <summary>
    /// Returns whether contacts may synchronize without a company related to a customer or vendor. Off by default, as in the standard integration.
    /// </summary>
    /// <returns>True when the business relation is optional.</returns>
    internal procedure IsBusinessRelationOptional(): Boolean
    begin
        exit(false);
    end;

    /// <summary>
    /// Returns whether a contact is left out of the synchronization to Dataverse because its company has no customer or vendor.
    /// </summary>
    /// <param name="ContactRecordRef">The contact.</param>
    /// <returns>True to leave the contact out.</returns>
    internal procedure IsContactWithoutBusinessRelation(var ContactRecordRef: RecordRef): Boolean
    var
        ContactBusinessRelation: Record "Contact Business Relation";
        CRMSynchHelper: Codeunit "CRM Synch. Helper";
    begin
        if IsBusinessRelationOptional() then
            exit(false);
        if CRMSynchHelper.FindContactRelatedCustomer(ContactRecordRef, ContactBusinessRelation) then
            exit(false);
        exit(not CRMSynchHelper.FindContactRelatedVendor(ContactRecordRef, ContactBusinessRelation));
    end;

    /// <summary>
    /// Sets the parent account of a Dataverse contact from the customer or vendor of the contact's company.
    /// </summary>
    /// <param name="ContactRecordRef">The Business Central contact.</param>
    /// <param name="CRMContactRecordRef">The Dataverse contact.</param>
    internal procedure SetParentAccount(var ContactRecordRef: RecordRef; var CRMContactRecordRef: RecordRef)
    var
        CRMContact: Record "CRM Contact";
        AccountId: Guid;
    begin
        if FindParentAccount(ContactRecordRef, AccountId) then
            CRMContactRecordRef.Field(CRMContact.FieldNo(ParentCustomerId)).Value(AccountId);
    end;

    /// <summary>
    /// Sets the company of a Business Central contact from the parent account of the Dataverse contact.
    /// </summary>
    /// <param name="CRMContactRecordRef">The Dataverse contact.</param>
    /// <param name="ContactRecordRef">The Business Central contact.</param>
    internal procedure SetContactCompany(var CRMContactRecordRef: RecordRef; var ContactRecordRef: RecordRef)
    var
        CRMContact: Record "CRM Contact";
        CRMSynchHelper: Codeunit "CRM Synch. Helper";
    begin
        if CRMSynchHelper.SetContactParentCompany(CRMContactRecordRef.Field(CRMContact.FieldNo(ParentCustomerId)).Value(), ContactRecordRef) then
            exit;
        if not IsBusinessRelationOptional() then
            Error(ContactMissingCompanyErr);
    end;

    /// <summary>
    /// Blocks a customer when its Dataverse account is inactive.
    /// </summary>
    /// <param name="CRMAccountRecordRef">The Dataverse account.</param>
    /// <param name="CustomerRecordRef">The customer.</param>
    /// <returns>True when the customer was blocked.</returns>
    internal procedure BlockCustomerOfInactiveAccount(var CRMAccountRecordRef: RecordRef; var CustomerRecordRef: RecordRef): Boolean
    var
        Customer: Record Customer;
        CRMAccount: Record "CRM Account";
        StatusCode: Integer;
        Blocked: Integer;
    begin
        StatusCode := CRMAccountRecordRef.Field(CRMAccount.FieldNo(StatusCode)).Value();
        if StatusCode <> CRMAccount.StatusCode::Inactive then
            exit(false);
        Blocked := CustomerRecordRef.Field(Customer.FieldNo(Blocked)).Value();
        if Blocked <> Customer.Blocked::" ".AsInteger() then
            exit(false);
        CustomerRecordRef.Field(Customer.FieldNo(Blocked)).Value(Customer.Blocked::All);
        exit(true);
    end;

    /// <summary>
    /// Moves the contact mapping's watermark back to a new customer's creation time, so its contacts synchronize in the next run.
    /// </summary>
    /// <param name="CustomerRecordRef">The customer that was just created in Dataverse.</param>
    internal procedure RewindContactMapping(var CustomerRecordRef: RecordRef)
    var
        Customer: Record Customer;
        IntegrationTableMapping: Record "Integration Table Mapping";
    begin
        CustomerRecordRef.SetTable(Customer);
        if not FindMapping(Database::Contact, Database::"CRM Contact", IntegrationTableMapping) then
            exit;
        if IntegrationTableMapping."Synch. Int. Tbl. Mod. On Fltr." <= Customer.SystemCreatedAt then
            exit;
        IntegrationTableMapping."Synch. Int. Tbl. Mod. On Fltr." := Customer.SystemCreatedAt;
        IntegrationTableMapping.Modify(false);
    end;

    /// <summary>
    /// Sets the company and primary contact of the Business Central contacts coupled to the Dataverse contacts of an account created in Business Central.
    /// </summary>
    /// <param name="CRMAccountRecordRef">The Dataverse account.</param>
    internal procedure UpdateChildContacts(var CRMAccountRecordRef: RecordRef)
    var
        CRMAccount: Record "CRM Account";
        CRMContact: Record "CRM Contact";
        Contact: Record Contact;
        CRMIntegrationRecord: Record "CRM Integration Record";
        CDSCompany: Record "CDS Company";
        CDSIntegrationMgt: Codeunit "CDS Integration Mgt.";
        ContactRecordRef: RecordRef;
        CRMContactRecordRef: RecordRef;
    begin
        CRMAccountRecordRef.SetTable(CRMAccount);
        if not AccountMappingGetsFromDataverse(CRMAccount) then
            exit;
        Contact.SetRange("Company No.", '');
        if Contact.IsEmpty() then
            exit;
        if not CDSIntegrationMgt.GetCDSCompany(CDSCompany) then
            exit;
        CRMContact.SetRange(ParentCustomerIdType, CRMContact.ParentCustomerIdType::account);
        CRMContact.SetRange(ParentCustomerId, CRMAccount.AccountId);
        CRMContact.SetRange(CompanyId, CDSCompany.CompanyId);
        if CRMContact.FindSet() then
            repeat
                if CRMIntegrationRecord.FindByCRMID(CRMContact.ContactId) then begin
                    CRMContactRecordRef.GetTable(CRMContact);
                    ContactRecordRef.Open(Database::Contact);
                    if ContactRecordRef.GetBySystemId(CRMIntegrationRecord."Integration ID") then begin
                        FixPrimaryContactNo(CRMContactRecordRef, ContactRecordRef);
                        UpdateContactCompanyKeepingSynchState(CRMAccount.AccountId, ContactRecordRef);
                    end;
                    ContactRecordRef.Close();
                end;
            until CRMContact.Next() = 0;
    end;

    /// <summary>
    /// Sets a contact created from Dataverse as the primary contact of its parent customer or vendor when that has none.
    /// </summary>
    /// <param name="CRMContactRecordRef">The Dataverse contact.</param>
    /// <param name="ContactRecordRef">The Business Central contact.</param>
    internal procedure FixPrimaryContactNo(var CRMContactRecordRef: RecordRef; var ContactRecordRef: RecordRef)
    var
        CRMContact: Record "CRM Contact";
        Contact: Record Contact;
        CRMIntegrationRecord: Record "CRM Integration Record";
        PartyRecordId: RecordId;
    begin
        CRMContactRecordRef.SetTable(CRMContact);
        ContactRecordRef.SetTable(Contact);
        if CRMContact.ParentCustomerIdType <> CRMContact.ParentCustomerIdType::account then
            exit;
        if IsNullGuid(CRMContact.ParentCustomerId) then
            exit;
        if CRMIntegrationRecord.FindRecordIDFromID(CRMContact.ParentCustomerId, Database::Customer, PartyRecordId) then
            if SetPrimaryContactOfCustomer(PartyRecordId, Contact) then
                exit;
        if CRMIntegrationRecord.FindRecordIDFromID(CRMContact.ParentCustomerId, Database::Vendor, PartyRecordId) then
            SetPrimaryContactOfVendor(PartyRecordId, Contact);
    end;

    /// <summary>
    /// Sets a contact sent to Dataverse as the primary contact of its parent account when that has none.
    /// </summary>
    /// <param name="CRMContactRecordRef">The Dataverse contact that was just created.</param>
    internal procedure FixPrimaryContactInDataverse(var CRMContactRecordRef: RecordRef)
    var
        CRMContact: Record "CRM Contact";
        CRMAccount: Record "CRM Account";
        IntegrationTableMapping: Record "Integration Table Mapping";
        CouplingStore: Codeunit "DVI Coupling Store";
        AccountRecordRef: RecordRef;
        ModifiedAfterLastSynch: Boolean;
    begin
        CRMContactRecordRef.SetTable(CRMContact);
        if CRMContact.ParentCustomerIdType <> CRMContact.ParentCustomerIdType::account then
            exit;
        if IsNullGuid(CRMContact.ParentCustomerId) then
            exit;
        if not CRMAccount.Get(CRMContact.ParentCustomerId) then
            exit;
        if not IsNullGuid(CRMAccount.PrimaryContactId) then
            exit;
        if not FindAccountMapping(CRMAccount, IntegrationTableMapping) then
            exit;
        if not (IntegrationTableMapping.Direction in [IntegrationTableMapping.Direction::Bidirectional, IntegrationTableMapping.Direction::ToIntegrationTable]) then
            exit;
        AccountRecordRef.GetTable(CRMAccount);
        ModifiedAfterLastSynch := CouplingStore.WasModifiedAfterLastSynch(IntegrationTableMapping, AccountRecordRef);
        CRMAccount.PrimaryContactId := CRMContact.ContactId;
        CRMAccount.Modify();
        if not ModifiedAfterLastSynch then
            KeepAccountSynchronized(CRMAccount);
    end;

    /// <summary>
    /// Removes the couplings of the person contacts under a customer or vendor whose account is being uncoupled.
    /// </summary>
    /// <param name="LocalRecordRef">The customer or vendor.</param>
    /// <param name="IntegrationRecordRef">The Dataverse account.</param>
    internal procedure RemoveChildContactCouplings(var LocalRecordRef: RecordRef; var IntegrationRecordRef: RecordRef)
    var
        CRMIntegrationManagement: Codeunit "CRM Integration Management";
        ChildContactIds: List of [Guid];
    begin
        if CollectCoupledChildContacts(LocalRecordRef, IntegrationRecordRef, ChildContactIds) then
            CRMIntegrationManagement.RemoveCoupling(Database::Contact, ChildContactIds, false);
    end;

    local procedure FindParentAccount(var ContactRecordRef: RecordRef; var AccountId: Guid): Boolean
    var
        ContactBusinessRelation: Record "Contact Business Relation";
        Contact: Record Contact;
        Customer: Record Customer;
        Vendor: Record Vendor;
        CRMIntegrationRecord: Record "CRM Integration Record";
        CRMSynchHelper: Codeunit "CRM Synch. Helper";
        Silent: Boolean;
    begin
        Silent := IsBusinessRelationOptional();
        if CRMSynchHelper.FindContactRelatedCustomer(ContactRecordRef, ContactBusinessRelation) then begin
            if Customer.Get(ContactBusinessRelation."No.") then
                exit(CRMIntegrationRecord.FindIDFromRecordID(Customer.RecordId(), AccountId));
            if not Silent then
                Error(RecordNotFoundErr, Customer.TableCaption(), ContactBusinessRelation."No.");
            exit(false);
        end;
        if CRMSynchHelper.FindContactRelatedVendor(ContactRecordRef, ContactBusinessRelation) then begin
            if Vendor.Get(ContactBusinessRelation."No.") then
                exit(CRMIntegrationRecord.FindIDFromRecordID(Vendor.RecordId(), AccountId));
            if not Silent then
                Error(RecordNotFoundErr, Vendor.TableCaption(), ContactBusinessRelation."No.");
            exit(false);
        end;
        if not Silent then
            Error(ContactMustBeRelatedErr, ContactRecordRef.Field(Contact.FieldNo("No.")).Value());
        exit(false);
    end;

    local procedure SetPrimaryContactOfCustomer(CustomerRecordId: RecordId; Contact: Record Contact): Boolean
    var
        Customer: Record Customer;
        CRMAccount: Record "CRM Account";
        IntegrationTableMapping: Record "Integration Table Mapping";
        RecordRef: RecordRef;
        ModifiedAfterLastSynch: Boolean;
    begin
        if not Customer.Get(CustomerRecordId) then
            exit(false);
        if Customer."Primary Contact No." <> '' then
            exit(false);
        if not FindMapping(Database::Customer, Database::"CRM Account", IntegrationTableMapping) then
            exit(false);
        if not IntegrationTableMapping.IsFieldMappingEnabled(Customer.FieldNo("Primary Contact No."), CRMAccount.FieldNo(PrimaryContactId), IntegrationTableMapping.Direction::FromIntegrationTable) then
            exit(false);
        RecordRef.GetTable(Customer);
        ModifiedAfterLastSynch := WasModifiedAfterLastSynch(IntegrationTableMapping, RecordRef);
        Customer."Primary Contact No." := Contact."No.";
        if Contact.Type = Contact.Type::Person then
            Customer.Contact := Contact.Name;
        Customer.Modify(false);
        if not ModifiedAfterLastSynch then
            KeepLocalSynchronized(Customer.SystemId, Customer.SystemModifiedAt);
        exit(true);
    end;

    local procedure SetPrimaryContactOfVendor(VendorRecordId: RecordId; Contact: Record Contact)
    var
        Vendor: Record Vendor;
        CRMAccount: Record "CRM Account";
        IntegrationTableMapping: Record "Integration Table Mapping";
        RecordRef: RecordRef;
        ModifiedAfterLastSynch: Boolean;
    begin
        if not Vendor.Get(VendorRecordId) then
            exit;
        if Vendor."Primary Contact No." <> '' then
            exit;
        if not FindMapping(Database::Vendor, Database::"CRM Account", IntegrationTableMapping) then
            exit;
        if not IntegrationTableMapping.IsFieldMappingEnabled(Vendor.FieldNo("Primary Contact No."), CRMAccount.FieldNo(PrimaryContactId), IntegrationTableMapping.Direction::FromIntegrationTable) then
            exit;
        RecordRef.GetTable(Vendor);
        ModifiedAfterLastSynch := WasModifiedAfterLastSynch(IntegrationTableMapping, RecordRef);
        Vendor."Primary Contact No." := Contact."No.";
        if Contact.Type = Contact.Type::Person then
            Vendor.Contact := Contact.Name;
        Vendor.Modify(false);
        if not ModifiedAfterLastSynch then
            KeepLocalSynchronized(Vendor.SystemId, Vendor.SystemModifiedAt);
    end;

    local procedure UpdateContactCompanyKeepingSynchState(AccountId: Guid; var ContactRecordRef: RecordRef)
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        Contact: Record Contact;
        CRMSynchHelper: Codeunit "CRM Synch. Helper";
        ModifiedAfterLastSynch: Boolean;
        OldCompanyNo: Code[20];
        NewCompanyNo: Code[20];
    begin
        if not FindMapping(Database::Contact, Database::"CRM Contact", IntegrationTableMapping) then
            exit;
        if not (IntegrationTableMapping.Direction in [IntegrationTableMapping.Direction::Bidirectional, IntegrationTableMapping.Direction::FromIntegrationTable]) then
            exit;
        ModifiedAfterLastSynch := WasModifiedAfterLastSynch(IntegrationTableMapping, ContactRecordRef);
        OldCompanyNo := ContactRecordRef.Field(Contact.FieldNo("Company No.")).Value();
        if not CRMSynchHelper.SetContactParentCompany(AccountId, ContactRecordRef) then
            exit;
        NewCompanyNo := ContactRecordRef.Field(Contact.FieldNo("Company No.")).Value();
        if NewCompanyNo = OldCompanyNo then
            exit;
        ContactRecordRef.Modify();
        ContactRecordRef.SetTable(Contact);
        if not ModifiedAfterLastSynch then
            KeepLocalSynchronized(Contact.SystemId, Contact.SystemModifiedAt);
    end;

    local procedure CollectCoupledChildContacts(var LocalRecordRef: RecordRef; var IntegrationRecordRef: RecordRef; var ChildContactIds: List of [Guid]): Boolean
    var
        ContactBusinessRelation: Record "Contact Business Relation";
        Contact: Record Contact;
        CRMAccount: Record "CRM Account";
        CRMContact: Record "CRM Contact";
        CRMIntegrationRecord: Record "CRM Integration Record";
        PartyNo: Code[20];
        ContactId: Guid;
    begin
        if (IntegrationRecordRef.Number() <> Database::"CRM Account") or (LocalRecordRef.Number() = 0) then
            exit(false);
        IntegrationRecordRef.SetTable(CRMAccount);
        if IsNullGuid(CRMAccount.AccountId) then
            exit(false);
        PartyNo := CopyStr(Format(LocalRecordRef.Field(1).Value()), 1, MaxStrLen(PartyNo));
        case LocalRecordRef.Number() of
            Database::Customer:
                ContactBusinessRelation.SetRange("Link to Table", ContactBusinessRelation."Link to Table"::Customer);
            Database::Vendor:
                ContactBusinessRelation.SetRange("Link to Table", ContactBusinessRelation."Link to Table"::Vendor);
            else
                exit(false);
        end;
        ContactBusinessRelation.SetRange("No.", PartyNo);
        if not ContactBusinessRelation.FindFirst() then
            exit(false);
        Contact.SetRange("Company No.", ContactBusinessRelation."Contact No.");
        Contact.SetRange(Type, Contact.Type::Person);
        if Contact.FindSet() then
            repeat
                if CRMIntegrationRecord.FindIDFromRecordID(Contact.RecordId(), ContactId) then
                    if CRMContact.Get(ContactId) then
                        if CRMContact.ParentCustomerId = CRMAccount.AccountId then
                            ChildContactIds.Add(Contact.SystemId);
            until Contact.Next() = 0;
        exit(ChildContactIds.Count() > 0);
    end;

    local procedure AccountMappingGetsFromDataverse(CRMAccount: Record "CRM Account"): Boolean
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
    begin
        if not FindAccountMapping(CRMAccount, IntegrationTableMapping) then
            exit(false);
        exit(IntegrationTableMapping.Direction in [IntegrationTableMapping.Direction::Bidirectional, IntegrationTableMapping.Direction::FromIntegrationTable]);
    end;

    local procedure FindAccountMapping(CRMAccount: Record "CRM Account"; var IntegrationTableMapping: Record "Integration Table Mapping"): Boolean
    begin
        case CRMAccount.CustomerTypeCode of
            CRMAccount.CustomerTypeCode::Customer:
                exit(FindMapping(Database::Customer, Database::"CRM Account", IntegrationTableMapping));
            CRMAccount.CustomerTypeCode::Vendor:
                exit(FindMapping(Database::Vendor, Database::"CRM Account", IntegrationTableMapping));
        end;
        exit(false);
    end;

    local procedure WasModifiedAfterLastSynch(IntegrationTableMapping: Record "Integration Table Mapping"; var RecordRef: RecordRef): Boolean
    var
        CouplingStore: Codeunit "DVI Coupling Store";
    begin
        exit(CouplingStore.WasModifiedAfterLastSynch(IntegrationTableMapping, RecordRef));
    end;

    local procedure KeepLocalSynchronized(SystemId: Guid; ModifiedAt: DateTime)
    var
        CRMIntegrationRecord: Record "CRM Integration Record";
    begin
        CRMIntegrationRecord.SetRange("Integration ID", SystemId);
        if not CRMIntegrationRecord.FindFirst() then
            exit;
        CRMIntegrationRecord."Last Synch. Modified On" := ModifiedAt;
        CRMIntegrationRecord.Modify(false);
    end;

    local procedure KeepAccountSynchronized(CRMAccount: Record "CRM Account")
    var
        CRMIntegrationRecord: Record "CRM Integration Record";
    begin
        CRMIntegrationRecord.SetRange("CRM ID", CRMAccount.AccountId);
        if not CRMIntegrationRecord.FindFirst() then
            exit;
        CRMIntegrationRecord."Last Synch. CRM Modified On" := CRMAccount.ModifiedOn;
        CRMIntegrationRecord.Modify(false);
    end;
}
