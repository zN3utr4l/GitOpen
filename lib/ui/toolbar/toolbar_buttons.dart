import 'package:flutter/material.dart';
import 'package:gitopen/ui/theme/app_design_tokens.dart';
import 'package:gitopen/ui/theme/app_palette.dart';

/// Plain toolbar action button (icon + label).
class ToolbarButton extends StatelessWidget {
  const ToolbarButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    super.key,
    this.tooltip,
  });
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  /// Hover hint — used to surface the action's keyboard shortcut. Also
  /// becomes the button's semantics label for screen readers.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final tip = tooltip;
    if (tip != null) {
      return Tooltip(
        message: tip,
        waitDuration: const Duration(milliseconds: 500),
        child: _body(context),
      );
    }
    return _body(context);
  }

  Widget _body(BuildContext context) {
    final palette = AppPalette.of(context);
    final spacing = AppSpacing.of(context);
    final radii = AppRadii.of(context);
    final typography = AppTypography.of(context);
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: radii.controlRadius,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.md - 2,
            vertical: spacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: palette.fg1),
              const SizedBox(width: 5),
              Text(label, style: typography.body.copyWith(color: palette.fg0)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dropdown trigger button — same visual style as [ToolbarButton] but includes
/// a small chevron to signal it opens a menu.
class ToolbarDropdownButton extends StatelessWidget {
  const ToolbarDropdownButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    super.key,
  });
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final spacing = AppSpacing.of(context);
    final radii = AppRadii.of(context);
    final typography = AppTypography.of(context);
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: radii.controlRadius,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.md - 2,
            vertical: spacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: palette.fg1),
              const SizedBox(width: 5),
              Text(label, style: typography.body.copyWith(color: palette.fg0)),
              const SizedBox(width: 3),
              Icon(Icons.expand_more, size: 12, color: palette.fg2),
            ],
          ),
        ),
      ),
    );
  }
}
