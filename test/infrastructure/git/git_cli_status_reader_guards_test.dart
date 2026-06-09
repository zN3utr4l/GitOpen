import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/domain/repositories/repo_id.dart';
import 'package:gitopen/domain/repositories/repo_location.dart';
import 'package:gitopen/infrastructure/git/git_cli_status_reader.dart';
import 'package:gitopen/infrastructure/git/git_process_runner.dart';

/// Runner returning a canned porcelain-v2 payload, so malformed records can
/// be fed straight into the parser.
class _CannedRunner implements GitProcessRunner {
  _CannedRunner(this.stdout);
  final String stdout;

  @override
  String get executable => 'git';

  @override
  Future<String> run(
    String workingDir,
    List<String> args, {
    Duration? timeout,
  }) async =>
      stdout;

  @override
  Future<String> runWithStdin(
    String workingDir,
    List<String> args,
    String input,
  ) async =>
      stdout;
}

RepoLocation get _repo => const RepoLocation(RepoId('t'), '/tmp/t', 't');

void main() {
  group('GitCliStatusReader malformed-record guards', () {
    test('truncated "1" record is skipped instead of crashing', () async {
      // A well-formed entry has 9+ space-separated fields; this one is cut
      // short (e.g. a corrupt line or future format drift).
      final reader = GitCliStatusReader(_CannedRunner([
        '# branch.head master',
        '1 .M',
        '1 .M N... 100644 100644 100644 abc def ok.txt',
        '',
      ].join('\x00')));
      final status = await reader.getStatus(_repo);
      expect(status.entries, hasLength(1));
      expect(status.entries.single.path, 'ok.txt');
    });

    test('truncated "2" rename record is skipped instead of crashing',
        () async {
      final reader = GitCliStatusReader(_CannedRunner([
        '2 R.',
        '1 .M N... 100644 100644 100644 abc def ok.txt',
        '',
      ].join('\x00')));
      final status = await reader.getStatus(_repo);
      expect(status.entries, hasLength(1));
      expect(status.entries.single.path, 'ok.txt');
    });

    test('truncated "u" unmerged record is skipped instead of crashing',
        () async {
      final reader = GitCliStatusReader(_CannedRunner([
        'u UU',
        '1 .M N... 100644 100644 100644 abc def ok.txt',
        '',
      ].join('\x00')));
      final status = await reader.getStatus(_repo);
      expect(status.entries, hasLength(1));
    });

    test('record with empty XY field is skipped instead of crashing',
        () async {
      // parts[1] exists but is empty -> xy[0] used to throw RangeError.
      final reader = GitCliStatusReader(_CannedRunner(
        '1  N... 100644 100644 100644 abc def weird.txt\x00',
      ));
      final status = await reader.getStatus(_repo);
      expect(status.entries, isEmpty);
    });
  });
}
