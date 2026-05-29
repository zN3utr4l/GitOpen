/// Redacts secrets that git and our own code can emit into log lines and the
/// persisted activity log.
///
/// Two things make this necessary:
///   - git over HTTPS echoes the remote URL into progress/error output, and a
///     URL can embed credentials: `https://user:token@host/repo.git`.
///   - auth failures and `extraheader` plumbing can surface `Authorization:`
///     headers and bare provider tokens (`ghp_…`, `gho_…`, `github_pat_…`).
///
/// Anything that lands on disk (`gitopen.log`) or in the SQLite activity log
/// must pass through here first.  The patterns are deliberately conservative:
/// they target well-known secret shapes and never touch ordinary text.
library;

const _redacted = '«redacted»';

final List<(RegExp, String Function(Match))> _rules = [
  // userinfo in a URL: scheme://user:secret@host  → scheme://user:«redacted»@host
  // Also covers the token-only form scheme://token@host.
  (
    RegExp(r'([a-zA-Z][a-zA-Z0-9+.\-]*://)([^/\s:@]+)(:[^/\s@]+)?@'),
    (m) => '${m.group(1)}${m.group(2)}${m.group(3) == null ? '' : ':$_redacted'}@',
  ),
  // Authorization / auth header values (Basic, Bearer, token …).
  (
    RegExp(r'((?:[Aa]uthorization|http\.extraheader)\s*[:=]\s*)\S.*',
        multiLine: false),
    (m) => '${m.group(1)}$_redacted',
  ),
  // Bare provider tokens.
  (
    RegExp(r'\b(gh[posru]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})\b'),
    (_) => _redacted,
  ),
  // x-access-token:<token> form used by some credential helpers.
  (
    RegExp(r'(x-access-token:)\S+'),
    (m) => '${m.group(1)}$_redacted',
  ),
];

/// Returns [input] with any recognised secret material replaced by a
/// placeholder.  Safe to call on null-ish/empty input.
String redactSecrets(String input) {
  if (input.isEmpty) return input;
  var out = input;
  for (final (re, replace) in _rules) {
    out = out.replaceAllMapped(re, replace);
  }
  return out;
}
