import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/infrastructure/git/git_process_runner.dart';

void main() {
  group('buildGitEnvironment', () {
    test('forces the C locale', () {
      final env = buildGitEnvironment();
      expect(env['LC_ALL'], 'C');
      expect(env['LANG'], 'C');
    });

    test('merges extra env without dropping the locale', () {
      final env = buildGitEnvironment({'GIT_TERMINAL_PROMPT': '0'});
      expect(env['GIT_TERMINAL_PROMPT'], '0');
      expect(env['LC_ALL'], 'C');
      expect(env['LANG'], 'C');
    });

    test('locale always wins over a conflicting extra value', () {
      final env = buildGitEnvironment({'LC_ALL': 'it_IT.UTF-8'});
      expect(env['LC_ALL'], 'C');
    });
  });
}
