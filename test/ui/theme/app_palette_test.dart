import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/ui/theme/app_palette.dart';

void main() {
  test('AppPalette.dark and .light produce distinct fg0', () {
    expect(AppPalette.dark().fg0, isNot(AppPalette.light().fg0));
  });

  test('copyWith preserves untouched fields', () {
    final dark = AppPalette.dark();
    final modified = dark.copyWith(fg0: const Color(0xFFEEEEEE));
    expect(modified.fg0, const Color(0xFFEEEEEE));
    expect(modified.bg0, dark.bg0);
  });
}
