namespace DataverseIntegration.Core;

interface "DVI IOptionSource"
{
    /// <summary>
    /// Returns the Dataverse entity and option set field that hold the values of an option mapping, such as the account's payment terms.
    /// </summary>
    /// <param name="Context">The synchronization context; its mapping identifies the option field.</param>
    /// <param name="EntityName">Receives the logical name of the entity.</param>
    /// <param name="FieldName">Receives the logical name of the option set field.</param>
    procedure GetOptionSetField(var Context: Codeunit "DVI Sync Context"; var EntityName: Text; var FieldName: Text);

    /// <summary>
    /// Loads the option values from Dataverse.
    /// </summary>
    /// <param name="Context">The synchronization context.</param>
    /// <param name="TempOptionValue">Receives one record per option value and label.</param>
    procedure LoadOptions(var Context: Codeunit "DVI Sync Context"; var TempOptionValue: Record "DVI Option Value" temporary);
}
