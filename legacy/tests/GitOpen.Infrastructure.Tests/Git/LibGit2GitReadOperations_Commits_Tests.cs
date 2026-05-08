using FluentAssertions;
using GitOpen.Application.Git;
using GitOpen.Domain.Repositories;
using GitOpen.Infrastructure.Git;
using GitOpen.Infrastructure.Tests.Helpers;
using Xunit;

namespace GitOpen.Infrastructure.Tests.Git;

public class LibGit2GitReadOperations_Commits_Tests
{
    private static RepoLocation Loc(RepoFixture f) =>
        new(RepoId.NewId(), f.Path, "test");

    [Fact]
    public async Task GetCommitsAsync_returns_all_in_topological_order()
    {
        using var f = RepoFixture.WithLinearHistory(5);
        var sut = new LibGit2GitReadOperations();

        var commits = new List<GitOpen.Domain.Commits.CommitInfo>();
        await foreach (var c in sut.GetCommitsAsync(Loc(f), new CommitQuery(), default))
            commits.Add(c);

        commits.Should().HaveCount(5);
        commits[0].Sha.Value.Should().Be(f.HeadSha);
    }

    [Fact]
    public async Task GetCommitsAsync_respects_take_and_skip()
    {
        using var f = RepoFixture.WithLinearHistory(10);
        var sut = new LibGit2GitReadOperations();

        var commits = new List<GitOpen.Domain.Commits.CommitInfo>();
        await foreach (var c in sut.GetCommitsAsync(Loc(f), new CommitQuery(Skip: 2, Take: 3), default))
            commits.Add(c);

        commits.Should().HaveCount(3);
    }

    [Fact]
    public async Task GetCommitsAsync_returns_empty_for_empty_repo()
    {
        using var f = RepoFixture.Empty();
        var sut = new LibGit2GitReadOperations();

        var commits = new List<GitOpen.Domain.Commits.CommitInfo>();
        await foreach (var c in sut.GetCommitsAsync(Loc(f), new CommitQuery(), default))
            commits.Add(c);

        commits.Should().BeEmpty();
    }

    [Fact]
    public async Task GetCommitsAsync_respects_cancellation()
    {
        using var f = RepoFixture.WithLinearHistory(50);
        var sut = new LibGit2GitReadOperations();
        using var cts = new CancellationTokenSource();
        cts.Cancel();

        var act = async () =>
        {
            await foreach (var _ in sut.GetCommitsAsync(Loc(f), new CommitQuery(), cts.Token)) { }
        };

        await act.Should().ThrowAsync<OperationCanceledException>();
    }
}
