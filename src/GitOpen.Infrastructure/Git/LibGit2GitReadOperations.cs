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

    public async IAsyncEnumerable<CommitInfo> GetCommitsAsync(
        RepoLocation repo,
        CommitQuery query,
        [EnumeratorCancellation] CancellationToken ct)
    {
        using var lg = new LibGit2Sharp.Repository(repo.Path);
        var filter = new LibGit2Sharp.CommitFilter
        {
            SortBy = LibGit2Sharp.CommitSortStrategies.Topological | LibGit2Sharp.CommitSortStrategies.Time
        };
        if (query.RefSpec is not null) filter.IncludeReachableFrom = query.RefSpec;

        IEnumerable<LibGit2Sharp.Commit> commits = lg.Commits.QueryBy(filter);
        if (query.Skip is { } s) commits = commits.Skip(s);
        if (query.Take is { } t) commits = commits.Take(t);

        foreach (var c in commits)
        {
            ct.ThrowIfCancellationRequested();
            yield return new CommitInfo(
                new CommitSha(c.Sha),
                c.Parents.Select(p => new CommitSha(p.Sha)).ToList(),
                new CommitSignature(c.Author.Name, c.Author.Email, c.Author.When),
                new CommitSignature(c.Committer.Name, c.Committer.Email, c.Committer.When),
                c.MessageShort,
                c.Message);
            await Task.Yield();
        }
    }

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
