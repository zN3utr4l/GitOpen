import 'package:gitopen/application/auth/auth_profile.dart';
import 'package:gitopen/application/git/auth_failure_classifier.dart';
import 'package:gitopen/application/git/auth_spec.dart';
import 'package:gitopen/application/git/git_action_ports.dart';
import 'package:gitopen/application/git/git_progress.dart';
import 'package:gitopen/application/git/git_result.dart';
import 'package:gitopen/application/git/git_write_operations.dart';
import 'package:gitopen/application/git/merge_outcome.dart';
import 'package:gitopen/application/operations/running_operation.dart';
import 'package:gitopen/domain/commits/commit_sha.dart';
import 'package:gitopen/domain/repositories/repo_location.dart';

/// How an action finished, from the caller's point of view.
enum ActionOutcome {
  /// The operation completed cleanly.
  success,

  /// The operation paused on a conflict the user must resolve.
  conflict,

  /// The operation could not complete (already surfaced to the user via the
  /// progress sink / a message).
  failed,
}

/// Which cached repo data an action invalidated, so the UI adapter can refresh
/// exactly the right providers (kept declarative to keep the service pure).
enum RepoDataScope {
  /// The read-ops cache (`gitReadOperationsProvider`) — commits, refs, status…
  reads,

  /// The in-progress-op detection (`repoStateProvider`) — merge/rebase state.
  repoState,
}

/// Severity of a user-facing message attached to an [ActionResult].
enum MessageSeverity {
  /// Neutral information.
  info,

  /// A successful outcome worth confirming.
  success,

  /// An error the user should notice.
  error,
}

/// The declarative result of a git action: what happened, what to invalidate,
/// and an optional message for the UI adapter to surface.
final class ActionResult {
  const ActionResult(
    this.outcome, {
    this.invalidate = const {},
    this.message,
    this.severity,
  });

  /// Convenience for a clean success that invalidated the read cache.
  const ActionResult.reads(this.outcome)
      : invalidate = const {RepoDataScope.reads},
        message = null,
        severity = null;

  /// What happened.
  final ActionOutcome outcome;

  /// Repo data the action changed; the UI adapter invalidates the mapped
  /// providers.
  final Set<RepoDataScope> invalidate;

  /// Optional user-facing message (the adapter shows it as a snackbar).
  final String? message;

  /// Severity of [message], when present.
  final MessageSeverity? severity;
}

/// Pure application-layer orchestrator for git actions.
///
/// Owns the sequencing every UI call site used to duplicate: drive the op
/// through a [ProgressSink], classify failures, run the auth-retry loop via an
/// [AuthPrompt], and hand back a declarative [ActionResult] (what to invalidate
/// + any message). It depends only on the application interfaces and injected
/// ports — no Flutter, no `dart:io`, no infrastructure — so it is unit-testable
/// with fakes. The composition root injects `errorText` (the only code that
/// knows how to read git's stderr off a thrown infrastructure exception).
final class GitActionsService {
  GitActionsService({
    required GitWriteOperations write,
    required Future<AuthProfile?> Function(RepoLocation repo) resolveProfile,
    required String Function(Object error) errorText,
    AuthFailureClassifier classifier = const AuthFailureClassifier(),
    LoggerPort? log,
  })  : _write = write,
        _resolveProfile = resolveProfile,
        _errorText = errorText,
        _classifier = classifier,
        _log = log;

  final GitWriteOperations _write;
  final Future<AuthProfile?> Function(RepoLocation repo) _resolveProfile;
  final String Function(Object error) _errorText;
  final AuthFailureClassifier _classifier;
  final LoggerPort? _log;

  /// `git fetch` with progress + auth-retry.
  Future<ActionResult> fetch(
    RepoLocation repo, {
    required AuthPrompt prompt,
    required ProgressSink progress,
  }) {
    return _runStream(
      OpKind.fetch,
      'Fetching origin',
      repo,
      (auth) => _write.fetch(repo, auth: auth),
      prompt: prompt,
      progress: progress,
    );
  }

  /// `git pull` (with the caller-chosen [strategy]) with progress + auth-retry.
  Future<ActionResult> pull(
    RepoLocation repo,
    PullStrategy strategy, {
    required AuthPrompt prompt,
    required ProgressSink progress,
  }) {
    return _runStream(
      OpKind.pull,
      'Pulling',
      repo,
      (auth) => _write.pull(repo, strategy, auth: auth),
      prompt: prompt,
      progress: progress,
    );
  }

  /// `git push` with progress + auth-retry.
  Future<ActionResult> push(
    RepoLocation repo, {
    required AuthPrompt prompt,
    required ProgressSink progress,
  }) {
    return _runStream(
      OpKind.push,
      'Pushing',
      repo,
      (auth) => _write.push(repo, auth: auth),
      prompt: prompt,
      progress: progress,
    );
  }

  // ---- Local (non-streaming) actions ------------------------------------
  // No auth / progress streaming; each maps the write op's GitResult to a
  // declarative ActionResult. Conflict-bearing ops report
  // ActionOutcome.conflict so the UI surfaces the conflicts panel.

  /// Invalidation set for local actions: refresh reads + in-progress state.
  static const Set<RepoDataScope> _localScope = {
    RepoDataScope.reads,
    RepoDataScope.repoState,
  };

  /// `git merge <ref>` with the given [strategy].
  Future<ActionResult> merge(
    RepoLocation repo,
    String ref,
    MergeStrategy strategy,
  ) async =>
      _conflictable(
        await _write.merge(repo, ref, strategy: strategy),
        'Merge',
        (o) => o is MergeConflict ? o.conflictedPaths : null,
      );

  /// `git rebase <upstream>`.
  Future<ActionResult> rebase(RepoLocation repo, String upstream) async =>
      _conflictable(
        await _write.rebase(repo, upstream),
        'Rebase',
        (o) => o is RebaseConflict ? o.conflictedPaths : null,
      );

  /// `git cherry-pick <sha>`.
  Future<ActionResult> cherryPick(RepoLocation repo, CommitSha sha) async =>
      _conflictable(
        await _write.cherryPick(repo, sha),
        'Cherry-pick',
        (o) => o is CherryPickConflict ? o.conflictedPaths : null,
      );

  /// `git revert <sha>`.
  Future<ActionResult> revert(RepoLocation repo, CommitSha sha) async =>
      _conflictable(
        await _write.revert(repo, sha),
        'Revert',
        (o) => o is RevertConflict ? o.conflictedPaths : null,
      );

  /// `git reset --<mode>` to [to].
  Future<ActionResult> reset(
    RepoLocation repo,
    CommitSha to,
    ResetMode mode,
  ) async {
    final result = await _write.reset(repo, to, mode);
    return switch (result) {
      GitSuccess() =>
        const ActionResult(ActionOutcome.success, invalidate: _localScope),
      GitFailure(:final message) => ActionResult(
          ActionOutcome.failed,
          invalidate: _localScope,
          message: 'Reset failed: $message',
          severity: MessageSeverity.error,
        ),
    };
  }

  /// Maps a conflict-bearing write result to an [ActionResult]: success,
  /// conflict (with a count message), or failure. [conflictPaths] returns the
  /// conflicted paths when the success-outcome is a conflict, else null.
  ActionResult _conflictable<T>(
    GitResult<T> result,
    String label,
    List<String>? Function(T outcome) conflictPaths,
  ) {
    switch (result) {
      case GitSuccess(:final value):
        final paths = conflictPaths(value);
        if (paths == null) {
          return const ActionResult(
            ActionOutcome.success,
            invalidate: _localScope,
          );
        }
        return ActionResult(
          ActionOutcome.conflict,
          invalidate: _localScope,
          message: '$label conflict in ${paths.length} file(s). '
              'Resolve in the conflicts panel below.',
          severity: MessageSeverity.error,
        );
      case GitFailure(:final message):
        return ActionResult(
          ActionOutcome.failed,
          invalidate: _localScope,
          message: '$label failed: $message',
          severity: MessageSeverity.error,
        );
    }
  }

  /// Drives a streaming git op through [progress], and on an auth-style failure
  /// prompts for an account and retries with the chosen credential. The user
  /// cancelling the prompt ends the loop; a non-auth failure ends it too.
  Future<ActionResult> _runStream(
    OpKind kind,
    String label,
    RepoLocation repo,
    Stream<GitProgress> Function(AuthSpec? auth) streamFactory, {
    required AuthPrompt prompt,
    required ProgressSink progress,
    AuthProfile? profile,
    bool profileResolved = false,
  }) async {
    final id = progress.start(kind, label, repo: repo);
    final resolved =
        profileResolved ? profile : await _resolveProfile(repo);
    try {
      await for (final ev in streamFactory(resolved?.spec)) {
        progress.progress(id, ev.fraction, ev.phase);
      }
      progress.success(id);
      return const ActionResult.reads(ActionOutcome.success);
    } on Object catch (e) {
      // Classify ONLY git's stderr (via the injected extractor) — never the
      // full exception string, which embeds the argv and would false-positive.
      final reason = _classifier.classify(_errorText(e));
      if (reason != null) {
        progress.failure(
          id,
          reason == AuthFailureReason.wrongAccount
              ? 'Repository not visible to current account'
              : 'Authentication required',
        );
        final chosen = await prompt.forAccount(repo, reason);
        if (chosen == null) return const ActionResult(ActionOutcome.failed);
        return _runStream(
          kind,
          label,
          repo,
          streamFactory,
          prompt: prompt,
          progress: progress,
          profile: chosen,
          profileResolved: true,
        );
      }
      _log?.w('git $label failed: $e');
      progress.failure(id, e.toString());
      return const ActionResult(ActionOutcome.failed);
    }
  }
}
