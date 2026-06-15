import 'package:flutter/material.dart';
import 'package:gitopen/ui/theme/app_design_tokens.dart';
import 'package:gitopen/ui/theme/app_palette.dart';

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
    this.actionIcon,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final IconData? actionIcon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final spacing = AppSpacing.of(context);
    final typography = AppTypography.of(context);
    return Center(
      child: Padding(
        padding: spacing.panel,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: palette.fg3),
            SizedBox(height: spacing.sm),
            Text(
              title,
              textAlign: TextAlign.center,
              style: typography.bodyStrong.copyWith(color: palette.fg1),
            ),
            SizedBox(height: spacing.xxs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: typography.body.copyWith(color: palette.fg3),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: spacing.md),
              FilledButton.icon(
                icon: Icon(actionIcon ?? Icons.refresh, size: 15),
                label: Text(actionLabel!),
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
