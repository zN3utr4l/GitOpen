namespace GitOpen.Domain.Diff;

public enum FileChangeKind { Added, Deleted, Modified, Renamed, Copied, TypeChanged, Unmerged }

public sealed record FileDiff(
    string Path,
    string? OldPath,
    FileChangeKind ChangeKind,
    bool IsBinary,
    int LinesAdded,
    int LinesDeleted,
    IReadOnlyList<DiffHunk> Hunks);
