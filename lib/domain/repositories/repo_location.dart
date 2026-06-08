import 'package:equatable/equatable.dart';

import 'package:gitopen/domain/repositories/repo_id.dart';

final class RepoLocation extends Equatable {

  const RepoLocation(this.id, this.path, this.displayName);
  final RepoId id;
  final String path;
  final String displayName;

  @override
  List<Object?> get props => [id, path, displayName];
}
