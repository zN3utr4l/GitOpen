using GitOpen.Domain.Commits;

namespace GitOpen.Domain.Refs;

public sealed record Tag(string Name, string FullName, CommitSha TargetSha, bool IsAnnotated);
