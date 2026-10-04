namespace DataverseIntegration.Core;

enum 80003 "DVI Deletion Outcome"
{
    Caption = 'Deletion Conflict Outcome';
    Extensible = false;

    value(0; DVIFail) { Caption = 'Fail'; }
    value(1; DVIRestoreRecord) { Caption = 'Restore the deleted record'; }
    value(2; DVIRemoveCoupling) { Caption = 'Remove the coupling'; }
    value(3; DVISkip) { Caption = 'Skip the record'; }
}
