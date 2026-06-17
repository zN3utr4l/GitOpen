# Identity-based account resolution ("per-folder" auth)

**Date:** 2026-06-17
**Status:** Approved design, pending implementation plan

## Problem

A user works with two GitHub accounts on the same host (`github.com`) — one for
personal repos, one for work repos — and already maintains a per-folder
`.gitconfig` (via `includeIf "gitdir:"`) that sets the correct
`user.name` / `user.email` per directory tree.

Commit identity is therefore already correct per folder, because GitOpen shells
out to the system `git` inside the repo directory and git resolves config
normally (`git_identity_service.dart`).

Network authentication is **not** derived from `.gitconfig`. GitOpen
authenticates via its own `AuthProfile` system (`credential_helper.dart` injects
an `http.extraheader` and resets `credential.helper=`, bypassing the OS
credential manager). The resolver (`auth_resolver.dart`) picks a profile by:

1. explicit per-repo binding (`authRepoBindings[repoId]`, set via the account
   switcher), then
2. the single-profile-per-host fallback, then
3. nothing (prompt on first auth failure).

With two accounts on the same host, step 2 is ambiguous, so switching is **not**
automatic unless the user has explicitly bound each repo. The user wants the
account to follow the folder automatically.

## Goal

Make the network account follow the folder **without** introducing a new
folder-rule concept. Reuse the per-folder `.gitconfig` the user already
maintains as the source of truth for "which identity": resolve the repo's
effective `user.email`, then match it to the account that owns that email.

```
repo folder
  └─ (.gitconfig includeIf — already the user's)  → effective user.email
        └─ (GitIdentityService.readEffective)      → email
              └─ (AuthResolver: email match)        → AuthProfile.emails
                    └→ AuthSpec → authenticated fetch / push
```

GitOpen only adds the last link: `email → account`.

## Decisions (locked during brainstorming)

- **Model:** inherit from the existing `.gitconfig` (identity-based), not
  explicit folder→account rules.
- **Match key:** the repo's effective `user.email`, matched against emails
  **auto-populated** on the account from the GitHub API; manual edit available
  as a fallback (SSH / no API).
- **Resolution order:** explicit per-repo binding > email match >
  single-profile-per-host > none. The email match is a strong hint, never a
  wall — a no-match never blocks.

## Design

### 1. Data model — `AuthProfile.emails`

Add a field to `AuthProfile` (`lib/application/auth/auth_profile.dart`):

```dart
final Set<String> emails; // normalized: trimmed + lowercased
```

- Include `emails` in `props`, `copyWith`, and the constructor (default `{}`).
- `AuthProfileStore.upsert` (`lib/application/auth/auth_profile_store.dart`)
  gains `Set<String> emails = const {}`.
- `SecureAuthProfileStore` (`lib/infrastructure/auth/secure_auth_profile_store.dart`):
  - `_encode` writes `'emails': emails.toList()`.
  - `_decode` reads `(m['emails'] as List?)?.cast<String>().toSet() ?? {}`.
  - **Backward compatible:** existing profiles lack the key → decode to an empty
    set. No migration-marker bump, no data loss. (The legacy `_migrateLegacy`
    path produces profiles with empty emails, which is correct.)

Emails are **not secret**, but they live alongside the profile record in the
DPAPI blob for simplicity (one record per account, no second source of truth).

### 2. Resolver — `AuthResolver.resolveForRepo`

Add an injected port, twin of the existing `RemoteUrlReader`:

```dart
// lib/application/auth/auth_resolver.dart
abstract interface class RepoIdentityReader {
  /// The effective user.email git would use in this repo (local→global),
  /// or null if unset. Implemented over GitIdentityService in infrastructure;
  /// injected so the resolver never spawns processes.
  Future<String?> effectiveEmail(RepoLocation repo);
}
```

New resolution order (host-scoped to avoid cross-host email collisions):

1. **Explicit per-repo binding** (`_bindingLookup(repo.id.value)` → `store.get`)
   — unchanged, wins.
2. Resolve `host` from the remote URL (`hostFromRepo`). If null → return null
   (no remote → nothing to fetch).
3. **Email match:** read `effectiveEmail(repo)`. If non-null, normalize it
   (trim + lowercase) and, among `store.forHost(host)`, find profiles whose
   `emails` set contains it (the stored emails are already normalized).
   **Exactly one → return it.** Zero or more than one → fall through
   (ambiguous; never guess).
4. **Single profile per host** → return it (existing fallback).
5. Otherwise → null (caller prompts on first auth failure, as today).

The `GitActionsService._runStream` auth-retry loop is unchanged: a no-match
still surfaces as the normal prompt-and-bind flow on the first failure.

### 3. Auto-population — `GitHubUserService`

Extend `lib/infrastructure/auth/github_user_service.dart` (today returns only
`login`):

```dart
Future<({String? login, int? id, Set<String> emails})> fetchAccount(String token);
```

- `GET /user` → `login`, `id`, and `email` (public; may be null).
- Compute the GitHub noreply forms from `id` + `login`:
  - modern: `{id}+{login}@users.noreply.github.com`
  - legacy: `{login}@users.noreply.github.com`
- `GET /user/emails` → verified emails, **best-effort**: on 403 (missing
  `user:email` scope) or any failure, skip silently.
- Return the normalized union. Keep the existing `fetchLogin` (or re-implement
  it in terms of `fetchAccount`) so current call sites stay green.

The noreply computation + response parsing should be a **pure function** so it
is unit-testable without HTTP.

**Hook points** (same places that already call `fetchLogin` to fill `username`):
- `AuthDialog` — PAT / Basic sign-in.
- `DeviceFlowController` — GitHub OAuth.
- A **"Refresh emails"** action on the account row repopulates existing
  profiles (which start with empty `emails` after the data-model change).

### 4. UI — Settings → Authentication

In `lib/ui/settings/sections/authentication_section.dart`, each account row:
- shows the detected emails as chips,
- allows **manual add/remove** of emails (the fallback for SSH or when the API
  is unavailable),
- offers **Refresh emails** to re-pull from the API.

The per-repo manual choice (account switcher) is untouched and remains the
level-1 override.

### 5. Error handling & edge cases

- **No match** → does not block; falls through to host-fallback / prompt.
- **Email matches multiple profiles** → ambiguous, fall through (no guess).
- **Repo `user.email` unset** → skip the email step.
- **SSH remote** → host still extracted (existing regex); email match works,
  emails entered manually (no API token).
- **Identity read cost** → one extra `git config` per resolve; negligible, the
  resolver is already async. Memoization is a non-goal.

## Testing

- `test/application/auth/auth_resolver_test.dart` (extend), with a
  `FakeRepoIdentityReader`:
  - binding beats email match;
  - email match beats single-profile-per-host;
  - no match falls through to host fallback / null;
  - ambiguous email (matches >1) falls through;
  - case-insensitive match;
  - unset email skips the step;
  - email match is host-scoped (same email on another host does not match).
- `test/infrastructure/auth/secure_auth_profile_store_test.dart` (extend):
  - round-trip `emails`;
  - decode a legacy profile JSON without the `emails` key → empty set.
- New pure unit test for noreply computation + `fetchAccount` response parsing.

## Non-goals

- Explicit folder→account rules (rejected in favor of `.gitconfig`).
- Identity-read memoization / caching.
- Cross-host sync of the same email.
- Changing the commit-identity path (already correct via system git).
