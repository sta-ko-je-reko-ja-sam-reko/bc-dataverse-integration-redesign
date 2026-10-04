namespace DataverseIntegration.Core;

using Microsoft.Integration.SyncEngine;

codeunit 80011 "DVI Mapping Conflict Policy" implements "DVI IConflictPolicy"
{
    Access = Public;

    procedure ResolveUpdateConflict(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef; var DestinationRecordRef: RecordRef; var SkipRecord: Boolean): Boolean
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
    begin
        Context.GetMapping(IntegrationTableMapping);
        case IntegrationTableMapping."Update-Conflict Resolution" of
            IntegrationTableMapping."Update-Conflict Resolution"::"Get Update from Integration":
                begin
                    SkipRecord := SourceRecordRef.Number() <> IntegrationTableMapping."Integration Table ID";
                    exit(true);
                end;
            IntegrationTableMapping."Update-Conflict Resolution"::"Send Update to Integration":
                begin
                    SkipRecord := SourceRecordRef.Number() <> IntegrationTableMapping."Table ID";
                    exit(true);
                end;
        end;
        exit(false);
    end;

    procedure ResolveDeletionConflict(var Context: Codeunit "DVI Sync Context"; var SourceRecordRef: RecordRef): Enum "DVI Deletion Outcome"
    var
        IntegrationTableMapping: Record "Integration Table Mapping";
    begin
        Context.GetMapping(IntegrationTableMapping);
        case IntegrationTableMapping."Deletion-Conflict Resolution" of
            IntegrationTableMapping."Deletion-Conflict Resolution"::"Restore Records":
                exit(Enum::"DVI Deletion Outcome"::DVIRestoreRecord);
            IntegrationTableMapping."Deletion-Conflict Resolution"::"Remove Coupling":
                exit(Enum::"DVI Deletion Outcome"::DVIRemoveCoupling);
        end;
        exit(Enum::"DVI Deletion Outcome"::DVIFail);
    end;
}
