import 'package:flutter/material.dart';
import '../theme/app_palette.dart';

/// Two-pane vertical split with a draggable horizontal handle in between.
/// Top pane fills the leftover space; bottom pane is the resizable one.
///
/// - Drag the handle to resize.
/// - Double-click resets the bottom pane to [defaultBottom].
/// - Bottom height is clamped to [minBottom] .. (parent height - [minTop]).
class VerticalSplitter extends StatefulWidget {
  final Widget top;
  final Widget bottom;
  final double defaultBottom;
  final double minBottom;
  final double minTop;
  final double handleHeight;

  const VerticalSplitter({
    super.key,
    required this.top,
    required this.bottom,
    this.defaultBottom = 320,
    this.minBottom = 140,
    this.minTop = 200,
    this.handleHeight = 5,
  });

  @override
  State<VerticalSplitter> createState() => _VerticalSplitterState();
}

class _VerticalSplitterState extends State<VerticalSplitter> {
  late double _bottom = widget.defaultBottom;
  bool _hover = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Guard against windows shorter than minTop+minBottom: a naive
        // `clamp(minBottom, maxHeight - minTop)` would produce an inverted
        // range (lower > upper) and assert.  Floor the upper bound at
        // minBottom so the range is always valid.
        final maxBottom =
            (constraints.maxHeight - widget.minTop).clamp(widget.minBottom, double.infinity);
        final clamped = _bottom.clamp(widget.minBottom, maxBottom);
        return Column(
          children: [
            Expanded(child: widget.top),
            MouseRegion(
              cursor: SystemMouseCursors.resizeRow,
              onEnter: (_) => setState(() => _hover = true),
              onExit: (_) => setState(() => _hover = false),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragStart: (_) =>
                    setState(() => _dragging = true),
                onVerticalDragUpdate: (d) {
                  setState(() {
                    _bottom = (_bottom - d.delta.dy)
                        .clamp(widget.minBottom, maxBottom);
                  });
                },
                onVerticalDragEnd: (_) =>
                    setState(() => _dragging = false),
                onDoubleTap: () =>
                    setState(() => _bottom = widget.defaultBottom),
                child: Container(
                  height: widget.handleHeight,
                  color: _dragging
                      ? palette.accentCurrent
                      : (_hover ? palette.borderStrong : palette.border),
                ),
              ),
            ),
            SizedBox(height: clamped, child: widget.bottom),
          ],
        );
      },
    );
  }
}
