using GitOpen.Domain.Commits;
using GitOpen.Domain.Diff;
using GitOpen.Domain.Files;
using GitOpen.Domain.Refs;
using GitOpen.Domain.Repositories;
using GitOpen.Domain.Status;

namespace GitOpen.Application.Git;

public sealed record CommitQuery(int? Skip = null, int? Take = null, string? RefSpec = null);

public interface IGitReadOperations
{
    Task<RepoStatus> GetStatusAsync(RepoLocation repo, CancellationToken ct);
    IAsyncEnumerable<CommitInfo> GetCommitsAsync(RepoLocation repo, CommitQuery query, CancellationToken ct);
    Task<IReadOnlyList<Branch>> GetBranchesAsync(RepoLocation repo, CancellationToken ct);
    Task<IReadOnlyList<Tag>> GetTagsAsync(RepoLocation repo, CancellationToken ct);
    Task<IReadOnlyList<Remote>> GetRemotesAsync(RepoLocation repo, CancellationToken ct);
    Task<IReadOnlyList<Stash>> GetStashesAsync(RepoLocation repo, CancellationToken ct);
    Task<DiffResult> GetDiffAsync(RepoLocation repo, DiffSpec spec, CancellationToken ct);
    Task<IReadOnlyList<FileTreeEntry>> GetFileTreeAsync(RepoLocation repo, CommitSha sha, string path, CancellationToken ct);
}
