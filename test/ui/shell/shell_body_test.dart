import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/ui/shell/shell_body.dart';

void main() {
  group('shellBodyFor', () {
    test('settings wins even with no active repo (the empty-catalog bug)', () {
      // Repro: user removed every repo, then clicked Settings. Settings must
      // still open instead of being shadowed by the welcome screen.
      expect(
        shellBodyFor(settingsOpen: true, hasActiveRepo: false),
        ShellBody.settings,
      );
    });

    test('settings wins when a repo is active too', () {
      expect(
        shellBodyFor(settingsOpen: true, hasActiveRepo: true),
        ShellBody.settings,
      );
    });

    test('no active repo and settings closed -> welcome', () {
      expect(
        shellBodyFor(settingsOpen: false, hasActiveRepo: false),
        ShellBody.welcome,
      );
    });

    test('active repo and settings closed -> repo body', () {
      expect(
        shellBodyFor(settingsOpen: false, hasActiveRepo: true),
        ShellBody.repo,
      );
    });
  });
}
