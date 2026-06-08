import 'package:flutter/material.dart';
import 'package:gitopen/application/commit_graph/commit_node.dart';
import 'package:gitopen/application/commit_graph/lane_segment.dart';
import 'package:gitopen/ui/theme/app_palette.dart' show AppPalette;

const double kLaneSpacing = 16;
const double kLanePad = 12;
const double kRowHeight = 26;
const double kHalfHeight = 13;

double laneX(int lane) => kLanePad + lane * kLaneSpacing;

double svgWidth(int maxLane) => kLanePad * 2 + kLaneSpacing * (maxLane + 1);

class LanePainter extends CustomPainter {

  const LanePainter({
    required this.node,
    required this.maxLane,
    required this.lanePalette,
  });
  final CommitNode node;
  final int maxLane;
  /// The lane colour palette, passed in from the caller that has a
  /// [BuildContext] (and therefore access to [AppPalette]).
  final List<Color> lanePalette;

  Color _laneColor(int idx) => lanePalette[idx.abs() % lanePalette.length];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    for (final s in node.topSegments) {
      paint.color = _laneColor(s.color);
      _drawSegment(canvas, paint, s, fromY: 0, toY: kHalfHeight);
    }
    for (final s in node.bottomSegments) {
      paint.color = _laneColor(s.color);
      _drawSegment(canvas, paint, s, fromY: kHalfHeight, toY: kRowHeight);
    }

    // Commit dot
    final dot = Paint()
      ..style = PaintingStyle.fill
      ..color = _laneColor(node.color);
    canvas.drawCircle(Offset(laneX(node.lane), kHalfHeight), 4, dot);
  }

  void _drawSegment(Canvas canvas, Paint paint, LaneSegment s,
      {required double fromY, required double toY}) {
    final x1 = laneX(s.fromLane);
    final x2 = laneX(s.toLane);
    if (s.fromLane == s.toLane) {
      canvas.drawLine(Offset(x1, fromY), Offset(x2, toY), paint);
      return;
    }
    // Smooth cubic Bezier with vertical tangents at both ends.
    final midY = fromY + (toY - fromY) / 2;
    final path = Path()
      ..moveTo(x1, fromY)
      ..cubicTo(x1, midY, x2, midY, x2, toY);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant LanePainter old) =>
      old.node != node ||
      old.maxLane != maxLane ||
      old.lanePalette != lanePalette;
}
