using FluentAssertions;
using GitOpen.Domain.Commits;
using GitOpen.Domain.Diff;
using GitOpen.Domain.Repositories;
using GitOpen.Infrastructure.Git;
using GitOpen.Infrastructure.Tests.Helpers;
using Xunit;

namespace GitOpen.Infrastructure.Tests.Git;

public class LibGit2GitReadOperations_Diff_Tests
{
    private static RepoLocation Loc(RepoFixture f) => new(RepoId.NewId(), f.Path, "test");

    [Fact]
    public async Task GetDiffAsync_commit_vs_parent_lists_added_files()
    {
        using var f = RepoFixture.WithLinearHistory(2);
        var sut = new LibGit2GitReadOperations();

        var diff = await sut.GetDiffAsync(Loc(f),
            new DiffSpec.CommitVsParent(new CommitSha(f.HeadSha)), default);

        diff.Files.Should().ContainSingle(fd => fd.Path == "file_1.txt"
            && fd.ChangeKind == FileChangeKind.Added);
    }

    [Fact]
    public async Task GetDiffAsync_initial_commit_vs_no_parent_lists_all_added()
    {
        using var f = RepoFixture.WithLinearHistory(1);
        var sut = new LibGit2GitReadOperations();

        var diff = await sut.GetDiffAsync(Loc(f),
            new DiffSpec.CommitVsParent(new CommitSha(f.HeadSha)), default);

        diff.Files.Should().ContainSingle(fd => fd.Path == "file_0.txt"
            && fd.ChangeKind == FileChangeKind.Added);
    }
}
