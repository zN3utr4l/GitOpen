import 'package:gitopen/application/git/git_write_operations.dart';

/// Pre-flight check for an interactive-rebase plan (entries OLDEST-FIRST).
/// Returns a user-facing error, or `null` when the plan can run.
String? validateRebasePlan(List<RebaseTodoEntry> plan) {
  final kept = plan.where((p) => p.action != RebaseTodoAction.drop).toList();
  if (kept.isEmpty) return 'The plan must keep at least one commit.';
  final first = kept.first.action;
  if (first == RebaseTodoAction.squash || first == RebaseTodoAction.fixup) {
    return 'The first kept commit cannot fold (squash/fixup) — there is no '
        'previous commit to fold into.';
  }
  return null;
}

/// The ordered commit-message editor stops git will raise for [plan]
/// (entries OLDEST-FIRST). One stop per `reword`; one stop per maximal run
/// of consecutive squash/fixup commands that contains at least one
/// `squash` (git opens the editor once, at the end of the run). Any other
/// command — including `drop` — ends a run. `null` keeps the message git
/// proposes at that stop.
List<String?> plannedEditorMessages(List<RebaseTodoEntry> plan) {
  final stops = <String?>[];
  String? groupMessage;
  var groupHasSquash = false;
  var inGroup = false;

  void closeGroup() {
    if (inGroup && groupHasSquash) stops.add(groupMessage);
    inGroup = false;
    groupHasSquash = false;
    groupMessage = null;
  }

  for (final entry in plan) {
    switch (entry.action) {
      case RebaseTodoAction.squash:
        inGroup = true;
        groupHasSquash = true;
        if (entry.message != null) groupMessage = entry.message;
      case RebaseTodoAction.fixup:
        inGroup = true;
      case RebaseTodoAction.reword:
        closeGroup();
        stops.add(entry.message);
      case RebaseTodoAction.pick:
      case RebaseTodoAction.drop:
        closeGroup();
    }
  }
  closeGroup();
  return stops;
}
