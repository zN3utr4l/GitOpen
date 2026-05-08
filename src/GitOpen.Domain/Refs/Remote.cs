namespace GitOpen.Domain.Refs;

public sealed record Remote(string Name, string Url, IReadOnlyList<Branch> Branches);
