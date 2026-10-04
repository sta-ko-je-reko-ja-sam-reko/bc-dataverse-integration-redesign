namespace DataverseIntegration.Core;

enum 80000 "DVI Sync Handler" implements "DVI IRecordSync", "DVI IRecordCoupling", "DVI IRecordFilter", "DVI IConflictPolicy", "DVI IOptionSource", "DVI IHandlerScope"
{
    Caption = 'Synchronization Handler';
    Extensible = true;
    DefaultImplementation = "DVI IRecordSync" = "DVI Generic Handler", "DVI IRecordCoupling" = "DVI Generic Handler", "DVI IRecordFilter" = "DVI Generic Handler", "DVI IConflictPolicy" = "DVI Mapping Conflict Policy", "DVI IOptionSource" = "DVI Standard Option Source", "DVI IHandlerScope" = "DVI Generic Handler";

    value(0; DVIMicrosoft)
    {
        Caption = 'Microsoft (not redesigned)';
    }
    value(1; DVIGeneric)
    {
        Caption = 'Generic';
    }
}
