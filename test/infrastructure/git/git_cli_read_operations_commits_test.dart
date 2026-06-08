import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/application/git/git_read_operations.dart';
import 'package:gitopen/domain/repositories/repo_id.dart';
import 'package:gitopen/domain/repositories/repo_location.dart';
import 'package:gitopen/infrastructure/git/git_cli_read_operations.dart';
import '../../_helpers/repo_fixture.dart';

void main() {
  RepoLocation loc(RepoFixture f) =>
      RepoLocation(RepoId.newId(), f.path, 'test');

  group('GitCliReadOperations.getCommits', () {
    test('returns all commits in topological order', () async {
      final f = await RepoFixture.withLinearHistory(5);
      try {
        final sut = GitCliReadOperations();
        final commits =
            await sut.getCommits(loc(f), const CommitQuery()).toList();
        expect(commits, hasLength(5));
        expect(commits.first.sha.value, f.headSha);
      } finally {
        await f.dispose();
      }
    });

    test('respects skip and take', () async {
      final f = await RepoFixture.withLinearHistory(10);
      try {
        final sut = GitCliReadOperations();
        final commits = await sut
            .getCommits(loc(f), const CommitQuery(skip: 2, take: 3))
            .toList();
        expect(commits, hasLength(3));
      } finally {
        await f.dispose();
      }
    });

    test('returns empty for empty repo', () async {
      final f = await RepoFixture.empty();
      try {
        final sut = GitCliReadOperations();
        final commits =
            await sut.getCommits(loc(f), const CommitQuery()).toList();
        expect(commits, isEmpty);
      } finally {
        await f.dispose();
      }
    });

    test('parses author and committer signatures', () async {
      final f = await RepoFixture.withLinearHistory(1);
      try {
        final sut = GitCliReadOperations();
        final commits =
            await sut.getCommits(loc(f), const CommitQuery()).toList();
        expect(commits, hasLength(1));
        final c = commits.first;
        expect(c.author.name, 'Test');
        expect(c.author.email, 'test@example.com');
        expect(c.committer.name, 'Test');
      } finally {
        await f.dispose();
      }
    });
  });
}
