import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../application/commit_graph/commit_node.dart';
import 'lane_painter.dart';
import 'ref_decoration.dart';
import 'ref_pill.dart';

class CommitRow extends StatelessWidget {
  final CommitNode node;
  final int maxLane;
  final List<RefDecoration> refs;
  final bool isSelected;
  final VoidCallback onTap;
  /// Called when the user right-clicks / secondary-taps on this row.
  /// Receives the global position of the tap for context-menu placement.
  final void Function(Offset globalPosition)? onSecondaryTap;

  const CommitRow({
    super.key,
    required this.node,
    required this.maxLane,
    required this.refs,
    required this.isSelected,
    required this.onTap,
    this.onSecondaryTap,
  });

  static final _dateFmt = DateFormat('yyyy-MM-dd HH:mm');

  @override
  Widget build(BuildContext context) {
    final bg = isSelected ? const Color(0xFF094771) : Colors.transparent;
    final textColor = isSelected ? Colors.white : const Color(0xFFD4D4D4);
    final mutedColor = isSelected ? Colors.white70 : const Color(0xFFB8B8BC);
    final dateColor = isSelected ? Colors.white70 : const Color(0xFF888892);
    final shaColor = isSelected ? Colors.white : const Color(0xFF6FA8DC);

    return Material(
      color: bg,
      child: GestureDetector(
        onSecondaryTapDown: onSecondaryTap != null
            ? (details) => onSecondaryTap!(details.globalPosition)
            : null,
        child: InkWell(
          onTap: onTap,
          hoverColor: const Color(0xFF34343A),
          child: SizedBox(
            height: kRowHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: svgWidth(maxLane),
                    height: kRowHeight,
                    child: CustomPaint(
                      painter: LanePainter(node: node, maxLane: maxLane),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 70,
                    child: Text(
                      node.commit.sha.short(),
                      style: TextStyle(
                        color: shaColor,
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRect(
                      child: Row(
                        children: [
                          for (final r in refs)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: RefPill(decoration: r),
                            ),
                          if (refs.isNotEmpty) const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              node.commit.summary,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: TextStyle(color: textColor, fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 180,
                    child: Text(
                      node.commit.author.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: mutedColor, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 130,
                    child: Text(
                      _dateFmt.format(node.commit.author.when.toLocal()),
                      style: TextStyle(
                        color: dateColor,
                        fontSize: 11.5,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
