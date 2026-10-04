namespace DataverseIntegration.Core;

interface "DVI IValueConverter"
{
    /// <summary>
    /// Returns whether this converter is the default for a field mapping, used when a mapping is switched to the redesigned synchronization. The first converter value that applies wins; Direct is the fallback.
    /// </summary>
    /// <param name="Context">The context; its mapping and direction describe the field mapping.</param>
    /// <param name="SourceFieldRef">The source field of the field mapping.</param>
    /// <param name="DestinationFieldRef">The destination field of the field mapping.</param>
    /// <returns>True when this converter handles values of this field pair.</returns>
    procedure AppliesTo(var Context: Codeunit "DVI Sync Context"; var SourceFieldRef: FieldRef; var DestinationFieldRef: FieldRef): Boolean;

    /// <summary>
    /// Computes the value written to the destination field.
    /// </summary>
    /// <param name="Context">The synchronization context.</param>
    /// <param name="SourceFieldRef">The source field, with the value being synchronized.</param>
    /// <param name="DestinationFieldRef">The destination field, with its current value.</param>
    /// <param name="NewValue">Receives the value to write.</param>
    /// <param name="NeedsConversion">Set to true when NewValue still has to be evaluated into the destination field's type.</param>
    /// <returns>True when this converter produced the value; false transfers the source value as it is.</returns>
    procedure Convert(var Context: Codeunit "DVI Sync Context"; var SourceFieldRef: FieldRef; var DestinationFieldRef: FieldRef; var NewValue: Variant; var NeedsConversion: Boolean): Boolean;
}
