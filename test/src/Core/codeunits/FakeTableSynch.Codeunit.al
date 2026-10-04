namespace DataverseIntegration.Test;

using DataverseIntegration.Core;
using Microsoft.Integration.SyncEngine;

codeunit 84001 "DVI Fake Table Synch." implements "DVI ITableSynch"
{
    SingleInstance = true;

    var
        LastMappingName: Code[20];
        CallCount: Integer;

    procedure SynchronizeMapping(var IntegrationTableMapping: Record "Integration Table Mapping")
    begin
        CallCount += 1;
        LastMappingName := IntegrationTableMapping.Name;
    end;

    /// <summary>
    /// Clears the recorded calls.
    /// </summary>
    internal procedure Reset()
    begin
        CallCount := 0;
        LastMappingName := '';
    end;

    /// <summary>
    /// Returns how often SynchronizeMapping was called since the last Reset.
    /// </summary>
    /// <returns>The number of calls.</returns>
    internal procedure GetCallCount(): Integer
    begin
        exit(CallCount);
    end;

    /// <summary>
    /// Returns the mapping of the last call.
    /// </summary>
    /// <returns>The mapping name.</returns>
    internal procedure GetLastMappingName(): Code[20]
    begin
        exit(LastMappingName);
    end;
}
