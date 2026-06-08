import 'package:equatable/equatable.dart';

import 'package:gitopen/domain/refs/branch.dart';

final class Remote extends Equatable {

  const Remote({
    required this.name,
    required this.url,
    required this.branches,
  });
  final String name;
  final String url;
  final List<Branch> branches;

  @override
  List<Object?> get props => [name, url, branches];
}
