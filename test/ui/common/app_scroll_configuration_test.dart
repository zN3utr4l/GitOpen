import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/ui/common/app_scroll_configuration.dart';
import 'package:gitopen/ui/theme/app_design_tokens.dart';
import 'package:gitopen/ui/theme/app_palette.dart';

void main() {
  testWidgets('wraps scrollables with styled scrollbars', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: [
            AppPalette.dark(),
            const AppSpacing.desktop(),
            const AppRadii.desktop(),
            const AppTypography.desktop(),
            const AppMotion.standard(),
          ],
        ),
        home: AppScrollConfiguration(
          child: SizedBox(
            width: 200,
            height: 100,
            child: ListView(
              children: const [
                SizedBox(height: 1000, child: Text('long')),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(Scrollbar), findsWidgets);
  });
}
