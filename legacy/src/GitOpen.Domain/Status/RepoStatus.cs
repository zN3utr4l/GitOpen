using GitOpen.Domain.Commits;

namespace GitOpen.Domain.Status;

public sealed record RepoStatus(
    string? CurrentBranch,
    CommitSha? HeadSha,
    bool IsDetached,
    bool IsBare,
    IReadOnlyList<WorkingFileEntry> Entries);
