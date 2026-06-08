import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/domain/commits/commit_sha.dart';
import 'package:gitopen/domain/refs/branch.dart';

void main() {
  group('Branch', () {
    Branch build({
      String name = 'main',
      String fullName = 'refs/heads/main',
      bool isRemote = false,
      bool isCurrent = true,
      int ahead = 0,
      int behind = 0,
      CommitSha? tipSha,
      String? upstreamFullName = 'refs/remotes/origin/main',
    }) {
      return Branch(
        name: name,
        fullName: fullName,
        isRemote: isRemote,
        isCurrent: isCurrent,
        ahead: ahead,
        behind: behind,
        tipSha: tipSha,
        upstreamFullName: upstreamFullName,
      );
    }

    test('assigns all fields from constructor', () {
      final tip = CommitSha('abcdef1');
      final branch = Branch(
        name: 'feature',
        fullName: 'refs/heads/feature',
        isRemote: false,
        isCurrent: true,
        ahead: 2,
        behind: 1,
        tipSha: tip,
        upstreamFullName: 'refs/remotes/origin/feature',
      );

      expect(branch.name, 'feature');
      expect(branch.fullName, 'refs/heads/feature');
      expect(branch.isRemote, isFalse);
      expect(branch.isCurrent, isTrue);
      expect(branch.ahead, 2);
      expect(branch.behind, 1);
      expect(branch.tipSha, tip);
      expect(branch.upstreamFullName, 'refs/remotes/origin/feature');
    });

    test('allows null optional fields', () {
      const branch = Branch(
        name: 'main',
        fullName: 'refs/heads/main',
        isRemote: false,
        isCurrent: true,
        ahead: 0,
        behind: 0,
      );

      expect(branch.tipSha, isNull);
      expect(branch.upstreamFullName, isNull);
    });

    test('is equal when all fields match', () {
      expect(build(tipSha: CommitSha('abcd123')),
          build(tipSha: CommitSha('abcd123')));
      expect(build(tipSha: CommitSha('abcd123')).hashCode,
          build(tipSha: CommitSha('abcd123')).hashCode);
    });

    test('differs by name', () {
      expect(build(name: 'a'), isNot(build(name: 'b')));
    });

    test('differs by fullName', () {
      expect(
        build(fullName: 'refs/heads/a'),
        isNot(build(fullName: 'refs/heads/b')),
      );
    });

    test('differs by isRemote', () {
      expect(build(), isNot(build(isRemote: true)));
    });

    test('differs by isCurrent', () {
      expect(build(), isNot(build(isCurrent: false)));
    });

    test('differs by tipSha', () {
      expect(
        build(tipSha: CommitSha('aaaa111')),
        isNot(build(tipSha: CommitSha('bbbb222'))),
      );
    });

    test('differs by upstreamFullName', () {
      expect(
        build(upstreamFullName: 'a'),
        isNot(build(upstreamFullName: 'b')),
      );
    });

    test('differs by ahead', () {
      expect(build(ahead: 1), isNot(build(ahead: 2)));
    });

    test('differs by behind', () {
      expect(build(behind: 1), isNot(build(behind: 2)));
    });
  });
}
