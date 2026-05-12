sealed class GitResult<T> {
  const GitResult();
}

final class GitSuccess<T> extends GitResult<T> {
  final T value;
  const GitSuccess(this.value);
}

final class GitFailure<T> extends GitResult<T> {
  final GitErrorKind kind;
  final String message;
  final String? rawOutput;
  const GitFailure(this.kind, this.message, [this.rawOutput]);
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
