import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/domain/commits/commit_sha.dart';
import 'package:gitopen/domain/diff/diff_spec.dart';

void main() {
  group('DiffSpecCommitVsParent', () {
    test('assigns commitSha and compares by value', () {
      final spec = DiffSpecCommitVsParent(CommitSha('abcdef1'));
      expect(spec.commitSha, CommitSha('abcdef1'));
      expect(
        DiffSpecCommitVsParent(CommitSha('abcdef1')),
        DiffSpecCommitVsParent(CommitSha('abcdef1')),
      );
      expect(
        DiffSpecCommitVsParent(CommitSha('aaaa111')),
        isNot(DiffSpecCommitVsParent(CommitSha('bbbb222'))),
      );
    });
  });

  group('DiffSpecCommitVsCommit', () {
    test('assigns from and to', () {
      final spec = DiffSpecCommitVsCommit(
        CommitSha('aaaa111'),
        CommitSha('bbbb222'),
      );
      expect(spec.from, CommitSha('aaaa111'));
      expect(spec.to, CommitSha('bbbb222'));
    });

    test('is equal when from and to match', () {
      expect(
        DiffSpecCommitVsCommit(CommitSha('aaaa111'), CommitSha('bbbb222')),
        DiffSpecCommitVsCommit(CommitSha('aaaa111'), CommitSha('bbbb222')),
      );
    });

    test('differs by from', () {
      expect(
        DiffSpecCommitVsCommit(CommitSha('aaaa111'), CommitSha('cccc333')),
        isNot(
          DiffSpecCommitVsCommit(CommitSha('bbbb222'), CommitSha('cccc333')),
        ),
      );
    });

    test('differs by to', () {
      expect(
        DiffSpecCommitVsCommit(CommitSha('aaaa111'), CommitSha('bbbb222')),
        isNot(
          DiffSpecCommitVsCommit(CommitSha('aaaa111'), CommitSha('cccc333')),
        ),
      );
    });
  });

  group('DiffSpecIndexVsHead', () {
    test('instances are equal with empty props', () {
      expect(const DiffSpecIndexVsHead(), const DiffSpecIndexVsHead());
      expect(const DiffSpecIndexVsHead().props, isEmpty);
    });
  });

  group('DiffSpecWorkingTreeVsIndex', () {
    test('instances are equal with empty props', () {
      expect(
        const DiffSpecWorkingTreeVsIndex(),
        const DiffSpecWorkingTreeVsIndex(),
      );
      expect(const DiffSpecWorkingTreeVsIndex().props, isEmpty);
    });
  });

  group('DiffSpec variants', () {
    test('different variants are not equal', () {
      expect(
        const DiffSpecIndexVsHead(),
        isNot(const DiffSpecWorkingTreeVsIndex()),
      );
    });

    test('is a sealed DiffSpec', () {
      const DiffSpec spec = DiffSpecIndexVsHead();
      expect(spec, isA<DiffSpec>());
    });
  });
}
