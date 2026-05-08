using GitOpen.Domain.Commits;

namespace GitOpen.Application.CommitGraph;

public sealed record CommitNode(
    CommitInfo Commit,
    int Lane,
    int Color,
    IReadOnlyList<int> ParentLanes);
