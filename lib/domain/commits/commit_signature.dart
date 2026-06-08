import 'package:equatable/equatable.dart';

final class CommitSignature extends Equatable {

  const CommitSignature(this.name, this.email, this.when);
  final String name;
  final String email;
  final DateTime when;

  @override
  List<Object?> get props => [name, email, when];
}
