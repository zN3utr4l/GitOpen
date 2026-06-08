import 'package:equatable/equatable.dart';

final class LaneSegment extends Equatable {
  const LaneSegment(this.fromLane, this.toLane, this.color);
  final int fromLane;
  final int toLane;
  final int color;
  @override
  List<Object?> get props => [fromLane, toLane, color];
}
