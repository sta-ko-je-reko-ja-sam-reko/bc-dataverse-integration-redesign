namespace DataverseIntegration.Core;

interface "DVI IMappingLogic"
{
    /// <summary>
    /// Validates a change of the synchronization handler assigned to an integration table mapping.
    /// </summary>
    /// <param name="MappingAssignment">The assignment with the new handler.</param>
    /// <param name="xMappingAssignment">The assignment before the change.</param>
    procedure Validate_Handler(var MappingAssignment: Record "DVI Mapping Assignment"; xMappingAssignment: Record "DVI Mapping Assignment");
}
