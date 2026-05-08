using GitOpen.Domain.Commits;

namespace GitOpen.Domain.Diff;

public abstract record DiffSpec
{
    public sealed record CommitVsParent(CommitSha CommitSha) : DiffSpec;
    public sealed record CommitVsCommit(CommitSha From, CommitSha To) : DiffSpec;
    public sealed record IndexVsHead : DiffSpec;
    public sealed record WorkingTreeVsIndex : DiffSpec;
}
