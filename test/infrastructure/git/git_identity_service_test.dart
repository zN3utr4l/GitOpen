import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/domain/repositories/repo_id.dart';
import 'package:gitopen/domain/repositories/repo_location.dart';
import 'package:gitopen/infrastructure/git/git_identity_service.dart';
import '../../_helpers/repo_fixture.dart';

void main() {
  RepoLocation loc(RepoFixture f) =>
      RepoLocation(RepoId.newId(), f.path, 'test');

  Future<void> git(String cwd, List<String> args) async {
    final r = await Process.run('git', args, workingDirectory: cwd);
    if (r.exitCode != 0) {
      throw StateError('git ${args.join(' ')} failed: ${r.stderr}');
    }
  }

  group('GitIdentityService.readLocal', () {
    test('reads local user.name / user.email set in the repo config',
        () async {
      final f = await RepoFixture.empty();
      try {
        // RepoFixture.empty sets these as local config already.
        final sut = GitIdentityService();
        final id = await sut.readLocal(loc(f));
        expect(id.name, 'Test');
        expect(id.email, 'test@example.com');
      } finally {
        await f.dispose();
      }
    });

    test('returns null fields when not set locally', () async {
      final f = await RepoFixture.empty();
      try {
        await git(f.path, ['config', '--local', '--unset', 'user.name']);
        await git(f.path, ['config', '--local', '--unset', 'user.email']);
        final sut = GitIdentityService();
        final id = await sut.readLocal(loc(f));
        expect(id.name, isNull);
        expect(id.email, isNull);
      } finally {
        await f.dispose();
      }
    });
  });

  group('GitIdentityService.setLocal', () {
    test('writes name/email that readLocal then reports', () async {
      final f = await RepoFixture.empty();
      try {
        final sut = GitIdentityService();
        await sut.setLocal(loc(f), 'Ada Lovelace', 'ada@analytical.test');
        final id = await sut.readLocal(loc(f));
        expect(id.name, 'Ada Lovelace');
        expect(id.email, 'ada@analytical.test');
      } finally {
        await f.dispose();
      }
    });

    test('overwrites a previously set local identity', () async {
      final f = await RepoFixture.empty();
      try {
        final sut = GitIdentityService();
        await sut.setLocal(loc(f), 'First', 'first@x.test');
        await sut.setLocal(loc(f), 'Second', 'second@x.test');
        final id = await sut.readLocal(loc(f));
        expect(id.name, 'Second');
        expect(id.email, 'second@x.test');
      } finally {
        await f.dispose();
      }
    });
  });

  group('GitIdentityService.readEffective', () {
    test('returns the local identity when present', () async {
      final f = await RepoFixture.empty();
      try {
        final sut = GitIdentityService();
        await sut.setLocal(loc(f), 'Local Name', 'local@x.test');
        final id = await sut.readEffective(loc(f));
        expect(id.name, 'Local Name');
        expect(id.email, 'local@x.test');
      } finally {
        await f.dispose();
      }
    });
  });
}
