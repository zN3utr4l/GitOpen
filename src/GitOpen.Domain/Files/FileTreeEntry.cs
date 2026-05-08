using GitOpen.Domain.Commits;

namespace GitOpen.Domain.Files;

public enum FileTreeKind { Blob, Tree, Submodule, Symlink }

public sealed record FileTreeEntry(
    string Name,
    string FullPath,
    FileTreeKind Kind,
    long? SizeBytes,
    CommitSha? ContainingCommit);
