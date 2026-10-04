namespace DataverseIntegration.Core;

using System.Environment.Configuration;

tableextension 80000 "DVI Application Area Setup" extends "Application Area Setup"
{
    fields
    {
        field(80000; "DVI Redesign"; Boolean)
        {
            Caption = 'Dataverse Integration Redesign';
            DataClassification = SystemMetadata;
        }
    }
}
