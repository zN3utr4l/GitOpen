import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/application/launcher/repo_launcher.dart';

void main() {
  group('EditorTarget', () {
    test('equality is by id', () {
      const a = EditorTarget(id: 'vscode', displayName: 'VS Code', executable: 'code');
      const b = EditorTarget(id: 'vscode', displayName: 'VS Code', executable: '/usr/local/bin/code');
      expect(a, equals(b));
    });

    test('toString shows displayName', () {
      const e = EditorTarget(id: 'cursor', displayName: 'Cursor', executable: 'cursor');
      expect(e.toString(), contains('Cursor'));
    });
  });
}
