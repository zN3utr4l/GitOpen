import 'package:equatable/equatable.dart';

import 'package:gitopen/domain/diff/diff_line.dart';

final class DiffHunk extends Equatable {

  const DiffHunk({
    required this.oldStart,
    required this.oldCount,
    required this.newStart,
    required this.newCount,
    required this.header,
    required this.lines,
  });
  final int oldStart;
  final int oldCount;
  final int newStart;
  final int newCount;
  final String header;
  final List<DiffLine> lines;

  @override
  List<Object?> get props =>
      [oldStart, oldCount, newStart, newCount, header, lines];
}
