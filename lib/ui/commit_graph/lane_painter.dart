import 'package:flutter/material.dart';
import '../../application/commit_graph/commit_node.dart';
import '../../application/commit_graph/lane_segment.dart';

const double kLaneSpacing = 16.0;
const double kLanePad = 12.0;
const double kRowHeight = 26.0;
const double kHalfHeight = 13.0;

const List<Color> kLanePalette = [
  Color(0xFF5FB3A1),
  Color(0xFFD6C068),
  Color(0xFF6FA8DC),
  Color(0xFFC97C5D),
  Color(0xFFB787B3),
  Color(0xFF7A98C9),
  Color(0xFFC79A5D),
  Color(0xFFC97078),
];

Color laneColor(int idx) => kLanePalette[idx.abs() % kLanePalette.length];

double laneX(int lane) => kLanePad + lane * kLaneSpacing;

double svgWidth(int maxLane) => kLanePad * 2 + kLaneSpacing * (maxLane + 1);

class LanePainter extends CustomPainter {
  final CommitNode node;
  final int maxLane;
  const LanePainter({required this.node, required this.maxLane});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    for (final s in node.topSegments) {
      paint.color = laneColor(s.color);
      _drawSegment(canvas, paint, s, fromY: 0, toY: kHalfHeight);
    }
    for (final s in node.bottomSegments) {
      paint.color = laneColor(s.color);
      _drawSegment(canvas, paint, s, fromY: kHalfHeight, toY: kRowHeight);
    }

    // Commit dot
    final dot = Paint()
      ..style = PaintingStyle.fill
      ..color = laneColor(node.color);
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
      old.node != node || old.maxLane != maxLane;
}
