using GitOpen.Domain.Commits;

namespace GitOpen.Domain.Refs;

public sealed record Branch(
    string Name,
    string FullName,
    bool IsRemote,
    bool IsCurrent,
    CommitSha? TipSha,
    string? UpstreamFullName,
    int Ahead,
    int Behind);
