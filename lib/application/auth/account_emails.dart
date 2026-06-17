import 'package:gitopen/application/auth/auth_spec.dart';

/// The GitHub-API-capable bearer token carried by [spec], if any. PATs and
/// OAuth tokens can call the GitHub API; SSH / Basic / system cannot.
String? githubApiToken(AuthSpec spec) => switch (spec) {
      AuthHttpsPat(:final token) => token,
      AuthGitHubOauth(:final accessToken) => accessToken,
      _ => null,
    };

/// Computes the email set to persist for an account when (re)populating.
///
/// Returns the union of [current] and freshly fetched emails when [host] is
/// GitHub and [spec] carries an API token; otherwise returns [current]
/// unchanged — so SSH / Basic accounts keep any manually entered emails.
/// [fetch] (token -> emails) is injected so this stays free of HTTP/IO and
/// keeps the application layer independent of infrastructure.
Future<Set<String>> populatedEmails({
  required String host,
  required AuthSpec spec,
  required Future<Set<String>> Function(String token) fetch,
  Set<String> current = const {},
}) async {
  if (host != 'github.com') return current;
  final token = githubApiToken(spec);
  if (token == null) return current;
  final fetched = await fetch(token);
  return {...current, ...fetched};
}
