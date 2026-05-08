namespace GitOpen.Domain.Repositories;

public readonly record struct RepoId(Guid Value)
{
    public static RepoId NewId() => new(Guid.NewGuid());
    public override string ToString() => Value.ToString("N");
}
