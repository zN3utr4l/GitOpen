import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class GitOpenPaths {
  static Future<String> stateDbPath() async {
    final supportDir = await getApplicationSupportDirectory();
    final dir = Directory(p.join(supportDir.path, 'GitOpen'));
    await dir.create(recursive: true);
    return p.join(dir.path, 'state.db');
  }

  static Future<String> logDirectory() async {
    final supportDir = await getApplicationSupportDirectory();
    final dir = Directory(p.join(supportDir.path, 'GitOpen', 'logs'));
    await dir.create(recursive: true);
    return dir.path;
  }
}
