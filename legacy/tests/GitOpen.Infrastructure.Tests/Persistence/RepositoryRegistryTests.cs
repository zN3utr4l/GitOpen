using FluentAssertions;
using GitOpen.Infrastructure.Persistence;
using GitOpen.Infrastructure.Tests.Helpers;
using Xunit;

namespace GitOpen.Infrastructure.Tests.Persistence;

public class RepositoryRegistryTests
{
    [Fact]
    public async Task AddAsync_persists_repo_and_returns_location()
    {
        using var db = InMemoryDb.CreateInMemory();
        var sut = new RepositoryRegistry(db);

        var loc = await sut.AddAsync("/tmp/foo/.git/..", default);

        loc.Path.Should().Be("/tmp/foo/.git/..");
        loc.DisplayName.Should().NotBeNullOrEmpty();
        var listed = await sut.ListAsync(default);
        listed.Should().ContainSingle(r => r.Id == loc.Id);
    }

    [Fact]
    public async Task AddAsync_returns_existing_when_path_already_known()
    {
        using var db = InMemoryDb.CreateInMemory();
        var sut = new RepositoryRegistry(db);

        var first = await sut.AddAsync("/tmp/dup", default);
        var second = await sut.AddAsync("/tmp/dup", default);

        second.Id.Should().Be(first.Id);
        (await sut.ListAsync(default)).Should().HaveCount(1);
    }

    [Fact]
    public async Task RemoveAsync_deletes_the_repo()
    {
        using var db = InMemoryDb.CreateInMemory();
        var sut = new RepositoryRegistry(db);
        var loc = await sut.AddAsync("/tmp/gone", default);

        await sut.RemoveAsync(loc.Id, default);

        (await sut.ListAsync(default)).Should().BeEmpty();
    }

    [Fact]
    public async Task TouchLastOpenedAsync_updates_timestamp()
    {
        using var db = InMemoryDb.CreateInMemory();
        var sut = new RepositoryRegistry(db);
        var loc = await sut.AddAsync("/tmp/x", default);
        var initial = (await sut.GetByPathAsync("/tmp/x", default))!;
        await Task.Delay(10);

        await sut.TouchLastOpenedAsync(loc.Id, default);

        var raw = db.Repositories.Single(r => r.Id == loc.Id.Value);
        raw.LastOpenedUtc.Should().BeAfter(default(DateTime));
    }
}
