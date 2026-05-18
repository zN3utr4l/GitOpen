import '../../domain/commits/commit_info.dart';
import '../../domain/commits/commit_sha.dart';
import 'commit_node.dart';
import 'lane_segment.dart';

abstract interface class CommitGraphLayout {
  List<CommitNode> compute(List<CommitInfo> commitsNewestFirst);
}

/// Lays commits out into lanes and assigns a stable colour to each branch
/// "strand" (a chain of commits linked by first-parent edges).
///
/// The colour is bound to the strand identity, not to the lane index — so
/// a lane that gets freed and later reused by an unrelated branch receives
/// a fresh colour, and a branch that re-joins its fork point keeps its own
/// colour on the way down while the trunk it merges into keeps its own
/// colour on the pass-through. This is the same colouring rule Fork uses.
final class DefaultCommitGraphLayout implements CommitGraphLayout {
  const DefaultCommitGraphLayout();

  @override
  List<CommitNode> compute(List<CommitInfo> commitsNewestFirst) {
    if (commitsNewestFirst.isEmpty) return const [];

    // Active lanes: index -> sha each lane is currently waiting to render,
    // with a parallel array tracking the lane's current strand colour.
    final lanes = <CommitSha?>[];
    final laneColors = <int?>[];
    var nextColor = 0;
    final result = <CommitNode>[];

    // Snapshot of `lanes`/`laneColors` at the end of the previous row, used
    // to draw top segments (connections from the previous row's lane
    // positions to this row's lane positions).
    var prevLanes = <CommitSha?>[];
    var prevColors = <int?>[];

    for (final commit in commitsNewestFirst) {
      // 1) Find this commit's lane. If no lane is waiting for it, this
      //    commit is a strand root (branch tip with no descendant in the
      //    visible window): allocate a free slot and a fresh colour.
      var ownLane = -1;
      for (var i = 0; i < lanes.length; i++) {
        if (lanes[i] == commit.sha) {
          ownLane = i;
          break;
        }
      }
      final int ownColor;
      if (ownLane == -1) {
        ownLane = lanes.indexOf(null);
        if (ownLane == -1) {
          ownLane = lanes.length;
          lanes.add(null);
          laneColors.add(null);
        }
        ownColor = nextColor++;
        laneColors[ownLane] = ownColor;
      } else {
        ownColor = laneColors[ownLane]!;
      }

      // 2) Top segments: every previously-active lane connects from its
      //    previous index (at y=0) to its position at y=12. Lanes waiting
      //    for THIS commit converge to ownLane; everyone else passes
      //    through vertically. Colours come from the previous snapshot so
      //    each strand keeps its colour across the boundary.
      final topSegments = <LaneSegment>[];
      for (var i = 0; i < prevLanes.length; i++) {
        final sha = prevLanes[i];
        if (sha == null) continue;
        final color = prevColors[i] ?? 0;
        if (sha == commit.sha) {
          topSegments.add(LaneSegment(i, ownLane, color));
        } else {
          topSegments.add(LaneSegment(i, i, color));
        }
      }

      // 3) Free our own lane; first parent (if any) may reclaim it.
      lanes[ownLane] = null;
      laneColors[ownLane] = null;

      // Snapshot the OTHER strands that are passing through this row.
      // These contribute vertical pass-through segments in the bottom
      // half regardless of what our parents do.
      final preParentLanes = List<CommitSha?>.of(lanes);
      final preParentColors = List<int?>.of(laneColors);

      // 4) Assign parents to lanes.
      final parentLaneIndices = <int>[];
      final parentEdgeColors = <int>[];
      for (var pi = 0; pi < commit.parentShas.length; pi++) {
        final parentSha = commit.parentShas[pi];

        // If a lane already waits for this parent (typical merge-back to
        // the fork point), reuse it. The existing strand keeps its colour;
        // our outgoing edge uses our own strand colour so the curve looks
        // like the tail of OUR branch joining the established line.
        var existing = -1;
        for (var i = 0; i < lanes.length; i++) {
          if (lanes[i] == parentSha) {
            existing = i;
            break;
          }
        }
        if (existing >= 0) {
          parentLaneIndices.add(existing);
          parentEdgeColors.add(ownColor);
          continue;
        }

        final int targetLane;
        final int color;
        if (pi == 0) {
          // First parent continues the current strand in the same lane
          // and inherits its colour.
          targetLane = ownLane;
          color = ownColor;
        } else {
          // Non-first parent is a merged-in side branch. It starts a new
          // strand on a free slot with a fresh colour.
          var slot = lanes.indexOf(null);
          if (slot == -1) {
            slot = lanes.length;
            lanes.add(null);
            laneColors.add(null);
          }
          targetLane = slot;
          color = nextColor++;
        }
        lanes[targetLane] = parentSha;
        laneColors[targetLane] = color;
        parentLaneIndices.add(targetLane);
        parentEdgeColors.add(color);
      }

      // Trim trailing nulls so the lane width stays minimal.
      while (lanes.isNotEmpty && lanes.last == null) {
        lanes.removeLast();
        laneColors.removeLast();
      }

      // 5) Bottom segments:
      //    a) Every strand that was passing through this row (snapshot
      //       taken AFTER we freed our own lane but BEFORE parent
      //       allocation) continues vertically — this is the key piece
      //       that keeps a merged-into trunk visible at the merge-back
      //       row, with its own colour.
      //    b) For each parent, draw an edge from our dot (ownLane) to the
      //       parent's lane, coloured by the strand entering that edge.
      final bottomSegments = <LaneSegment>[];
      for (var i = 0; i < preParentLanes.length; i++) {
        if (preParentLanes[i] == null) continue;
        bottomSegments.add(LaneSegment(i, i, preParentColors[i] ?? 0));
      }
      for (var k = 0; k < parentLaneIndices.length; k++) {
        bottomSegments.add(LaneSegment(
          ownLane,
          parentLaneIndices[k],
          parentEdgeColors[k],
        ));
      }

      result.add(CommitNode(
        commit: commit,
        lane: ownLane,
        color: ownColor,
        topSegments: topSegments,
        bottomSegments: bottomSegments,
      ));

      // 6) Snapshot lanes/colours for the next row's top-segment pass.
      prevLanes = List<CommitSha?>.of(lanes);
      prevColors = List<int?>.of(laneColors);
    }

    return result;
  }
}
