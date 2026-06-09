import 'package:gitopen/application/auth/auth_profile.dart';
import 'package:gitopen/application/git/auth_failure_classifier.dart';
import 'package:gitopen/application/git/auth_spec.dart';
import 'package:gitopen/application/git/git_action_ports.dart';
import 'package:gitopen/application/git/git_progress.dart';
import 'package:gitopen/application/git/git_write_operations.dart';
import 'package:gitopen/application/operations/running_operation.dart';
import 'package:gitopen/domain/repositories/repo_location.dart';

/// How an action finished, from the caller's point of view.
enum ActionOutcome {
  /// The operation completed cleanly.
  success,

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
