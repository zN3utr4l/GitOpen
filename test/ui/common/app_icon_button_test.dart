import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/ui/common/app_icon_button.dart';
import 'package:gitopen/ui/theme/app_design_tokens.dart';
import 'package:gitopen/ui/theme/app_palette.dart';

Widget _host(Widget child) => MaterialApp(
  theme: ThemeData(
    extensions: [
      AppPalette.dark(),
      const AppSpacing.desktop(),
      const AppRadii.desktop(),
      const AppTypography.desktop(),
      const AppMotion.standard(),
    ],
  ),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('fires tap and exposes button semantics', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        AppIconButton(
          icon: Icons.delete_outline,
          tooltip: 'Discard changes',
          onPressed: () => taps++,
        ),
      ),
    );

    await tester.tap(find.byTooltip('Discard changes'));
    expect(taps, 1);
    final semantics = tester.getSemantics(
      find.bySemanticsLabel('Discard changes'),
    );
    expect(semantics.flagsCollection.isButton, isTrue);
  });

  testWidgets('disabled action does not fire and selected is semantic', (
    tester,
  ) async {
    const taps = 0;
    await tester.pumpWidget(
      _host(
        const AppIconButton(
          icon: Icons.list,
          tooltip: 'Tree view',
          selected: true,
          onPressed: null,
        ),
      ),
    );

    await tester.tap(find.byTooltip('Tree view'));
    expect(taps, 0);
    final semantics = tester.getSemantics(find.bySemanticsLabel('Tree view'));
    expect(semantics.flagsCollection.isSelected, Tristate.isTrue);
  });
}
