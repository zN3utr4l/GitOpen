import 'dart:convert';

import 'package:http/http.dart' as http;

/// The GitHub no-reply email forms for an account — the modern id-prefixed
/// form and the legacy login-only form — normalized to lowercase.
Set<String> githubNoreplyEmails({required int id, required String login}) {
  final l = login.toLowerCase();
  return {
    '$id+$l@users.noreply.github.com',
    '$l@users.noreply.github.com',
  };
}

/// Normalized (trim + lowercase) union of every email signal we can gather
/// for an account: its public email, verified emails, and the computed
/// no-reply forms. Blank entries are dropped.
Set<String> accountEmails({
  int? id,
  String? login,
  String? publicEmail,
  List<String> verified = const [],
}) {
  final out = <String>{};
  void add(String? e) {
    final n = e?.trim().toLowerCase();
    if (n != null && n.isNotEmpty) out.add(n);
  }

  add(publicEmail);
  verified.forEach(add);
  if (id != null && login != null && login.isNotEmpty) {
    out.addAll(githubNoreplyEmails(id: id, login: login));
  }
  return out;
}

/// Looks up the authenticated GitHub user's login from an OAuth token, so the
/// UI does not perform HTTP calls itself.
class GitHubUserService {
  const GitHubUserService();

  /// `GET https://api.github.com/user` with [token]; returns the `login`, or
  /// `null` on any failure (the caller falls back to a sentinel label).
  Future<String?> fetchLogin(String token) async {
    try {
      final r = await http.get(
        Uri.parse('https://api.github.com/user'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
        },
      );
      if (r.statusCode == 200) {
        final m = jsonDecode(r.body) as Map<String, dynamic>;
        final login = m['login'];
        if (login is String && login.isNotEmpty) return login;
      }
    } on Object catch (_) {
      // fall through
    }
    return null;
  }

  /// `GET /user` plus best-effort `GET /user/emails` with [token]; returns the
  /// login, numeric id, and the normalized email set for the account. Any
  /// failure degrades gracefully to whatever was gathered (possibly empty) —
  /// it never throws into the caller's auth flow.
  Future<({String? login, int? id, Set<String> emails})> fetchAccount(
    String token,
  ) async {
    String? login;
    int? id;
    String? publicEmail;
    final verified = <String>[];
    final headers = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
    };
    try {
      final r = await http.get(
        Uri.parse('https://api.github.com/user'),
        headers: headers,
      );
      if (r.statusCode == 200) {
        final m = jsonDecode(r.body) as Map<String, dynamic>;
        if (m['login'] is String) login = m['login'] as String;
        if (m['id'] is int) id = m['id'] as int;
        if (m['email'] is String) publicEmail = m['email'] as String;
      }
    } on Object catch (_) {
      // best-effort
    }
    try {
      final r = await http.get(
        Uri.parse('https://api.github.com/user/emails'),
        headers: headers,
      );
      if (r.statusCode == 200) {
        for (final e in jsonDecode(r.body) as List<dynamic>) {
          if (e is Map && e['email'] is String) {
            verified.add(e['email'] as String);
          }
        }
      }
    } on Object catch (_) {
      // user:email scope may be absent (403) — ignore.
    }
    return (
      login: login,
      id: id,
      emails: accountEmails(
        id: id,
        login: login,
        publicEmail: publicEmail,
        verified: verified,
      ),
    );
  }
}
