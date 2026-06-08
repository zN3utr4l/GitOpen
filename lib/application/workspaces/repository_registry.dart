import 'package:gitopen/domain/repositories/repo_id.dart';
import 'package:gitopen/domain/repositories/repo_location.dart';

abstract interface class RepositoryRegistry {
  Future<RepoLocation> add(String path);
  Future<List<RepoLocation>> list();
  Future<RepoLocation?> getByPath(String path);
  Future<void> remove(RepoId id);
  Future<void> touchLastOpened(RepoId id);
}
