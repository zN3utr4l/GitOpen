import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/domain/commits/commit_sha.dart';
import 'package:gitopen/domain/status/repo_status.dart';
import 'package:gitopen/domain/status/working_file_entry.dart';

void main() {
  group('RepoStatus', () {
    const entry = WorkingFileEntry(
      path: 'lib/main.dart',
      indexState: WorkingFileState.modified,
      workingTreeState: WorkingFileState.unmodified,
    );

    RepoStatus build({
      String? currentBranch = 'main',
      String? headShaValue = 'abcdef1',
      bool isDetached = false,
      bool isBare = false,
      List<WorkingFileEntry> entries = const [entry],
      int ahead = 1,
      int behind = 2,
    }) {
      return RepoStatus(
        currentBranch: currentBranch,
        headSha: headShaValue == null ? null : CommitSha(headShaValue),
        isDetached: isDetached,
        isBare: isBare,
        entries: entries,
        ahead: ahead,
        behind: behind,
      );
    }

    test('assigns all fields from constructor', () {
      final status = build();
      expect(status.currentBranch, 'main');
      expect(status.headSha, CommitSha('abcdef1'));
      expect(status.isDetached, isFalse);
      expect(status.isBare, isFalse);
      expect(status.entries, [entry]);
      expect(status.ahead, 1);
      expect(status.behind, 2);
    });

    test('ahead and behind default to zero', () {
      const status = RepoStatus(
        isDetached: false,
        isBare: false,
        entries: [],
      );
      expect(status.ahead, 0);
      expect(status.behind, 0);
    });

    test('allows null currentBranch and headSha', () {
      final status = build(currentBranch: null, headShaValue: null);
      expect(status.currentBranch, isNull);
      expect(status.headSha, isNull);
    });

    test('is equal when all fields match', () {
      expect(build(), build());
      expect(build().hashCode, build().hashCode);
    });

    test('differs by currentBranch', () {
      expect(
        build(),
        isNot(build(currentBranch: 'dev')),
      );
    });

    test('differs by headSha', () {
      expect(
        build(headShaValue: 'aaaa111'),
        isNot(build(headShaValue: 'bbbb222')),
      );
    });

    test('differs by isDetached', () {
      expect(build(), isNot(build(isDetached: true)));
    });

    test('differs by isBare', () {
      expect(build(), isNot(build(isBare: true)));
    });

    test('differs by entries', () {
      expect(build(), isNot(build(entries: const [])));
    });

    test('differs by ahead', () {
      expect(build(), isNot(build(ahead: 2)));
    });

    test('differs by behind', () {
      expect(build(behind: 1), isNot(build()));
    });
  });
}
