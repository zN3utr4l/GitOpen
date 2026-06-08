import 'package:equatable/equatable.dart';

import 'package:gitopen/domain/commits/commit_sha.dart';

final class Branch extends Equatable {

  const Branch({
    required this.name,
    required this.fullName,
    required this.isRemote,
    required this.isCurrent,
    required this.ahead, required this.behind, this.tipSha,
    this.upstreamFullName,
  });
  final String name;
  final String fullName;
  final bool isRemote;
  final bool isCurrent;
  final CommitSha? tipSha;
  final String? upstreamFullName;
  final int ahead;
  final int behind;

  @override
  List<Object?> get props => [
        name,
        fullName,
        isRemote,
        isCurrent,
        tipSha,
        upstreamFullName,
        ahead,
        behind,
      ];
}
