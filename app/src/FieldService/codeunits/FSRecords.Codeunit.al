namespace DataverseIntegration.FieldService;

using DataverseIntegration.CDS;
using DataverseIntegration.Core;
using Microsoft.Integration.Dataverse;
using Microsoft.Integration.DynamicsFieldService;
using Microsoft.Integration.SyncEngine;

codeunit 80830 "DVI FS Records"
{
    Access = Internal;

    /// <summary>
    /// Writes the Business Central company to a Field Service record that was just created in Business Central from it.
    /// </summary>
    /// <param name="FSRecordRef">The Field Service record.</param>
    internal procedure StampCompanyOnSource(var FSRecordRef: RecordRef)
    var
        CDSIntegrationMgt: Codeunit "CDS Integration Mgt.";
        CDSCompany: Codeunit "DVI CDS Company";
    begin
        if CDSIntegrationMgt.CheckCompanyId(FSRecordRef) then
            exit;
        CDSCompany.SetCompanyId(FSRecordRef);
        FSRecordRef.Modify();
    end;

    /// <summary>
    /// Returns whether Field Service is integrated with projects.
    /// </summary>
    /// <returns>True when the integration type is Projects.</returns>
    internal procedure IsProjectIntegration(): Boolean
    var
        FSConnectionSetup: Record "FS Connection Setup";
    begin
        FSConnectionSetup.SetLoadFields("Is Enabled", "Integration Type");
        if not FSConnectionSetup.Get() then
            exit(false);
        exit(FSConnectionSetup."Is Enabled" and (FSConnectionSetup."Integration Type" = FSConnectionSetup."Integration Type"::Projects));
    end;

    /// <summary>
    /// Returns whether Field Service is integrated with service orders.
    /// </summary>
    /// <returns>True when the integration type includes service.</returns>
    internal procedure IsServiceIntegration(): Boolean
    var
        FSConnectionSetup: Record "FS Connection Setup";
    begin
        FSConnectionSetup.SetLoadFields("Is Enabled", "Integration Type");
        if not FSConnectionSetup.Get() then
            exit(false);
        exit(FSConnectionSetup."Is Enabled" and (FSConnectionSetup."Integration Type" <> FSConnectionSetup."Integration Type"::Projects));
    end;

    /// <summary>
    /// Finds the switched or standard mapping between two tables.
    /// </summary>
    /// <param name="TableId">The Business Central table.</param>
    /// <param name="IntegrationTableId">The Field Service table.</param>
    /// <param name="IntegrationTableMapping">Receives the mapping.</param>
    /// <returns>True when a mapping exists.</returns>
    internal procedure FindMapping(TableId: Integer; IntegrationTableId: Integer; var IntegrationTableMapping: Record "Integration Table Mapping"): Boolean
    var
        CDSRelations: Codeunit "DVI CDS Relations";
    begin
        exit(CDSRelations.FindMapping(TableId, IntegrationTableId, IntegrationTableMapping));
    end;
}
