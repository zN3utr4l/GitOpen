using GitOpen.Domain.Repositories;

namespace GitOpen.Application.Workspaces;

public interface IRepositoryRegistry
{
    Task<RepoLocation> AddAsync(string path, CancellationToken ct);
    Task<IReadOnlyList<RepoLocation>> ListAsync(CancellationToken ct);
    Task<RepoLocation?> GetByPathAsync(string path, CancellationToken ct);
    Task RemoveAsync(RepoId id, CancellationToken ct);
    Task TouchLastOpenedAsync(RepoId id, CancellationToken ct);
}
