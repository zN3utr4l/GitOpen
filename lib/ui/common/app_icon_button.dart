import 'package:flutter/material.dart';
import 'package:gitopen/ui/theme/app_design_tokens.dart';
import 'package:gitopen/ui/theme/app_palette.dart';

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    super.key,
    this.selected = false,
    this.danger = false,
    this.size = 28,
    this.iconSize = 14,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;
  final bool danger;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final radii = AppRadii.of(context);
    final motion = AppMotion.of(context);
    final enabled = onPressed != null;
    final fg = danger
        ? palette.accentErr
        : selected
        ? palette.fg0
        : palette.fg2;
    final bg = selected ? palette.bgAccent : Colors.transparent;

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        selected: selected,
        label: tooltip,
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              canRequestFocus: enabled,
              borderRadius: radii.controlRadius,
              focusColor: palette.accentRemote.withValues(alpha: 0.24),
              hoverColor: palette.bg4,
              child: AnimatedContainer(
                width: size,
                height: size,
                duration: motion.fast,
                curve: motion.curve,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: radii.controlRadius,
                  border: Border.all(
                    color: selected ? palette.borderStrong : Colors.transparent,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: iconSize, color: fg),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
