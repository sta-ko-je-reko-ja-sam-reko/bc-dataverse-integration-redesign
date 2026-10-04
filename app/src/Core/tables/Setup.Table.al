namespace DataverseIntegration.Core;

table 80000 "DVI Setup"
{
    Caption = 'Dataverse Integration Redesign Setup';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
            DataClassification = SystemMetadata;
        }
        field(10; "DVI Enabled"; Boolean)
        {
            Caption = 'Enabled';
            ToolTip = 'Specifies whether the redesigned Dataverse integration is enabled. When it is off, every integration table mapping synchronizes exactly as Microsoft ships it. Changing it restarts the session.';
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }
}
