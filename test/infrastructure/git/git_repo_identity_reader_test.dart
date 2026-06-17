import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/domain/repositories/repo_id.dart';
import 'package:gitopen/domain/repositories/repo_location.dart';
import 'package:gitopen/infrastructure/git/git_repo_identity_reader.dart';
import '../../_helpers/repo_fixture.dart';

void main() {
  test('returns the repo local user.email', () async {
    final f = await RepoFixture.empty();
    try {
      await Process.run(
        'git',
        ['config', 'user.email', 'me@personal.dev'],
        workingDirectory: f.path,
      );
      final reader = GitRepoIdentityReader();
      final loc = RepoLocation(const RepoId('r'), f.path, 'test');
      expect(await reader.effectiveEmail(loc), 'me@personal.dev');
    } finally {
      await f.dispose();
    }
  });
}
