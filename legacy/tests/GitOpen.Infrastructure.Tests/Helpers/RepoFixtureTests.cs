using FluentAssertions;
using LibGit2Sharp;
using Xunit;

namespace GitOpen.Infrastructure.Tests.Helpers;

public class RepoFixtureTests
{
    [Fact]
    public void WithLinearHistory_creates_repo_with_n_commits()
    {
        using var f = RepoFixture.WithLinearHistory(5);
        using var repo = new Repository(f.Path);
        repo.Commits.Count().Should().Be(5);
        repo.Head.Tip.Sha.Should().Be(f.HeadSha);
    }

    [Fact]
    public void Empty_creates_initialised_repo_with_no_commits()
    {
        using var f = RepoFixture.Empty();
        using var repo = new Repository(f.Path);
        repo.Commits.Should().BeEmpty();
    }

    [Fact]
    public void WithBranches_creates_master_and_feature()
    {
        using var f = RepoFixture.WithBranches();
        using var repo = new Repository(f.Path);
        repo.Branches.Should().Contain(b => b.FriendlyName == "feature");
    }
}
