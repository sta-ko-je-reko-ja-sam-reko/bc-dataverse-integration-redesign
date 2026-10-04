namespace DataverseIntegration.Core;

enum 80002 "DVI Synch Action"
{
    Caption = 'Synchronization Action';
    Extensible = false;

    value(0; DVINone) { Caption = 'None'; }
    value(1; DVIInsert) { Caption = 'Insert'; }
    value(2; DVIModify) { Caption = 'Modify'; }
    value(3; DVIForceModify) { Caption = 'Force modify'; }
    value(4; DVIIgnoreUnchanged) { Caption = 'Unchanged'; }
    value(5; DVIFail) { Caption = 'Fail'; }
    value(6; DVISkip) { Caption = 'Skip'; }
    value(7; DVIDelete) { Caption = 'Delete'; }
    value(8; DVIUncouple) { Caption = 'Uncouple'; }
    value(9; DVICouple) { Caption = 'Couple'; }
}
