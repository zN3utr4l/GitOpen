namespace GitOpen.Domain.Commits;

public readonly record struct CommitSha
{
    public string Value { get; }

    public CommitSha(string value)
    {
        if (string.IsNullOrWhiteSpace(value))
            throw new ArgumentException("CommitSha cannot be empty", nameof(value));
        if (value.Length is < 4 or > 40)
            throw new ArgumentException("CommitSha must be 4..40 hex chars", nameof(value));
        Value = value.ToLowerInvariant();
    }

#pragma warning disable CA1720 // identifier contains type name
    public string Short(int length = 7) =>
        Value.Length <= length ? Value : Value[..length];
#pragma warning restore CA1720

    public override string ToString() => Value;
}
