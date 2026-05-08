namespace GitOpen.Domain.Diff;

public enum DiffLineKind { Context, Addition, Deletion }

public sealed record DiffLine(DiffLineKind Kind, int? OldLine, int? NewLine, string Content);
