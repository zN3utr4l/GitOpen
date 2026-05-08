namespace GitOpen.Domain.Commits;

public sealed record CommitInfo(
    CommitSha Sha,
    IReadOnlyList<CommitSha> ParentShas,
    CommitSignature Author,
    CommitSignature Committer,
    string Summary,
    string Message);
