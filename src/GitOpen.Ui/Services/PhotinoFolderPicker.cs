using Photino.Blazor;

namespace GitOpen.Ui.Services;

public sealed class PhotinoFolderPicker : IFolderPicker
{
    private readonly PhotinoBlazorApp _app;
    public PhotinoFolderPicker(PhotinoBlazorApp app) => _app = app;

    public Task<string?> PickFolderAsync(string title)
    {
        var paths = _app.MainWindow.ShowOpenFolder(title: title, multiSelect: false);
        return Task.FromResult(paths is { Length: > 0 } ? paths[0] : null);
    }
}
