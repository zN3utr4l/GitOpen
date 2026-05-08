namespace GitOpen.Ui.Services;

public interface IFolderPicker
{
    Task<string?> PickFolderAsync(string title);
}
