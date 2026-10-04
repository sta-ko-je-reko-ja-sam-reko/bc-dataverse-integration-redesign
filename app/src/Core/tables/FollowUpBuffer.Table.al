namespace DataverseIntegration.Core;

using Microsoft.Integration.SyncEngine;

table 80001 "DVI Follow-up Buffer"
{
    Caption = 'Synchronization Follow-up Buffer';
    DataClassification = SystemMetadata;
    TableType = Temporary;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
        }
        field(2; "Mapping Name"; Code[20])
        {
            Caption = 'Mapping Name';
            TableRelation = "Integration Table Mapping".Name;
        }
        field(3; "Source System Id"; Guid)
        {
            Caption = 'Source System Id';
        }
        field(4; "To Integration Table"; Boolean)
        {
            Caption = 'To Integration Table';
        }
        field(5; "Keep On Failure"; Boolean)
        {
            Caption = 'Keep On Failure';
        }
        field(6; Completion; Boolean)
        {
            Caption = 'Completion';
        }
        field(7; "Synch Action"; Enum "DVI Synch Action")
        {
            Caption = 'Synch Action';
        }
        field(8; "Job Id"; Guid)
        {
            Caption = 'Job Id';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(Completion; Completion, "Entry No.")
        {
        }
    }
}
