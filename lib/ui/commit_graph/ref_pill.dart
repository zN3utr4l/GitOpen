import 'package:flutter/material.dart';
import 'ref_decoration.dart';

/// Fork-style ref pill. Renders as a single pill split into two halves
/// when the local branch is synced with one or more remotes: left half
/// shows the branch name (with ✓ if current), right half shows the
/// remote name(s) prefixed with ⇄ to signal the sync.
class RefPill extends StatelessWidget {
  final RefDecoration decoration;
  const RefPill({super.key, required this.decoration});

  @override
  Widget build(BuildContext context) {
    final palette = _palette();

    final localSide = _Section(
      icon: _leadingIcon(palette),
      label: decoration.name,
      fg: palette.fg,
    );

    if (!decoration.isSynced) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
        decoration: BoxDecoration(
          color: palette.bg,
          border: Border.all(color: palette.border, width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: localSide,
      );
    }

    // Synced pill: local section + divider + remote section.
    return Container(
      decoration: BoxDecoration(
        color: palette.bg,
        border: Border.all(color: palette.border, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
              child: localSide,
            ),
            Container(
              width: 1,
              color: palette.border,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
              color: palette.remoteTintBg,
              child: _Section(
                icon: Icon(Icons.sync_alt, size: 10, color: palette.remoteFg),
                label: decoration.syncedRemotes.join(', '),
                fg: palette.remoteFg,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _leadingIcon(_PillPalette palette) {
    if (decoration.isCurrent) {
      return const Icon(Icons.check, size: 11, color: Color(0xFF4EC9B0));
    }
    if (decoration.isTag) {
      return Icon(Icons.local_offer_outlined, size: 10, color: palette.fg);
    }
    if (decoration.isRemote) {
      return Icon(Icons.cloud_outlined, size: 11, color: palette.fg);
    }
    return Icon(Icons.commit_outlined, size: 10, color: palette.fg);
  }

  _PillPalette _palette() {
    if (decoration.isTag) {
      return const _PillPalette(
        bg: Color(0xFF2C2A22),
        border: Color(0xFF5A4E2D),
        fg: Color(0xFFD7BA7D),
        remoteTintBg: Color(0xFF1E2A36),
        remoteFg: Color(0xFF7FB3DE),
      );
    }
    if (decoration.isRemote) {
      return const _PillPalette(
        bg: Color(0xFF1E2A36),
        border: Color(0xFF3F5F7F),
        fg: Color(0xFF7FB3DE),
        remoteTintBg: Color(0xFF1E2A36),
        remoteFg: Color(0xFF7FB3DE),
      );
    }
    if (decoration.isCurrent) {
      return const _PillPalette(
        bg: Color(0xFF1F3128),
        border: Color(0xFF4EC9B0),
        fg: Color(0xFFA5E4D2),
        remoteTintBg: Color(0xFF1E2A36),
        remoteFg: Color(0xFF7FB3DE),
      );
    }
    return const _PillPalette(
      bg: Color(0xFF252A28),
      border: Color(0xFF3F5F55),
      fg: Color(0xFF8FD4C0),
      remoteTintBg: Color(0xFF1E2A36),
      remoteFg: Color(0xFF7FB3DE),
    );
  }
}

class _Section extends StatelessWidget {
  final Widget icon;
  final String label;
  final Color fg;
  const _Section({required this.icon, required this.label, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: fg,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

class _PillPalette {
  final Color bg;
  final Color border;
  final Color fg;
  final Color remoteTintBg;
  final Color remoteFg;
  const _PillPalette({
    required this.bg,
    required this.border,
    required this.fg,
    required this.remoteTintBg,
    required this.remoteFg,
  });
}
