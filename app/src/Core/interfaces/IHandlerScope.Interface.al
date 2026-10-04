namespace DataverseIntegration.Core;

interface "DVI IHandlerScope"
{
    /// <summary>
    /// Returns whether this handler is the default for a mapping, used when mappings are switched to the redesigned synchronization. The first handler value that serves a mapping wins; the Generic handler is the fallback.
    /// </summary>
    /// <param name="Context">The context; its mapping identifies the table pair.</param>
    /// <returns>True when this handler implements the behaviour of the mapping's table pair.</returns>
    procedure Serves(var Context: Codeunit "DVI Sync Context"): Boolean;

    /// <summary>
    /// Returns the integration module a mapping belongs to when this handler is assigned to it.
    /// </summary>
    /// <param name="Context">The context; its mapping identifies the table pair.</param>
    /// <returns>The module whose connection guards the mapping.</returns>
    procedure DefaultModule(var Context: Codeunit "DVI Sync Context"): Enum "DVI Integration Module";
}
