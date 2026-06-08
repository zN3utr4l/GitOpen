import 'package:equatable/equatable.dart';

enum WorkingFileState {
  unmodified,
  added,
  modified,
  deleted,
  renamed,
  conflicted,
  untracked,
  ignored,
}

final class WorkingFileEntry extends Equatable {

  const WorkingFileEntry({
    required this.path,
    required this.indexState,
    required this.workingTreeState,
    this.oldPath,
  });
  final String path;
  final WorkingFileState indexState;
  final WorkingFileState workingTreeState;
  final String? oldPath;

  @override
  List<Object?> get props => [path, indexState, workingTreeState, oldPath];
}
