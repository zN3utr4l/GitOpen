namespace GitOpen.Domain.Status;

public enum WorkingFileState { Unmodified, Added, Modified, Deleted, Renamed, Conflicted, Untracked, Ignored }

public sealed record WorkingFileEntry(
    string Path,
    WorkingFileState IndexState,
    WorkingFileState WorkingTreeState,
    string? OldPath = null);
