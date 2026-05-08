using System.Runtime.CompilerServices;
using GitOpen.Application.Git;
using GitOpen.Domain.Commits;
using GitOpen.Domain.Diff;
using GitOpen.Domain.Files;
using GitOpen.Domain.Refs;
using GitOpen.Domain.Repositories;
using GitOpen.Domain.Status;

namespace GitOpen.Infrastructure.Git;

public sealed class LibGit2GitReadOperations : IGitReadOperations
{
    public Task<RepoStatus> GetStatusAsync(RepoLocation repo, CancellationToken ct)
        => throw new NotImplementedException();

    public IAsyncEnumerable<CommitInfo> GetCommitsAsync(RepoLocation repo, CommitQuery query, CancellationToken ct)
        => throw new NotImplementedException();

    public Task<IReadOnlyList<Branch>> GetBranchesAsync(RepoLocation repo, CancellationToken ct)
        => throw new NotImplementedException();

    public Task<IReadOnlyList<Tag>> GetTagsAsync(RepoLocation repo, CancellationToken ct)
        => throw new NotImplementedException();

    public Task<IReadOnlyList<Remote>> GetRemotesAsync(RepoLocation repo, CancellationToken ct)
        => throw new NotImplementedException();

    public Task<IReadOnlyList<Stash>> GetStashesAsync(RepoLocation repo, CancellationToken ct)
        => throw new NotImplementedException();

    public Task<DiffResult> GetDiffAsync(RepoLocation repo, DiffSpec spec, CancellationToken ct)
        => throw new NotImplementedException();

    public Task<IReadOnlyList<FileTreeEntry>> GetFileTreeAsync(RepoLocation repo, CommitSha sha, string path, CancellationToken ct)
        => throw new NotImplementedException();
}
