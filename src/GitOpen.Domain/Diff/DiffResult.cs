namespace GitOpen.Domain.Diff;

public sealed record DiffResult(IReadOnlyList<FileDiff> Files);
