class ProcessProbeResult {
  // Positional kept to preserve the existing call sites in
  // SystemProcessRunner; this is a tiny internal result holder.
  // ignore: avoid_positional_boolean_parameters
  const ProcessProbeResult(this.found, this.resolvedPath);
  final bool found;
  final String? resolvedPath;
}

abstract interface class ProcessRunner {
  /// Returns whether [command] resolves on PATH (`where` / `which`).
  Future<ProcessProbeResult> probe(String command);

  /// Starts [executable] with [args] detached. Returns true on successful
  /// spawn, false if the executable could not be started.
  Future<bool> startDetached(String executable, List<String> args);
}
