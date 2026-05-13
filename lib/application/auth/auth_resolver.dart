import 'dart:io';

import '../../domain/repositories/repo_location.dart';
import '../git/auth_spec.dart';
import 'credentials_store.dart';

/// Looks up a stored credential for a repo's remote, so push / fetch / pull
/// can use an in-app-selected account instead of falling back to a system
/// credential helper (e.g. Git Credential Manager on Windows).
///
/// Returns null if no credential is stored for the host (caller should then
/// let git use its usual flow).
class AuthResolver {
  final CredentialsStore _store;
  AuthResolver(this._store);

  Future<AuthSpec?> resolveForRepo(RepoLocation repo,
      {String remote = 'origin'}) async {
    final host = await _hostFromRepo(repo, remote);
    if (host == null) return null;
    return _store.get(host);
  }

  Future<String?> _hostFromRepo(RepoLocation repo, String remote) async {
    try {
      final result = await Process.run(
        'git',
        ['remote', 'get-url', remote],
        workingDirectory: repo.path,
      );
      if (result.exitCode != 0) return null;
      final url = (result.stdout as String).trim();
      // https://hostname/...
      final https = RegExp(r'^https?://([^/]+)').firstMatch(url);
      if (https != null) return https.group(1);
      // git@hostname:...
      final ssh = RegExp(r'^git@([^:]+):').firstMatch(url);
      if (ssh != null) return ssh.group(1);
    } catch (_) {}
    return null;
  }
}
