namespace GitOpen.Domain.Commits;

public sealed record CommitSignature(string Name, string Email, DateTimeOffset When);
