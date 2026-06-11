import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/application/git/git_write_operations.dart';
import 'package:gitopen/application/git/rebase_plan.dart';
import 'package:gitopen/domain/commits/commit_sha.dart';

RebaseTodoEntry e(String sha, RebaseTodoAction a, [String? msg]) =>
    RebaseTodoEntry(CommitSha(sha * 8), a, message: msg);

void main() {
  group('validateRebasePlan', () {
    test('null for a plain pick plan', () {
      expect(
        validateRebasePlan([
          e('a', RebaseTodoAction.pick),
          e('b', RebaseTodoAction.squash),
        ]),
        isNull,
      );
    });

    test('rejects an empty plan and an all-drop plan', () {
      expect(validateRebasePlan(const []), isNotNull);
      expect(
        validateRebasePlan([e('a', RebaseTodoAction.drop)]),
        isNotNull,
      );
    });

    test('rejects squash/fixup as the first kept commit', () {
      expect(
        validateRebasePlan([
          e('a', RebaseTodoAction.squash),
          e('b', RebaseTodoAction.pick),
        ]),
        contains('fold'),
      );
      expect(
        validateRebasePlan([
          e('a', RebaseTodoAction.drop),
          e('b', RebaseTodoAction.fixup),
        ]),
        contains('fold'),
      );
    });
  });

  group('plannedEditorMessages', () {
    test('no editor stops for pick/fixup/drop-only plans', () {
      expect(
        plannedEditorMessages([
          e('a', RebaseTodoAction.pick),
          e('b', RebaseTodoAction.fixup),
          e('c', RebaseTodoAction.drop),
        ]),
        isEmpty,
      );
    });

    test('one stop per reword, in todo order', () {
      expect(
        plannedEditorMessages([
          e('a', RebaseTodoAction.reword, 'new a'),
          e('b', RebaseTodoAction.pick),
          e('c', RebaseTodoAction.reword), // keep original
        ]),
        equals(['new a', null]),
      );
    });

    test('one stop per fold group containing a squash', () {
      expect(
        plannedEditorMessages([
          e('a', RebaseTodoAction.pick),
          e('b', RebaseTodoAction.squash, 'combined'),
          e('c', RebaseTodoAction.fixup),
          e('d', RebaseTodoAction.pick),
          e('f', RebaseTodoAction.fixup), // fixup-only group: no stop
        ]),
        equals(['combined']),
      );
    });

    test('a drop splits a fold run into two groups', () {
      expect(
        plannedEditorMessages([
          e('a', RebaseTodoAction.pick),
          e('b', RebaseTodoAction.squash, 'first'),
          e('c', RebaseTodoAction.drop),
          e('d', RebaseTodoAction.squash, 'second'),
        ]),
        equals(['first', 'second']),
      );
    });

    test('reword closes a pending fold group before its own stop', () {
      expect(
        plannedEditorMessages([
          e('a', RebaseTodoAction.pick),
          e('b', RebaseTodoAction.squash), // default combined message
          e('c', RebaseTodoAction.reword, 'r'),
        ]),
        equals([null, 'r']),
      );
    });

    test('last non-null squash message in a group wins', () {
      expect(
        plannedEditorMessages([
          e('a', RebaseTodoAction.pick),
          e('b', RebaseTodoAction.squash, 'one'),
          e('c', RebaseTodoAction.squash, 'two'),
        ]),
        equals(['two']),
      );
    });
  });
}
