namespace DataverseIntegration.Core;

table 80002 "DVI Option Value"
{
    Caption = 'Dataverse Option Value';
    DataClassification = SystemMetadata;
    TableType = Temporary;

    fields
    {
        field(1; "Option Id"; Integer)
        {
            Caption = 'Option Id';
        }
        field(2; "Code"; Text[250])
        {
            Caption = 'Code';
        }
    }

    keys
    {
        key(PK; "Option Id")
        {
            Clustered = true;
        }
    }
}
