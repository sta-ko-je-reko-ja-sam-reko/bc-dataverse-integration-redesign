namespace DataverseIntegration.Core;

using Microsoft.Integration.SyncEngine;

codeunit 80030 "DVI Record Action Context"
{
    Access = Public;

    var
        IntegrationTableMapping: Record "Integration Table Mapping";
        CurrentRecordId: RecordId;
        IntegrationId: Guid;
        MappingFound: Boolean;
        Coupled: Boolean;

    /// <summary>
    /// Sets the record the page shows.
    /// </summary>
    /// <param name="NewRecordId">The current record.</param>
    procedure SetRecord(NewRecordId: RecordId)
    begin
        CurrentRecordId := NewRecordId;
        MappingFound := false;
        Coupled := false;
        Clear(IntegrationId);
        Clear(IntegrationTableMapping);
    end;

    /// <summary>
    /// Returns the record the page shows.
    /// </summary>
    /// <returns>The current record.</returns>
    procedure GetRecordId(): RecordId
    begin
        exit(CurrentRecordId);
    end;

    /// <summary>
    /// Sets the integration table mapping the record is synchronized through.
    /// </summary>
    /// <param name="NewIntegrationTableMapping">The mapping.</param>
    procedure SetMapping(NewIntegrationTableMapping: Record "Integration Table Mapping")
    begin
        IntegrationTableMapping := NewIntegrationTableMapping;
        MappingFound := true;
    end;

    /// <summary>
    /// Returns the integration table mapping of the record.
    /// </summary>
    /// <param name="CurrentIntegrationTableMapping">Receives the mapping.</param>
    procedure GetMapping(var CurrentIntegrationTableMapping: Record "Integration Table Mapping")
    begin
        CurrentIntegrationTableMapping := IntegrationTableMapping;
    end;

    /// <summary>
    /// Returns whether the record's table has an integration table mapping.
    /// </summary>
    /// <returns>True when a mapping was found.</returns>
    procedure HasMapping(): Boolean
    begin
        exit(MappingFound);
    end;

    /// <summary>
    /// Sets the Dataverse record the current record is coupled to.
    /// </summary>
    /// <param name="NewIntegrationId">The ID of the coupled Dataverse record.</param>
    procedure SetCoupling(NewIntegrationId: Guid)
    begin
        IntegrationId := NewIntegrationId;
        Coupled := not IsNullGuid(NewIntegrationId);
    end;

    /// <summary>
    /// Returns whether the current record is coupled.
    /// </summary>
    /// <returns>True when the record is coupled to a Dataverse record.</returns>
    procedure IsCoupled(): Boolean
    begin
        exit(Coupled);
    end;

    /// <summary>
    /// Returns the ID of the coupled Dataverse record.
    /// </summary>
    /// <returns>The ID; a null GUID when the record is not coupled.</returns>
    procedure GetIntegrationId(): Guid
    begin
        exit(IntegrationId);
    end;

    /// <summary>
    /// Returns whether the mapping synchronizes from Business Central to Dataverse.
    /// </summary>
    /// <returns>True for a To Integration Table or bidirectional mapping.</returns>
    procedure AllowsToIntegrationTable(): Boolean
    begin
        if not MappingFound then
            exit(false);
        exit(IntegrationTableMapping.Direction in [IntegrationTableMapping.Direction::ToIntegrationTable, IntegrationTableMapping.Direction::Bidirectional]);
    end;

    /// <summary>
    /// Returns whether the mapping synchronizes from Dataverse to Business Central.
    /// </summary>
    /// <returns>True for a From Integration Table or bidirectional mapping.</returns>
    procedure AllowsFromIntegrationTable(): Boolean
    begin
        if not MappingFound then
            exit(false);
        exit(IntegrationTableMapping.Direction in [IntegrationTableMapping.Direction::FromIntegrationTable, IntegrationTableMapping.Direction::Bidirectional]);
    end;
}
