using FluentAssertions;
using GitOpen.Domain.Commits;
using GitOpen.Domain.Files;
using GitOpen.Domain.Repositories;
using GitOpen.Infrastructure.Git;
using GitOpen.Infrastructure.Tests.Helpers;
using Xunit;

namespace GitOpen.Infrastructure.Tests.Git;

public class LibGit2GitReadOperations_FileTree_Tests
{
    private static RepoLocation Loc(RepoFixture f) => new(RepoId.NewId(), f.Path, "test");

    [Fact]
    public async Task GetFileTreeAsync_lists_root_files_for_commit()
    {
        using var f = RepoFixture.WithLinearHistory(3);
        var sut = new LibGit2GitReadOperations();

        var entries = await sut.GetFileTreeAsync(Loc(f), new CommitSha(f.HeadSha), "", default);

        entries.Should().Contain(e => e.Name == "file_0.txt" && e.Kind == FileTreeKind.Blob);
        entries.Should().Contain(e => e.Name == "file_1.txt");
        entries.Should().Contain(e => e.Name == "file_2.txt");
    }
}
