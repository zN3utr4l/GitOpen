/// Why a git operation failed in a way that re-authentication might fix.
enum AuthFailureReason {
  /// The credential was rejected (401/403, "authentication failed", …).
  authRequired,

  /// The host returned "repository not found" — typically the wrong account
  /// is active for a private repo shared across accounts (GitHub answers
  /// 404 rather than 403 to avoid confirming the repo exists).
  wrongAccount,
}

/// Classifies git **stderr** into an [AuthFailureReason], or `null` when the
/// failure is not auth-related.
///
/// Pure: operates on a string, so it is unit-testable without git. Patterns
/// are scoped to phrases git actually emits — loose substrings like `'auth'`
/// are deliberately avoided because the credential helper puts the literal
/// word `Authorization` (from `http.extraheader=Authorization:`) into the
/// argv, which would false-positive. Callers must therefore pass git's
/// stderr, never the full exception string (which embeds the argv).
class AuthFailureClassifier {
  const AuthFailureClassifier();

  AuthFailureReason? classify(String stderr) {
    final lower = stderr.toLowerCase();
    // Auth wins over wrong-account when both could match: a rejected credential
    // is the more actionable diagnosis.
    if (_isAuthError(lower)) return AuthFailureReason.authRequired;
    if (_isWrongAccount(lower)) return AuthFailureReason.wrongAccount;
    return null;
  }

  bool _isAuthError(String lower) =>
      lower.contains('authentication failed') ||
      lower.contains('invalid username or password') ||
      lower.contains('could not read username') ||
      lower.contains('could not read password') ||
      lower.contains('terminal prompts disabled') ||
      lower.contains('http basic: access denied') ||
      lower.contains('remote: invalid credentials') ||
      lower.contains('remote: denied') ||
      lower.contains('permission denied') ||
      lower.contains('error: 401') ||
      lower.contains('error: 403');

  bool _isWrongAccount(String lower) =>
      lower.contains('repository not found') ||
      lower.contains('remote: not found') ||
      lower.contains('error: 404');
}
