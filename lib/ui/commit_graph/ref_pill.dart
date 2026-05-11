import 'package:flutter/material.dart';
import 'ref_decoration.dart';

class RefPill extends StatelessWidget {
  final RefDecoration decoration;
  const RefPill({super.key, required this.decoration});

  @override
  Widget build(BuildContext context) {
    final palette = _palette();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: decoration.isCurrent ? palette.bgCurrent : palette.bg,
        border: Border.all(color: palette.border, width: 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (decoration.isCurrent)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Text(
                'HEAD →',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0A1F1A),
                ),
              ),
            ),
          Text(
            decoration.name,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: decoration.isCurrent ? const Color(0xFF0A1F1A) : palette.fg,
            ),
          ),
        ],
      ),
    );
  }

  _PillPalette _palette() {
    if (decoration.isTag) {
      return const _PillPalette(
        bg: Color(0x24D7BA7D),
        bgCurrent: Color(0xFFD7BA7D),
        border: Color(0x73D7BA7D),
        fg: Color(0xFFD7BA7D),
      );
    }
    if (decoration.isRemote) {
      return const _PillPalette(
        bg: Color(0x24569CD6),
        bgCurrent: Color(0xFF569CD6),
        border: Color(0x73569CD6),
        fg: Color(0xFF569CD6),
      );
    }
    // Branch
    return const _PillPalette(
      bg: Color(0x244EC9B0),
      bgCurrent: Color(0xFF4EC9B0),
      border: Color(0x734EC9B0),
      fg: Color(0xFF4EC9B0),
    );
  }
}

class _PillPalette {
  final Color bg;
  final Color bgCurrent;
  final Color border;
  final Color fg;
  const _PillPalette({
    required this.bg,
    required this.bgCurrent,
    required this.border,
    required this.fg,
  });
}
