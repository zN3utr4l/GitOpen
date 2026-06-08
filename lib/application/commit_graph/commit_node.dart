import 'package:equatable/equatable.dart';
import 'package:gitopen/application/commit_graph/lane_segment.dart';
import 'package:gitopen/domain/commits/commit_info.dart';

final class CommitNode extends Equatable {

  const CommitNode({
    required this.commit,
    required this.lane,
    required this.color,
    required this.topSegments,
    required this.bottomSegments,
  });
  final CommitInfo commit;
  final int lane;
  final int color;
  final List<LaneSegment> topSegments;
  final List<LaneSegment> bottomSegments;

  @override
  List<Object?> get props => [commit, lane, color, topSegments, bottomSegments];
}
