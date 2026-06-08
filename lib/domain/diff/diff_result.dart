import 'package:equatable/equatable.dart';

import 'package:gitopen/domain/diff/file_diff.dart';

final class DiffResult extends Equatable {

  const DiffResult({required this.files});
  final List<FileDiff> files;

  @override
  List<Object?> get props => [files];
}
