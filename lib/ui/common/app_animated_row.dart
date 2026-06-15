import 'package:flutter/material.dart';
import 'package:gitopen/ui/theme/app_design_tokens.dart';
import 'package:gitopen/ui/theme/app_palette.dart';

class AppAnimatedRow extends StatefulWidget {
  const AppAnimatedRow({
    required this.child,
    required this.selected,
    required this.onTap,
    super.key,
    this.semanticLabel,
    this.onSecondaryTapDown,
    this.height,
    this.padding,
  });

  final Widget child;
  final bool selected;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final GestureTapDownCallback? onSecondaryTapDown;
  final double? height;
  final EdgeInsetsGeometry? padding;

  @override
  State<AppAnimatedRow> createState() => _AppAnimatedRowState();
}

class _AppAnimatedRowState extends State<AppAnimatedRow> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final spacing = AppSpacing.of(context);
    final radii = AppRadii.of(context);
    final motion = AppMotion.of(context);
    final bg = widget.selected
        ? palette.bgAccent
        : _hovered
        ? palette.bg2
        : Colors.transparent;
    final border = _focused ? palette.accentRemote : Colors.transparent;

    final content = AnimatedContainer(
      duration: motion.normal,
      curve: motion.curve,
      height: widget.height,
      padding: widget.padding ?? spacing.row,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: widget.selected || _hovered ? radii.rowRadius : null,
        border: Border.all(color: border),
      ),
      child: widget.child,
    );

    return Semantics(
      button: widget.onTap != null,
      selected: widget.selected,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        mouseCursor: widget.onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        child: GestureDetector(
          onSecondaryTapDown: widget.onSecondaryTapDown,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: radii.rowRadius,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
