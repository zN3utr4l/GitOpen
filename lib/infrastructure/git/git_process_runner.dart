import 'dart:async';
import 'dart:convert';
import 'dart:io';

final class GitProcessException implements Exception {
  final List<String> args;
  final int exitCode;
  final String stderr;
  GitProcessException(this.args, this.exitCode, this.stderr);
  @override
  String toString() => 'git ${args.join(' ')} failed ($exitCode): $stderr';
}

class GitProcessRunner {
  final String executable;
  GitProcessRunner({this.executable = 'git'});

  Future<String> run(String workingDir, List<String> args) async {
    final result = await Process.run(
      executable,
      args,
      workingDirectory: workingDir,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    if (result.exitCode != 0) {
      throw GitProcessException(
          args, result.exitCode, result.stderr.toString());
    }
    return result.stdout.toString();
  }

  Future<String> runWithStdin(
      String workingDir, List<String> args, String input) async {
    final proc =
        await Process.start(executable, args, workingDirectory: workingDir);
    proc.stdin.add(utf8.encode(input));
    await proc.stdin.close();
    final outBuf = StringBuffer();
    final errBuf = StringBuffer();
    await Future.wait([
      proc.stdout.transform(utf8.decoder).forEach(outBuf.write),
      proc.stderr.transform(utf8.decoder).forEach(errBuf.write),
    ]);
    final exit = await proc.exitCode;
    if (exit != 0) throw GitProcessException(args, exit, errBuf.toString());
    return outBuf.toString();
  }

  Stream<String> streamLines(String workingDir, List<String> args) async* {
    final p = await Process.start(executable, args,
        workingDirectory: workingDir);
    final stdoutLines =
        p.stdout.transform(utf8.decoder).transform(const LineSplitter());
    final stderrBuf = StringBuffer();
    p.stderr.transform(utf8.decoder).listen(stderrBuf.write);
    await for (final line in stdoutLines) {
      yield line;
    }
    final exit = await p.exitCode;
    if (exit != 0) {
      throw GitProcessException(args, exit, stderrBuf.toString());
    }
  }
}
