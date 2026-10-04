namespace DataverseIntegration.Core;

using Microsoft.CRM.Team;
using Microsoft.Integration.Dataverse;

codeunit 80041 "DVI Owner Converter" implements "DVI IValueConverter"
{
    Access = Public;

    var
        OwnerIdFieldTok: Label 'OwnerId', Locked = true;

    procedure AppliesTo(var Context: Codeunit "DVI Sync Context"; var SourceFieldRef: FieldRef; var DestinationFieldRef: FieldRef): Boolean
    begin
        exit((SourceFieldRef.Name() = OwnerIdFieldTok) or (DestinationFieldRef.Name() = OwnerIdFieldTok));
    end;

    procedure Convert(var Context: Codeunit "DVI Sync Context"; var SourceFieldRef: FieldRef; var DestinationFieldRef: FieldRef; var NewValue: Variant; var NeedsConversion: Boolean): Boolean
    var
        CDSConnectionSetup: Record "CDS Connection Setup";
        CRMSynchHelper: Codeunit "CRM Synch. Helper";
        SalespersonCode: Code[20];
    begin
        NeedsConversion := false;
        CDSConnectionSetup.SetLoadFields("Ownership Model");
        if not CDSConnectionSetup.Get() then
            exit(false);
        case CDSConnectionSetup."Ownership Model" of
            CDSConnectionSetup."Ownership Model"::Team:
                NewValue := DestinationFieldRef.Value();
            CDSConnectionSetup."Ownership Model"::Person:
                if DestinationFieldRef.Name() = OwnerIdFieldTok then
                    NewValue := CRMSynchHelper.GetCoupledCDSUserId(SourceFieldRef.Record())
                else begin
                    SalespersonCode := CoupledSalespersonCode(SourceFieldRef.Value());
                    if SalespersonCode <> '' then
                        NewValue := SalespersonCode
                    else
                        NewValue := DestinationFieldRef.Value();
                end;
            else
                exit(false);
        end;
        exit(true);
    end;

    local procedure CoupledSalespersonCode(UserId: Guid): Code[20]
    var
        SalespersonPurchaser: Record "Salesperson/Purchaser";
        CRMIntegrationRecord: Record "CRM Integration Record";
        SalespersonRecordId: RecordId;
    begin
        if IsNullGuid(UserId) then
            exit('');
        if not CRMIntegrationRecord.FindRecordIDFromID(UserId, Database::"Salesperson/Purchaser", SalespersonRecordId) then
            exit('');
        SalespersonPurchaser.SetLoadFields(Code);
        if not SalespersonPurchaser.Get(SalespersonRecordId) then
            exit('');
        exit(SalespersonPurchaser.Code);
    end;
}
