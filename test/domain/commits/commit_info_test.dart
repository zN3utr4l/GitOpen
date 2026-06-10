import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/domain/commits/commit_info.dart';
import 'package:gitopen/domain/commits/commit_sha.dart';
import 'package:gitopen/domain/commits/commit_signature.dart';
import 'package:gitopen/domain/commits/gpg_signature_status.dart';

void main() {
  group('CommitInfo', () {
    final author = CommitSignature('Ada', 'ada@x.com', DateTime.utc(2026));
    final committer = CommitSignature(
      'Grace',
      'grace@x.com',
      DateTime.utc(2026, 6),
    );

    CommitInfo build({
      String sha = 'abcdef1',
      List<CommitSha>? parents,
      CommitSignature? authorValue,
      CommitSignature? committerValue,
      String summary = 'Fix bug',
      String message = 'Fix bug\n\nDetails.',
      GpgSignatureStatus signatureStatus = GpgSignatureStatus.unsigned,
    }) {
      return CommitInfo(
        sha: CommitSha(sha),
        parentShas: parents ?? [CommitSha('1111aaa')],
        author: authorValue ?? author,
        committer: committerValue ?? committer,
        summary: summary,
        message: message,
        signatureStatus: signatureStatus,
      );
    }

    test('assigns all fields from constructor', () {
      final info = build();
      expect(info.sha, CommitSha('abcdef1'));
      expect(info.parentShas, [CommitSha('1111aaa')]);
      expect(info.author, author);
      expect(info.committer, committer);
      expect(info.summary, 'Fix bug');
      expect(info.message, 'Fix bug\n\nDetails.');
      expect(info.signatureStatus, GpgSignatureStatus.unsigned);
    });

    test('is equal when all fields match', () {
      expect(build(), build());
      expect(build().hashCode, build().hashCode);
    });

    test('differs by sha', () {
      expect(build(sha: 'aaaa111'), isNot(build(sha: 'bbbb222')));
    });

    test('differs by parentShas', () {
      expect(
        build(parents: [CommitSha('1111aaa')]),
        isNot(build(parents: const [])),
      );
    });

    test('differs by author', () {
      expect(
        build(authorValue: CommitSignature('A', 'a@x', DateTime.utc(2026))),
        isNot(
          build(authorValue: CommitSignature('B', 'b@x', DateTime.utc(2026))),
        ),
      );
    });

    test('differs by committer', () {
      expect(
        build(committerValue: CommitSignature('A', 'a@x', DateTime.utc(2026))),
        isNot(
          build(
            committerValue: CommitSignature('B', 'b@x', DateTime.utc(2026)),
          ),
        ),
      );
    });

    test('differs by summary', () {
      expect(build(summary: 'a'), isNot(build(summary: 'b')));
    });

    test('differs by message', () {
      expect(build(message: 'a'), isNot(build(message: 'b')));
    });

    test('differs by signature status', () {
      expect(
        build(signatureStatus: GpgSignatureStatus.good),
        isNot(build()),
      );
    });
  });
}
