using GitOpen.Domain.Commits;

namespace GitOpen.Application.CommitGraph;

public sealed class CommitGraphLayout : ICommitGraphLayout
{
    public IReadOnlyList<CommitNode> Compute(IReadOnlyList<CommitInfo> commitsNewestFirst)
    {
        if (commitsNewestFirst.Count == 0) return Array.Empty<CommitNode>();

        // Active lanes: index -> sha that this lane is currently waiting for.
        var lanes = new List<CommitSha?>();
        var laneColor = new Dictionary<int, int>();
        var nextColor = 0;
        var result = new List<CommitNode>(commitsNewestFirst.Count);

        foreach (var commit in commitsNewestFirst)
        {
            // Find the lane reserved for this sha (where some descendant pointed to us)
            var ownLane = -1;
            for (var i = 0; i < lanes.Count; i++)
            {
                if (lanes[i] == commit.Sha) { ownLane = i; break; }
            }
            if (ownLane == -1)
            {
                ownLane = lanes.IndexOf(null);
                if (ownLane == -1) { ownLane = lanes.Count; lanes.Add(null); }
                if (!laneColor.ContainsKey(ownLane)) laneColor[ownLane] = nextColor++;
            }

            // Free our own lane (we're done at this row, parents may reuse it)
            lanes[ownLane] = null;

            // Assign parents to lanes
            var parentLanes = new List<int>(commit.ParentShas.Count);
            for (var pi = 0; pi < commit.ParentShas.Count; pi++)
            {
                var parentSha = commit.ParentShas[pi];

                // If a lane already waits for this parent, reuse it
                var existing = -1;
                for (var i = 0; i < lanes.Count; i++)
                    if (lanes[i] == parentSha) { existing = i; break; }
                if (existing >= 0) { parentLanes.Add(existing); continue; }

                int targetLane;
                if (pi == 0)
                {
                    // First parent: keep our own lane
                    targetLane = ownLane;
                    lanes[ownLane] = parentSha;
                }
                else
                {
                    targetLane = lanes.IndexOf(null);
                    if (targetLane == -1) { targetLane = lanes.Count; lanes.Add(parentSha); }
                    else lanes[targetLane] = parentSha;
                    if (!laneColor.ContainsKey(targetLane)) laneColor[targetLane] = nextColor++;
                }
                parentLanes.Add(targetLane);
            }

            // Trim trailing nulls
            while (lanes.Count > 0 && lanes[^1] is null) lanes.RemoveAt(lanes.Count - 1);

            result.Add(new CommitNode(commit, ownLane, laneColor[ownLane], parentLanes));
        }
        return result;
    }
}
