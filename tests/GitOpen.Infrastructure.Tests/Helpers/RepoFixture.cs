using LibGit2Sharp;

namespace GitOpen.Infrastructure.Tests.Helpers;

public sealed class RepoFixture : IDisposable
{
    public string Path { get; }
    public string HeadSha { get; private set; } = "";

    private RepoFixture(string path) { Path = path; }

    public static RepoFixture Empty()
    {
        var path = CreateTempPath();
        Repository.Init(path);
        return new RepoFixture(path);
    }

    public static RepoFixture WithLinearHistory(int commits)
    {
        ArgumentOutOfRangeException.ThrowIfLessThan(commits, 1);
        var fixture = Empty();
        using var repo = new Repository(fixture.Path);
        var sig = new Signature("Test", "test@example.com", DateTimeOffset.UtcNow);
        for (var i = 0; i < commits; i++)
        {
            var file = System.IO.Path.Combine(fixture.Path, $"file_{i}.txt");
            File.WriteAllText(file, $"content {i}\n");
            Commands.Stage(repo, $"file_{i}.txt");
            var c = repo.Commit($"commit {i}", sig, sig);
            fixture.HeadSha = c.Sha;
        }
        return fixture;
    }

    public static RepoFixture WithBranches()
    {
        var fixture = WithLinearHistory(3);
        using var repo = new Repository(fixture.Path);
        var sig = new Signature("Test", "test@example.com", DateTimeOffset.UtcNow);
        var feature = repo.CreateBranch("feature");
        Commands.Checkout(repo, feature);
        var file = System.IO.Path.Combine(fixture.Path, "feature.txt");
        File.WriteAllText(file, "feature\n");
        Commands.Stage(repo, "feature.txt");
        repo.Commit("on feature", sig, sig);
        Commands.Checkout(repo, repo.Branches["master"] ?? repo.Branches["main"]!);
        return fixture;
    }

    public void Dispose()
    {
        try { ForceDelete(Path); } catch { /* best-effort cleanup */ }
    }

    private static string CreateTempPath()
    {
        var p = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "gitopen-test-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(p);
        return p;
    }

    private static void ForceDelete(string path)
    {
        if (!Directory.Exists(path)) return;
        foreach (var f in Directory.GetFiles(path, "*", SearchOption.AllDirectories))
            File.SetAttributes(f, FileAttributes.Normal);
        Directory.Delete(path, recursive: true);
    }
}
