import 'dart:convert';
import 'package:gitopen/application/workspaces/workspace_persistence.dart';
import 'package:gitopen/infrastructure/persistence/database.dart';

const String _key = 'open_workspaces';

final class DriftWorkspacePersistence implements WorkspacePersistence {
  DriftWorkspacePersistence(this._db);
  final AppDatabase _db;

  @override
  Future<List<String>> getOpenPaths() async {
    final row = await (_db.select(_db.settings)
          ..where((s) => s.key.equals(_key)))
        .getSingleOrNull();
    if (row == null) return [];
    final decoded = jsonDecode(row.valueJson);
    if (decoded is! List) return [];
    return decoded.cast<String>();
  }

  @override
  Future<void> saveOpenPaths(List<String> paths) async {
    final json = jsonEncode(paths);
    await _db.into(_db.settings).insertOnConflictUpdate(
          SettingsCompanion.insert(
            key: _key,
            valueJson: json,
          ),
        );
  }
}
