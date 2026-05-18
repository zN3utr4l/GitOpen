import 'dart:io';

import '../../domain/repositories/repo_location.dart';
import '../../infrastructure/logging/app_logger.dart';
import '../git/auth_spec.dart';
import 'auth_profile.dart';
import 'auth_profile_store.dart';

/// Resolves which credential a git operation should use for a given repo.
///
/// Priority:
///   1. Explicit per-repo binding (`repoId → profileId`) — what the user
///      picked in the account-switcher.
///   2. Single saved profile for the remote host — implicit default.
///   3. None (caller falls back to system credential helper or prompts).
class AuthResolver {
  final AuthProfileStore _store;
  final String? Function(String repoId) _bindingLookup;

  AuthResolver(
    this._store, {
    String? Function(String repoId)? bindingLookup,
  }) : _bindingLookup = bindingLookup ?? ((_) => null);

  /// Returns the resolved profile (with its [AuthSpec]) for a repo, or null
  /// if no candidate can be picked unambiguously.
  Future<AuthProfile?> resolveForRepo(
    RepoLocation repo, {
    String remote = 'origin',
  }) async {
    final sw = Stopwatch()..start();
    // 1. Per-repo binding wins.
    final boundId = _bindingLookup(repo.id.value);
    appLog.d('authResolver: bindingLookup=$boundId '
        '(${sw.elapsedMilliseconds}ms)');
    if (boundId != null) {
      final bound = await _store.get(boundId);
      appLog.d('authResolver: store.get done in ${sw.elapsedMilliseconds}ms '
          '(found=${bound != null})');
      if (bound != null) return bound;
    }

    // 2. Implicit single-profile-per-host fallback.
    final host = await hostFromRepo(repo, remote);
    appLog.d('authResolver: host="$host" (${sw.elapsedMilliseconds}ms)');
    if (host == null) return null;
    final candidates = await _store.forHost(host);
    appLog.d('authResolver: store.forHost done in '
        '${sw.elapsedMilliseconds}ms (candidates=${candidates.length})');
    if (candidates.length == 1) return candidates.first;
    // Multiple profiles & no binding → ambiguous; let the caller prompt.
    return null;
  }

  /// Convenience: just the host extracted from `origin`'s URL.
  Future<String?> hostFromRepo(
    RepoLocation repo,
    String remote,
  ) async {
    final sw = Stopwatch()..start();
    try {
      appLog.d('hostFromRepo: spawning git remote get-url $remote');
      final result = await Process.run(
        'git',
        ['remote', 'get-url', remote],
        workingDirectory: repo.path,
      );
      appLog.d('hostFromRepo: done in ${sw.elapsedMilliseconds}ms '
          '(exit=${result.exitCode})');
      if (result.exitCode != 0) return null;
      final url = (result.stdout as String).trim();
      final https = RegExp(r'^https?://([^/]+)').firstMatch(url);
      if (https != null) return https.group(1);
      final ssh = RegExp(r'^git@([^:]+):').firstMatch(url);
      if (ssh != null) return ssh.group(1);
    } catch (e) {
      appLog.w('hostFromRepo failed: $e');
    }
    return null;
  }
}
