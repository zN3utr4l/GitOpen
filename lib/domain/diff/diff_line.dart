import 'package:equatable/equatable.dart';

enum DiffLineKind { context, addition, deletion }

final class DiffLine extends Equatable {

  const DiffLine({
    required this.kind,
    required this.content, this.oldLine,
    this.newLine,
  });
  final DiffLineKind kind;
  final int? oldLine;
  final int? newLine;
  final String content;

  @override
  List<Object?> get props => [kind, oldLine, newLine, content];
}
