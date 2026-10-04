namespace DataverseIntegration.Core;

interface "DVI IConnection"
{
    /// <summary>
    /// Returns whether the module's connection is set up and enabled.
    /// </summary>
    /// <returns>True when records of the module may be synchronized.</returns>
    procedure IsEnabled(): Boolean;

    /// <summary>
    /// Opens and tests the connection used by the synchronization.
    /// </summary>
    /// <returns>The name of the registered connection, passed back to Close.</returns>
    procedure Open(): Text;

    /// <summary>
    /// Closes the connection opened by Open.
    /// </summary>
    /// <param name="ConnectionName">The name returned by Open.</param>
    procedure Close(ConnectionName: Text);
}
