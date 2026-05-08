using GitOpen.Domain.Commits;

namespace GitOpen.Application.CommitGraph;

public interface ICommitGraphLayout
{
    IReadOnlyList<CommitNode> Compute(IReadOnlyList<CommitInfo> commitsNewestFirst);
}
