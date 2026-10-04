namespace DataverseIntegration.Core;

enum 80000 "DVI Sync Handler" implements "DVI IRecordSync", "DVI IRecordCoupling", "DVI IRecordFilter", "DVI IConflictPolicy", "DVI IOptionSource", "DVI IHandlerScope",
    "DVI IIntegrationRecordView", "DVI ISynchronizeAction", "DVI ICouplingAction", "DVI ICreateAction", "DVI ISynchLogView"
{
    Caption = 'Synchronization Handler';
    Extensible = true;
    DefaultImplementation = "DVI IRecordSync" = "DVI Generic Handler", "DVI IRecordCoupling" = "DVI Generic Handler", "DVI IRecordFilter" = "DVI Generic Handler", "DVI IConflictPolicy" = "DVI Mapping Conflict Policy", "DVI IOptionSource" = "DVI Standard Option Source", "DVI IHandlerScope" = "DVI Generic Handler",
        "DVI IIntegrationRecordView" = "DVI Standard Record Actions", "DVI ISynchronizeAction" = "DVI Standard Record Actions", "DVI ICouplingAction" = "DVI Standard Record Actions", "DVI ICreateAction" = "DVI Standard Record Actions", "DVI ISynchLogView" = "DVI Standard Record Actions";

    value(0; DVIMicrosoft)
    {
        Caption = 'Microsoft (not redesigned)';
    }
    value(1; DVIGeneric)
    {
        Caption = 'Generic';
    }
}
