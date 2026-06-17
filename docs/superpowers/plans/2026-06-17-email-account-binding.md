# Identity-based Account Resolution — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Resolve the network auth account for a repo from its effective git `user.email` (already set per-folder via `.gitconfig`), matched against emails auto-populated on each `AuthProfile`.

**Architecture:** Add a normalized `emails` set to `AuthProfile`, persisted in the existing DPAPI store (backward-compatible). `AuthResolver` gains an injected `RepoIdentityReader` port and a new host-scoped email-match step between the explicit per-repo binding and the single-profile-per-host fallback. Emails are auto-populated from the GitHub API (`fetchAccount`) at sign-in and via a "Refresh" action, with manual add/remove as a fallback.

**Tech Stack:** Dart / Flutter, Riverpod providers, `flutter_test`, `http` package, DPAPI-backed secure storage.

## Global Constraints

- **Resolution order:** explicit per-repo binding > email match (host-scoped) > single-profile-per-host > none. A no-match never blocks.
- **Email normalization:** stored and compared as `trim()` + `toLowerCase()`.
- **Backward compatible:** profiles without an `emails` key decode to an empty set. No migration-marker bump. No data loss.
- **Best-effort API:** any GitHub API failure (incl. missing `user:email` scope → 403 on `/user/emails`) degrades silently; never throws into the auth flow.
- **Layering:** application code must not import infrastructure. The email population helper takes an injected `fetch` closure.
- Run tests with `flutter test <path>`; lint with `flutter analyze`.
- Every commit message ends with the `Co-Authored-By` trailer shown in the commit steps.

---

### Task 1: Add `emails` to `AuthProfile`

**Files:**
- Modify: `lib/application/auth/auth_profile.dart`
- Test: `test/application/auth/auth_profile_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `AuthProfile({required id, required host, required username, required spec, Set<String> emails = const {}})`; `final Set<String> emails;`; `copyWith({String? username, AuthSpec? spec, Set<String> emails})`; `emails` added to `props`.

- [ ] **Step 1: Update the failing test**

In `test/application/auth/auth_profile_test.dart`, change the existing props assertion and add new cases inside `group('AuthProfile', ...)`:

```dart
    test('equality is by id/host/username/spec/emails', () {
      const same = AuthProfile(
        id: 'p1',
        host: 'github.com',
        username: 'octocat',
        spec: baseSpec,
      );
      const differentId = AuthProfile(
        id: 'p2',
        host: 'github.com',
        username: 'octocat',
        spec: baseSpec,
      );
      expect(base, same);
      expect(base, isNot(differentId));
      expect(base.props, ['p1', 'github.com', 'octocat', baseSpec, <String>{}]);
    });

    test('profiles differing only by emails are unequal', () {
      const withEmail = AuthProfile(
        id: 'p1',
        host: 'github.com',
        username: 'octocat',
        spec: baseSpec,
        emails: {'octocat@users.noreply.github.com'},
      );
      expect(base, isNot(withEmail));
    });

    test('copyWith overrides emails only, keeping the rest', () {
      final updated = base.copyWith(emails: {'a@x.com'});
      expect(updated.emails, {'a@x.com'});
      expect(updated.id, 'p1');
      expect(updated.username, 'octocat');
      expect(updated.spec, same(baseSpec));
    });
```

Delete the old `test('equality is by id/host/username/spec', ...)` (replaced above).

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/application/auth/auth_profile_test.dart`
Expected: FAIL — `emails` is not a named parameter / `props` length mismatch.

- [ ] **Step 3: Add the field**

In `lib/application/auth/auth_profile.dart`, update the constructor, fields, `copyWith`, and `props`:

```dart
  const AuthProfile({
    required this.id,
    required this.host,
    required this.username,
    required this.spec,
    this.emails = const {},
  });
  final String id;
  final String host;
  final String username;
  final AuthSpec spec;

  /// Normalized (trim + lowercase) emails known to belong to this account.
  /// Used by the resolver to match a repo's effective git user.email to the
  /// right account. Empty for accounts whose emails were never populated
  /// (e.g. SSH, or before the first sign-in/refresh).
  final Set<String> emails;

  String get label => '$host / $username';

  AuthProfile copyWith({
    String? username,
    AuthSpec? spec,
    Set<String>? emails,
  }) {
    return AuthProfile(
      id: id,
      host: host,
      username: username ?? this.username,
      spec: spec ?? this.spec,
      emails: emails ?? this.emails,
    );
  }

  @override
  List<Object?> get props => [id, host, username, spec, emails];
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/application/auth/auth_profile_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/application/auth/auth_profile.dart test/application/auth/auth_profile_test.dart
git commit -m "feat(auth): add emails set to AuthProfile

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Thread `emails` through the profile store

**Files:**
- Modify: `lib/application/auth/auth_profile_store.dart`
- Modify: `lib/infrastructure/auth/secure_auth_profile_store.dart`
- Modify: `test/application/auth/auth_resolver_test.dart` (Fake store signature only — required so the whole test suite keeps compiling)
- Test: `test/infrastructure/auth/secure_auth_profile_store_test.dart`

**Interfaces:**
- Consumes: `AuthProfile.emails` (Task 1).
- Produces: `AuthProfileStore.upsert({required host, required username, required spec, String? id, Set<String> emails = const {}})` persisting emails; `SecureAuthProfileStore` encodes `'emails'` and decodes a missing key to `const {}`.

- [ ] **Step 1: Add the failing store tests**

Append to `test/infrastructure/auth/secure_auth_profile_store_test.dart`, inside `main()`:

```dart
  group('emails', () {
    test('upsert persists and get round-trips the emails set', () async {
      final created = await sut.upsert(
        host: 'github.com',
        username: 'alice',
        spec: const AuthSystemDefault(),
        emails: {'alice@personal.dev', 'alice@users.noreply.github.com'},
      );
      final fetched = await sut.get(created.id);
      expect(fetched!.emails,
          {'alice@personal.dev', 'alice@users.noreply.github.com'});
    });

    test('a profile blob without an emails key decodes to an empty set',
        () async {
      // Simulate a profile written before this feature existed: index entry
      // plus a blob with no "emails" field.
      await storage.write(_profileIndexKey, jsonEncode(['legacy-id']));
      await storage.write(
        '$_profilePrefix' 'legacy-id',
        jsonEncode({
          'host': 'github.com',
          'username': 'alice',
          'spec': {'kind': 'pat', 'username': 'alice', 'token': 'tok'},
        }),
      );
      final fetched = await sut.get('legacy-id');
      expect(fetched!.emails, isEmpty);
    });

    test('persisted blob carries the emails array', () async {
      final created = await sut.upsert(
        host: 'github.com',
        username: 'alice',
        spec: const AuthSystemDefault(),
        emails: {'a@x.com'},
      );
      final blob = storage.snapshot['$_profilePrefix${created.id}']!;
      final json = jsonDecode(blob) as Map<String, dynamic>;
      expect((json['emails'] as List).cast<String>(), ['a@x.com']);
    });
  });
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/infrastructure/auth/secure_auth_profile_store_test.dart`
Expected: FAIL — `emails` is not a named parameter of `upsert`.

- [ ] **Step 3: Extend the interface**

In `lib/application/auth/auth_profile_store.dart`, update `upsert`:

```dart
  /// Create a new profile or overwrite the existing one with the same id.
  /// If [id] is null, a fresh id is generated and returned.
  Future<AuthProfile> upsert({
    required String host,
    required String username,
    required AuthSpec spec,
    String? id,
    Set<String> emails = const {},
  });
```

- [ ] **Step 4: Update the secure store**

In `lib/infrastructure/auth/secure_auth_profile_store.dart`:

Update `upsert` (lines ~70-88):

```dart
  @override
  Future<AuthProfile> upsert({
    required String host,
    required String username,
    required AuthSpec spec,
    String? id,
    Set<String> emails = const {},
  }) async {
    await _ensureMigrated();
    final effectiveId = id ?? _generateId();
    final profile = AuthProfile(
      id: effectiveId,
      host: host,
      username: username,
      spec: spec,
      emails: emails,
    );
    await _storage.write(_profileKey(effectiveId), _encode(profile));
    await _indexAdd(effectiveId);
    return profile;
  }
```

Update `_encode` (line ~192):

```dart
  String _encode(AuthProfile p) {
    return jsonEncode({
      'host': p.host,
      'username': p.username,
      'spec': _encodeSpec(p.spec),
      'emails': p.emails.toList(),
    });
  }
```

Update `_decode` (line ~200):

```dart
  AuthProfile _decode(String id, String raw) {
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return AuthProfile(
      id: id,
      host: m['host'] as String,
      username: m['username'] as String,
      spec: _decodeSpec(m['spec'] as Map<String, dynamic>),
      emails: (m['emails'] as List<dynamic>?)?.cast<String>().toSet() ?? const {},
    );
  }
```

- [ ] **Step 5: Keep the resolver-test Fake compiling**

In `test/application/auth/auth_resolver_test.dart`, update `FakeAuthProfileStore.upsert` to match the new interface signature:

```dart
  @override
  Future<AuthProfile> upsert({
    required String host,
    required String username,
    required AuthSpec spec,
    String? id,
    Set<String> emails = const {},
  }) async {
    final pid = id ?? 'gen-${_byId.length}';
    final profile = AuthProfile(
      id: pid,
      host: host,
      username: username,
      spec: spec,
      emails: emails,
    );
    _byId[pid] = profile;
    return profile;
  }
```

- [ ] **Step 6: Run both test files to verify they pass**

Run: `flutter test test/infrastructure/auth/secure_auth_profile_store_test.dart test/application/auth/auth_resolver_test.dart`
Expected: PASS (all)

- [ ] **Step 7: Commit**

```bash
git add lib/application/auth/auth_profile_store.dart lib/infrastructure/auth/secure_auth_profile_store.dart test/infrastructure/auth/secure_auth_profile_store_test.dart test/application/auth/auth_resolver_test.dart
git commit -m "feat(auth): persist AuthProfile.emails in the secure store

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: GitHub email helpers + `fetchAccount`

**Files:**
- Modify: `lib/infrastructure/auth/github_user_service.dart`
- Test: `test/infrastructure/auth/github_user_service_test.dart` (create)

**Interfaces:**
- Consumes: nothing.
- Produces: top-level `Set<String> githubNoreplyEmails({required int id, required String login})`; top-level `Set<String> accountEmails({int? id, String? login, String? publicEmail, List<String> verified})`; method `Future<({String? login, int? id, Set<String> emails})> GitHubUserService.fetchAccount(String token)`. Existing `fetchLogin` is unchanged.

- [ ] **Step 1: Write the failing test**

Create `test/infrastructure/auth/github_user_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/infrastructure/auth/github_user_service.dart';

void main() {
  group('githubNoreplyEmails', () {
    test('produces modern and legacy forms, lowercased', () {
      expect(
        githubNoreplyEmails(id: 583231, login: 'Octocat'),
        {
          '583231+octocat@users.noreply.github.com',
          'octocat@users.noreply.github.com',
        },
      );
    });
  });

  group('accountEmails', () {
    test('unions public, verified and noreply, all normalized', () {
      final e = accountEmails(
        id: 42,
        login: 'Alice',
        publicEmail: 'Alice@Example.COM ',
        verified: ['alice@work.com', ''],
      );
      expect(e, {
        'alice@example.com',
        'alice@work.com',
        '42+alice@users.noreply.github.com',
        'alice@users.noreply.github.com',
      });
    });

    test('returns empty when nothing is provided', () {
      expect(accountEmails(), isEmpty);
    });

    test('skips noreply forms when id or login is missing', () {
      expect(accountEmails(login: 'alice'), isEmpty);
      expect(accountEmails(id: 1), isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/infrastructure/auth/github_user_service_test.dart`
Expected: FAIL — `githubNoreplyEmails` / `accountEmails` undefined.

- [ ] **Step 3: Implement the helpers and `fetchAccount`**

In `lib/infrastructure/auth/github_user_service.dart`, add the two top-level functions (outside the class) and the `fetchAccount` method (inside the class). Keep the existing `fetchLogin`.

```dart
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
```

Add inside the `GitHubUserService` class:

```dart
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
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/infrastructure/auth/github_user_service_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/infrastructure/auth/github_user_service.dart test/infrastructure/auth/github_user_service_test.dart
git commit -m "feat(auth): fetch account emails from the GitHub API

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: `populatedEmails` application helper

**Files:**
- Create: `lib/application/auth/account_emails.dart`
- Test: `test/application/auth/account_emails_test.dart` (create)

**Interfaces:**
- Consumes: `AuthSpec` subtypes (`lib/application/auth/auth_spec.dart`).
- Produces: top-level `String? githubApiToken(AuthSpec spec)`; top-level `Future<Set<String>> populatedEmails({required String host, required AuthSpec spec, required Future<Set<String>> Function(String token) fetch, Set<String> current = const {}})`.

- [ ] **Step 1: Write the failing test**

Create `test/application/auth/account_emails_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/application/auth/account_emails.dart';
import 'package:gitopen/application/auth/auth_spec.dart';

void main() {
  group('githubApiToken', () {
    test('returns the token for PAT and OAuth, null for the rest', () {
      expect(githubApiToken(const AuthHttpsPat(username: 'a', token: 't')), 't');
      expect(githubApiToken(const AuthGitHubOauth('gho_x')), 'gho_x');
      expect(githubApiToken(const AuthSsh(privateKeyPath: '/k')), isNull);
      expect(
        githubApiToken(const AuthHttpsBasic(username: 'a', password: 'p')),
        isNull,
      );
      expect(githubApiToken(const AuthSystemDefault()), isNull);
    });
  });

  group('populatedEmails', () {
    test('unions current with fetched for a github PAT', () async {
      final result = await populatedEmails(
        host: 'github.com',
        spec: const AuthHttpsPat(username: 'a', token: 't'),
        current: {'old@x.com'},
        fetch: (token) async {
          expect(token, 't');
          return {'new@x.com'};
        },
      );
      expect(result, {'old@x.com', 'new@x.com'});
    });

    test('returns current unchanged for a non-github host without fetching',
        () async {
      var called = false;
      final result = await populatedEmails(
        host: 'gitlab.com',
        spec: const AuthHttpsPat(username: 'a', token: 't'),
        current: {'keep@x.com'},
        fetch: (_) async {
          called = true;
          return {'x@x.com'};
        },
      );
      expect(result, {'keep@x.com'});
      expect(called, isFalse);
    });

    test('returns current unchanged when the spec has no API token', () async {
      final result = await populatedEmails(
        host: 'github.com',
        spec: const AuthSsh(privateKeyPath: '/k'),
        current: {'keep@x.com'},
        fetch: (_) async => {'x@x.com'},
      );
      expect(result, {'keep@x.com'});
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/application/auth/account_emails_test.dart`
Expected: FAIL — `account_emails.dart` / its functions do not exist.

- [ ] **Step 3: Implement the helper**

Create `lib/application/auth/account_emails.dart`:

```dart
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
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/application/auth/account_emails_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/application/auth/account_emails.dart test/application/auth/account_emails_test.dart
git commit -m "feat(auth): add populatedEmails + githubApiToken helpers

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Resolver `RepoIdentityReader` port + email-match step

**Files:**
- Modify: `lib/application/auth/auth_resolver.dart`
- Test: `test/application/auth/auth_resolver_test.dart`

**Interfaces:**
- Consumes: `AuthProfile.emails` (Task 1), `AuthProfileStore.forHost` (existing).
- Produces: `abstract interface class RepoIdentityReader { Future<String?> effectiveEmail(RepoLocation repo); }`; `AuthResolver(... , RepoIdentityReader? identity, ...)`. When `identity` is null the email step is skipped (so existing call sites/tests are unaffected).

- [ ] **Step 1: Add the failing tests**

In `test/application/auth/auth_resolver_test.dart`, add two fakes (top-level, after the existing `FakeAuthProfileStore`) and extend the `resolver()` helper:

```dart
class _FakeRemoteUrl implements RemoteUrlReader {
  _FakeRemoteUrl(this.url);
  final String? url;
  @override
  Future<String?> remoteUrl(RepoLocation repo, String remote) async => url;
}

class _FakeIdentity implements RepoIdentityReader {
  _FakeIdentity(this.email);
  final String? email;
  @override
  Future<String?> effectiveEmail(RepoLocation repo) async => email;
}
```

Replace the existing `resolver(...)` helper with:

```dart
AuthResolver resolver(
  AuthProfileStore store, {
  String? Function(String repoId)? bindingLookup,
  RemoteUrlReader? remoteUrl,
  RepoIdentityReader? identity,
}) =>
    AuthResolver(
      store,
      remoteUrl: remoteUrl ?? GitRemoteUrlReader(),
      bindingLookup: bindingLookup,
      identity: identity,
    );
```

Add a new group inside `main()`:

```dart
  group('AuthResolver identity (email) match', () {
    AuthProfile withEmails(
      String id,
      String host,
      String user,
      Set<String> emails,
    ) =>
        AuthProfile(
          id: id,
          host: host,
          username: user,
          spec: AuthHttpsPat(username: user, token: 'tok-$id'),
          emails: emails,
        );

    test('email match picks the owning profile among several for the host',
        () async {
      final store = FakeAuthProfileStore([
        withEmails('p1', 'github.com', 'alice', {'alice@personal.dev'}),
        withEmails('p2', 'github.com', 'work', {'giuseppe@work.com'}),
      ]);
      final r = resolver(
        store,
        remoteUrl: _FakeRemoteUrl('https://github.com/x/y.git'),
        identity: _FakeIdentity('giuseppe@work.com'),
      );
      final resolved = await r.resolveForRepo(locAt('/any'));
      expect(resolved?.id, 'p2');
    });

    test('match is case-insensitive', () async {
      final store = FakeAuthProfileStore([
        withEmails('p1', 'github.com', 'alice', {'alice@personal.dev'}),
        withEmails('p2', 'github.com', 'work', {'giuseppe@work.com'}),
      ]);
      final r = resolver(
        store,
        remoteUrl: _FakeRemoteUrl('https://github.com/x/y.git'),
        identity: _FakeIdentity('Alice@Personal.DEV'),
      );
      final resolved = await r.resolveForRepo(locAt('/any'));
      expect(resolved?.id, 'p1');
    });

    test('explicit binding wins over an email match', () async {
      final store = FakeAuthProfileStore([
        withEmails('p1', 'github.com', 'alice', {'shared@x.com'}),
        withEmails('p2', 'github.com', 'work', {'shared@x.com'}),
      ]);
      final r = resolver(
        store,
        bindingLookup: (_) => 'p1',
        remoteUrl: _FakeRemoteUrl('https://github.com/x/y.git'),
        identity: _FakeIdentity('shared@x.com'),
      );
      final resolved = await r.resolveForRepo(locAt('/any'));
      expect(resolved?.id, 'p1');
    });

    test('an email matching >1 profile is ambiguous -> falls through to null',
        () async {
      final store = FakeAuthProfileStore([
        withEmails('p1', 'github.com', 'a', {'dup@x.com'}),
        withEmails('p2', 'github.com', 'b', {'dup@x.com'}),
      ]);
      final r = resolver(
        store,
        remoteUrl: _FakeRemoteUrl('https://github.com/x/y.git'),
        identity: _FakeIdentity('dup@x.com'),
      );
      expect(await r.resolveForRepo(locAt('/any')), isNull);
    });

    test('no email match falls back to single-profile-per-host', () async {
      final store = FakeAuthProfileStore([
        withEmails('p1', 'github.com', 'alice', {'alice@personal.dev'}),
      ]);
      final r = resolver(
        store,
        remoteUrl: _FakeRemoteUrl('https://github.com/x/y.git'),
        identity: _FakeIdentity('nobody@nope.com'),
      );
      final resolved = await r.resolveForRepo(locAt('/any'));
      expect(resolved?.id, 'p1');
    });

    test('an unset email skips the identity step', () async {
      final store = FakeAuthProfileStore([
        withEmails('p1', 'github.com', 'a', {'a@x.com'}),
        withEmails('p2', 'github.com', 'b', {'b@x.com'}),
      ]);
      final r = resolver(
        store,
        remoteUrl: _FakeRemoteUrl('https://github.com/x/y.git'),
        identity: _FakeIdentity(null),
      );
      expect(await r.resolveForRepo(locAt('/any')), isNull);
    });

    test('email match is host-scoped', () async {
      final store = FakeAuthProfileStore([
        withEmails('p1', 'github.com', 'alice', {'me@x.com'}),
        withEmails('p2', 'gitlab.com', 'alice', {'me@x.com'}),
      ]);
      final r = resolver(
        store,
        remoteUrl: _FakeRemoteUrl('https://gitlab.com/x/y.git'),
        identity: _FakeIdentity('me@x.com'),
      );
      final resolved = await r.resolveForRepo(locAt('/any'));
      expect(resolved?.id, 'p2');
    });
  });
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/application/auth/auth_resolver_test.dart`
Expected: FAIL — `RepoIdentityReader` undefined / `identity` not a named parameter of `AuthResolver`.

- [ ] **Step 3: Add the port and the email-match step**

In `lib/application/auth/auth_resolver.dart`, add the new interface next to `RemoteUrlReader`:

```dart
/// Reads the effective git `user.email` for a repo (local overrides global),
/// or null when unset. Implemented over GitIdentityService in infrastructure;
/// injected so the resolver itself never spawns processes.
// ignore: one_member_abstracts
abstract interface class RepoIdentityReader {
  Future<String?> effectiveEmail(RepoLocation repo);
}
```

Update the constructor and fields:

```dart
  AuthResolver(
    this._store, {
    required RemoteUrlReader remoteUrl,
    String? Function(String repoId)? bindingLookup,
    RepoIdentityReader? identity,
    LoggerPort? log,
  })  : _remoteUrl = remoteUrl,
        _bindingLookup = bindingLookup ?? ((_) => null),
        _identity = identity,
        _log = log;
  final AuthProfileStore _store;
  final RemoteUrlReader _remoteUrl;
  final String? Function(String repoId) _bindingLookup;
  final RepoIdentityReader? _identity;
  final LoggerPort? _log;
```

Replace the body of `resolveForRepo` (keep the binding block; insert the email step after `candidates` is read, before the single-profile fallback):

```dart
  Future<AuthProfile?> resolveForRepo(
    RepoLocation repo, {
    String remote = 'origin',
  }) async {
    final sw = Stopwatch()..start();
    // 1. Per-repo binding wins.
    final boundId = _bindingLookup(repo.id.value);
    _log?.d('authResolver: bindingLookup=$boundId '
        '(${sw.elapsedMilliseconds}ms)');
    if (boundId != null) {
      final bound = await _store.get(boundId);
      _log?.d('authResolver: store.get done in ${sw.elapsedMilliseconds}ms '
          '(found=${bound != null})');
      if (bound != null) return bound;
    }

    // 2. Resolve the host; everything below is scoped to it.
    final host = await hostFromRepo(repo, remote);
    _log?.d('authResolver: host="$host" (${sw.elapsedMilliseconds}ms)');
    if (host == null) return null;
    final candidates = await _store.forHost(host);
    _log?.d('authResolver: store.forHost done in '
        '${sw.elapsedMilliseconds}ms (candidates=${candidates.length})');

    // 3. Identity (email) match — host-scoped. The repo's effective git
    // user.email (set per-folder via .gitconfig) selects the owning account.
    final identity = _identity;
    if (identity != null) {
      final email = (await identity.effectiveEmail(repo))?.trim().toLowerCase();
      _log?.d('authResolver: effectiveEmail="$email" '
          '(${sw.elapsedMilliseconds}ms)');
      if (email != null && email.isNotEmpty) {
        final matches = candidates
            .where((p) => p.emails.contains(email))
            .toList(growable: false);
        if (matches.length == 1) return matches.first;
      }
    }

    // 4. Implicit single-profile-per-host fallback.
    if (candidates.length == 1) return candidates.first;
    // 5. Multiple profiles & no match → ambiguous; let the caller prompt.
    return null;
  }
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/application/auth/auth_resolver_test.dart`
Expected: PASS (existing binding/host groups + the new identity group)

- [ ] **Step 5: Commit**

```bash
git add lib/application/auth/auth_resolver.dart test/application/auth/auth_resolver_test.dart
git commit -m "feat(auth): resolve account by repo git email

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: `GitRepoIdentityReader` infra + provider wiring

**Files:**
- Create: `lib/infrastructure/git/git_repo_identity_reader.dart`
- Modify: `lib/application/providers.dart`
- Test: `test/infrastructure/git/git_repo_identity_reader_test.dart` (create)

**Interfaces:**
- Consumes: `RepoIdentityReader` (Task 5), `GitIdentityService.readEffective` (existing, returns `({String? name, String? email})`).
- Produces: `GitRepoIdentityReader implements RepoIdentityReader`; `repoIdentityReaderProvider`; `authResolverProvider` now passes `identity:`.

- [ ] **Step 1: Write the failing test**

Create `test/infrastructure/git/git_repo_identity_reader_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gitopen/domain/repositories/repo_id.dart';
import 'package:gitopen/domain/repositories/repo_location.dart';
import 'package:gitopen/infrastructure/git/git_repo_identity_reader.dart';
import '../../_helpers/repo_fixture.dart';

void main() {
  test('returns the repo local user.email', () async {
    final f = await RepoFixture.empty();
    try {
      await Process.run(
        'git',
        ['config', 'user.email', 'me@personal.dev'],
        workingDirectory: f.path,
      );
      final reader = GitRepoIdentityReader();
      final loc = RepoLocation(const RepoId('r'), f.path, 'test');
      expect(await reader.effectiveEmail(loc), 'me@personal.dev');
    } finally {
      await f.dispose();
    }
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/infrastructure/git/git_repo_identity_reader_test.dart`
Expected: FAIL — `git_repo_identity_reader.dart` does not exist.

- [ ] **Step 3: Implement the reader**

Create `lib/infrastructure/git/git_repo_identity_reader.dart`:

```dart
import 'package:gitopen/application/auth/auth_resolver.dart';
import 'package:gitopen/domain/repositories/repo_location.dart';
import 'package:gitopen/infrastructure/git/git_identity_service.dart';

/// [RepoIdentityReader] over [GitIdentityService.readEffective] — returns the
/// effective git user.email (local overrides global) git would use to author a
/// commit in this repo, or null when unset.
class GitRepoIdentityReader implements RepoIdentityReader {
  GitRepoIdentityReader({GitIdentityService? identity})
      : _identity = identity ?? GitIdentityService();
  final GitIdentityService _identity;

  @override
  Future<String?> effectiveEmail(RepoLocation repo) async {
    final id = await _identity.readEffective(repo);
    return id.email;
  }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/infrastructure/git/git_repo_identity_reader_test.dart`
Expected: PASS

- [ ] **Step 5: Wire the provider**

In `lib/application/providers.dart`, add the import near the other infrastructure git imports:

```dart
import 'package:gitopen/infrastructure/git/git_repo_identity_reader.dart';
```

Add the provider immediately before `authResolverProvider`:

```dart
final repoIdentityReaderProvider = Provider<RepoIdentityReader>((ref) {
  return GitRepoIdentityReader(identity: ref.watch(gitIdentityServiceProvider));
});
```

Update `authResolverProvider` to pass it:

```dart
final authResolverProvider = Provider<AuthResolver>((ref) {
  final store = ref.watch(authProfileStoreProvider);
  return AuthResolver(
    store,
    remoteUrl: ref.watch(remoteUrlReaderProvider),
    identity: ref.watch(repoIdentityReaderProvider),
    // Always reads the current binding map from settings — closure runs once
    // per resolve, so the provider does not need to rebuild on settings change.
    bindingLookup: (repoId) =>
        ref.read(appSettingsProvider).authRepoBindings[repoId],
    log: ref.watch(loggerProvider),
  );
});
```

`RepoIdentityReader` is exported from `auth_resolver.dart`, already imported by `providers.dart`. `gitIdentityServiceProvider` already exists in this file.

- [ ] **Step 6: Verify analyze + the full suite**

Run: `flutter analyze`
Expected: No issues.

Run: `flutter test`
Expected: PASS (whole suite — confirms the provider wiring compiles and nothing regressed).

- [ ] **Step 7: Commit**

```bash
git add lib/infrastructure/git/git_repo_identity_reader.dart lib/application/providers.dart test/infrastructure/git/git_repo_identity_reader_test.dart
git commit -m "feat(auth): wire repo identity reader into the resolver

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: Auto-populate emails in the auth dialog

**Files:**
- Modify: `lib/ui/dialogs/auth_dialog.dart`

**Interfaces:**
- Consumes: `populatedEmails` + `githubApiToken` (Task 4), `GitHubUserService.fetchAccount` (Task 3), `AuthProfileStore.upsert(emails:)` (Task 2).
- Produces: no new public API — `_saveProfile` now persists emails.

> **No new unit test.** This task is composition glue: all of its logic lives in
> `populatedEmails` (Task 4) and `fetchAccount` (Task 3), already unit-tested.
> It is verified by `flutter analyze`, the full `flutter test` suite (no
> regressions), and the manual smoke check below.

- [ ] **Step 1: Add the import**

In `lib/ui/dialogs/auth_dialog.dart`, add:

```dart
import 'package:gitopen/application/auth/account_emails.dart';
```

- [ ] **Step 2: Populate emails in `_saveProfile`**

Replace the existing `_saveProfile` method:

```dart
  Future<AuthProfile> _saveProfile({
    required String username,
    required AuthSpec spec,
  }) async {
    final store = ref.read(authProfileStoreProvider);
    final emails = await populatedEmails(
      host: widget.host,
      spec: spec,
      current: widget.editing?.emails ?? const {},
      fetch: (token) async =>
          (await ref.read(gitHubUserServiceProvider).fetchAccount(token)).emails,
    );
    return store.upsert(
      id: widget.editing?.id,
      host: widget.host,
      username: username,
      spec: spec,
      emails: emails,
    );
  }
```

(Both callers already `await _saveProfile(...)`, so making it `async` is safe.)

- [ ] **Step 3: Verify analyze + suite**

Run: `flutter analyze`
Expected: No issues.

Run: `flutter test`
Expected: PASS (whole suite).

- [ ] **Step 4: Manual smoke check**

1. `flutter run -d windows`.
2. Settings → Authentication → Add account → host `github.com` → sign in with a PAT (or GitHub Login).
3. Confirm (via Task 8's UI, or by inspecting the stored profile) that the saved account now carries emails.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/dialogs/auth_dialog.dart
git commit -m "feat(auth): populate account emails on sign-in

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: Settings UI — show emails, manual edit, refresh

**Files:**
- Modify: `lib/ui/settings/sections/authentication_section.dart`

**Interfaces:**
- Consumes: `populatedEmails` (Task 4), `GitHubUserService.fetchAccount` (Task 3), `AuthProfileStore.upsert(emails:)` (Task 2), `AuthProfile.emails` (Task 1).
- Produces: no new public API — adds an "Emails…" affordance to each account row.

> **No new unit test.** Presentational wiring over already-tested logic
> (`populatedEmails`). Verified by `flutter analyze`, the full `flutter test`
> suite, and the manual checklist below. (The repo has no widget-test harness
> for settings sections; adding one is out of scope for this feature.)

- [ ] **Step 1: Add the imports**

In `lib/ui/settings/sections/authentication_section.dart`, add:

```dart
import 'package:gitopen/application/auth/account_emails.dart';
import 'package:gitopen/infrastructure/auth/github_user_service.dart';
```

`_profilesProvider` is already defined and invalidated by the other actions in
this file; reuse it.

- [ ] **Step 2: Show emails and an "Emails…" button on each row**

In `_ProfileRow.build`, add the emails count to the subtitle line and an
"Emails…" button before "Test". Replace the `Expanded(child: Column(...))`
subtitle `Text` with one that appends the email count:

```dart
                Text(
                  '${profile.host} · ${_kindLabel(profile.spec)}'
                  '${profile.emails.isEmpty ? '' : ' · ${profile.emails.length} email(s)'}',
                  style: TextStyle(color: palette.fg2, fontSize: 11.5),
                ),
```

Then add this button into the `Row`'s `children`, immediately before the
`AppButton.secondary(label: 'Test', ...)`:

```dart
          AppButton.secondary(
            label: 'Emails…',
            onPressed: () async {
              await _EmailsDialog.show(context, profile);
              refreshKey.invalidate(_profilesProvider);
            },
          ),
          const SizedBox(width: 6),
```

- [ ] **Step 3: Add the `_EmailsDialog` widget**

Append to `lib/ui/settings/sections/authentication_section.dart`:

```dart
/// Manage the emails associated with an account: list + remove, add by hand,
/// or refresh from the GitHub API. Persists via the store on Save.
class _EmailsDialog extends ConsumerStatefulWidget {
  const _EmailsDialog({required this.profile});
  final AuthProfile profile;

  static Future<void> show(BuildContext context, AuthProfile profile) {
    return showDialog<void>(
      context: context,
      builder: (_) => _EmailsDialog(profile: profile),
    );
  }

  @override
  ConsumerState<_EmailsDialog> createState() => _EmailsDialogState();
}

class _EmailsDialogState extends ConsumerState<_EmailsDialog> {
  late final Set<String> _emails = {...widget.profile.emails};
  final _addCtl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _addCtl.dispose();
    super.dispose();
  }

  void _add() {
    final e = _addCtl.text.trim().toLowerCase();
    if (e.isEmpty) return;
    setState(() {
      _emails.add(e);
      _addCtl.clear();
    });
  }

  Future<void> _refresh() async {
    setState(() => _busy = true);
    final fetched = await populatedEmails(
      host: widget.profile.host,
      spec: widget.profile.spec,
      current: _emails,
      fetch: (token) async =>
          (await ref.read(gitHubUserServiceProvider).fetchAccount(token)).emails,
    );
    if (!mounted) return;
    setState(() {
      _emails
        ..clear()
        ..addAll(fetched);
      _busy = false;
    });
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    await ref.read(authProfileStoreProvider).upsert(
          id: widget.profile.id,
          host: widget.profile.host,
          username: widget.profile.username,
          spec: widget.profile.spec,
          emails: _emails,
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final canRefresh = githubApiToken(widget.profile.spec) != null &&
        widget.profile.host == 'github.com';
    return AppDialog(
      title: 'Emails for ${widget.profile.username}',
      subtitle: 'Used to auto-select this account for repos whose git '
          'user.email matches.',
      width: 460,
      busy: _busy,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_emails.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('No emails yet.',
                  style: TextStyle(color: palette.fg2, fontSize: 12)),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in _emails)
                  Chip(
                    label: Text(e, style: const TextStyle(fontSize: 11.5)),
                    onDeleted: () => setState(() => _emails.remove(e)),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _addCtl,
                  style: TextStyle(color: palette.fg0, fontSize: 13),
                  decoration: appInputDecoration(context, label: 'Add email'),
                  onSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: 8),
              AppButton.secondary(label: 'Add', onPressed: _add),
            ],
          ),
        ],
      ),
      actions: [
        if (canRefresh)
          AppButton.secondary(
            label: 'Refresh from GitHub',
            onPressed: _busy ? null : _refresh,
          ),
        AppButton.secondary(
          label: 'Cancel',
          onPressed: _busy ? null : () => Navigator.pop(context),
        ),
        AppButton.primary(label: 'Save', onPressed: _busy ? null : _save),
      ],
    );
  }
}
```

If `AppDialog` does not accept a `subtitle` parameter in this codebase, drop
that line (the `AccountSwitcherDialog` uses `subtitle:`, so it should exist).

- [ ] **Step 4: Verify analyze + suite**

Run: `flutter analyze`
Expected: No issues.

Run: `flutter test`
Expected: PASS (whole suite).

- [ ] **Step 5: Manual checklist**

1. `flutter run -d windows`.
2. Settings → Authentication: each account row shows the email count.
3. "Emails…" opens the dialog; Add/remove chips work; Save persists (reopen to confirm).
4. For a GitHub PAT/OAuth account, "Refresh from GitHub" repopulates the set.
5. End-to-end: in a repo whose local `git config user.email` matches one
   account's emails (and with two github.com accounts saved), a fetch uses the
   matching account without prompting.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/settings/sections/authentication_section.dart
git commit -m "feat(auth): manage account emails in settings

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage:**
- Data model `emails` on profile → Task 1 (+ store persistence Task 2). ✓
- Resolver `RepoIdentityReader` + email step + order → Task 5; infra reader + wiring → Task 6. ✓
- Auto-population (`fetchAccount`, noreply, `/user/emails` best-effort) → Task 3; population policy → Task 4; sign-in hook → Task 7. ✓
- UI: show emails, manual edit, Refresh → Task 8. ✓
- Edge cases (no match, ambiguous, unset email, SSH, host-scoped) → Task 5 tests. ✓
- Backward compatibility (missing key → empty set) → Task 2 test. ✓
- Non-goals respected (no folder-rule concept, no memoization). ✓

**Placeholder scan:** none — every code/test step carries full code.

**Type consistency:** `populatedEmails`/`githubApiToken` signatures match between Task 4 (definition), Task 7, and Task 8 (use). `fetchAccount` return record `({String? login, int? id, Set<String> emails})` matches between Task 3 and its consumers. `RepoIdentityReader.effectiveEmail` matches between Task 5 (port), Task 6 (impl/fake), and the resolver call site. `upsert(... emails:)` matches across Tasks 2, 7, 8.
