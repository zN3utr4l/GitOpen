using GitOpen.Domain.Commits;

namespace GitOpen.Domain.Refs;

public sealed record Stash(int Index, CommitSha Sha, string Message, DateTimeOffset CreatedAt);
