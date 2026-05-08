using FluentAssertions;
using GitOpen.Application.CommitGraph;
using GitOpen.Domain.Commits;
using Xunit;

namespace GitOpen.Application.Tests.CommitGraph;

public class CommitGraphLayoutTests
{
    private static CommitInfo Mk(string sha, params string[] parents) =>
        new(
            new CommitSha(sha.PadLeft(8, '0')),
            parents.Select(p => new CommitSha(p.PadLeft(8, '0'))).ToList(),
            new CommitSignature("a", "a@x", DateTimeOffset.UtcNow),
            new CommitSignature("a", "a@x", DateTimeOffset.UtcNow),
            "msg", "msg");

    [Fact]
    public void Linear_history_all_in_lane_zero()
    {
        var commits = new[]
        {
            Mk("c", "b"),
            Mk("b", "a"),
            Mk("a")
        };
        var sut = new CommitGraphLayout();

        var nodes = sut.Compute(commits);

        nodes.Should().HaveCount(3);
        nodes.Should().OnlyContain(n => n.Lane == 0);
    }

    [Fact]
    public void Branch_creates_two_lanes()
    {
        // c (HEAD) with parents b1 and b2 (a merge); b1 -> a, b2 -> a
        var commits = new[]
        {
            Mk("c",  "b1", "b2"),
            Mk("b1", "a"),
            Mk("b2", "a"),
            Mk("a")
        };
        var sut = new CommitGraphLayout();

        var nodes = sut.Compute(commits);

        nodes.Select(n => n.Lane).Should().Contain(0).And.Contain(1);
        nodes[nodes.Count - 1].Lane.Should().Be(0); // root collapses back
    }

    [Fact]
    public void Empty_input_returns_empty()
    {
        var sut = new CommitGraphLayout();
        sut.Compute(Array.Empty<CommitInfo>()).Should().BeEmpty();
    }
}
