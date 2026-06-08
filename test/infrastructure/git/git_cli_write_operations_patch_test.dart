import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/application/git/git_result.dart';
import 'package:gitopen/domain/repositories/repo_id.dart';
import 'package:gitopen/domain/repositories/repo_location.dart';
import 'package:gitopen/infrastructure/git/git_cli_write_operations.dart';
import 'package:path/path.dart' as p;
import '../../_helpers/repo_fixture.dart';

void main() {
  test('stagePatch applies a unified diff', () async {
    final f = await RepoFixture.withLinearHistory(1);
    try {
      // Modify file_0.txt: original is "content 0\n"
      File(p.join(f.path, 'file_0.txt'))
          .writeAsStringSync('content 0\nnew line\n');
      const patch = '''
diff --git a/file_0.txt b/file_0.txt
--- a/file_0.txt
+++ b/file_0.txt
@@ -1 +1,2 @@
 content 0
+new line
''';
      final sut = GitCliWriteOperations();
      final res = await sut.stagePatch(
        RepoLocation(RepoId.newId(), f.path, 't'),
        patch,
      );
      expect(res, isA<GitSuccess<void>>());
      final status = await Process.run(
        'git',
        ['diff', '--cached', '--name-only'],
        workingDirectory: f.path,
      );
      expect(status.stdout.toString(), contains('file_0.txt'));
    } finally {
      await f.dispose();
    }
  });
}
