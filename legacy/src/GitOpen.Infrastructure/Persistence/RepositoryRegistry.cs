using GitOpen.Application.Workspaces;
using GitOpen.Domain.Repositories;
using GitOpen.Infrastructure.Persistence.Entities;
using Microsoft.EntityFrameworkCore;

namespace GitOpen.Infrastructure.Persistence;

public sealed class RepositoryRegistry : IRepositoryRegistry
{
    private readonly GitOpenDbContext _db;
    public RepositoryRegistry(GitOpenDbContext db) => _db = db;

    public async Task<RepoLocation> AddAsync(string path, CancellationToken ct)
    {
        var existing = await _db.Repositories.FirstOrDefaultAsync(r => r.Path == path, ct);
        if (existing is not null) return ToLocation(existing);

        var row = new RepositoryRow
        {
            Id = Guid.NewGuid(),
            Path = path,
            DisplayName = DefaultDisplayName(path),
            CreatedUtc = DateTime.UtcNow,
            LastOpenedUtc = DateTime.UtcNow,
            TabOrder = await _db.Repositories.CountAsync(ct)
        };
        _db.Repositories.Add(row);
        await _db.SaveChangesAsync(ct);
        return ToLocation(row);
    }

    public async Task<IReadOnlyList<RepoLocation>> ListAsync(CancellationToken ct) =>
        await _db.Repositories
            .OrderBy(r => r.TabOrder)
            .Select(r => new RepoLocation(new RepoId(r.Id), r.Path, r.DisplayName))
            .ToListAsync(ct);

    public async Task<RepoLocation?> GetByPathAsync(string path, CancellationToken ct)
    {
        var row = await _db.Repositories.FirstOrDefaultAsync(r => r.Path == path, ct);
        return row is null ? null : ToLocation(row);
    }

    public async Task RemoveAsync(RepoId id, CancellationToken ct)
    {
        var row = await _db.Repositories.FirstOrDefaultAsync(r => r.Id == id.Value, ct);
        if (row is null) return;
        _db.Repositories.Remove(row);
        await _db.SaveChangesAsync(ct);
    }

    public async Task TouchLastOpenedAsync(RepoId id, CancellationToken ct)
    {
        var row = await _db.Repositories.FirstOrDefaultAsync(r => r.Id == id.Value, ct);
        if (row is null) return;
        row.LastOpenedUtc = DateTime.UtcNow;
        await _db.SaveChangesAsync(ct);
    }

    private static RepoLocation ToLocation(RepositoryRow r) =>
        new(new RepoId(r.Id), r.Path, r.DisplayName);

    private static string DefaultDisplayName(string path)
    {
        var trimmed = path.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        var name = Path.GetFileName(trimmed);
        return string.IsNullOrEmpty(name) ? trimmed : name;
    }
}
