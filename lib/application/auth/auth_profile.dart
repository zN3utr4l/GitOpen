import 'package:equatable/equatable.dart';

import 'package:gitopen/application/auth/auth_spec.dart';

/// A saved credential entry: which host it authenticates against, which
/// identity (username) it represents, and the actual auth material.
///
/// Multiple profiles may exist per host (e.g. two GitHub accounts on the
/// same machine).  Each profile carries a stable [id] that workspaces can
/// reference to bind a repository to a specific identity.
final class AuthProfile extends Equatable {

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

  /// Short human label e.g. `github.com / s-porta`.
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
}
