sealed class GitResult<T> {
  const GitResult();
}

final class GitSuccess<T> extends GitResult<T> {
  const GitSuccess(this.value);
  final T value;
}

final class GitFailure<T> extends GitResult<T> {
  const GitFailure(this.kind, this.message, [this.rawOutput]);
  final GitErrorKind kind;
  final String message;
  final String? rawOutput;
}

enum GitErrorKind {
  network,
  auth,
  conflict,
  nonFastForward,
  dirtyWorkingTree,
  unknownRef,
  invalidArgument,
  other,
}
