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
