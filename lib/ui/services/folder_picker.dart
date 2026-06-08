import 'package:file_selector/file_selector.dart';

class FolderPicker {
  Future<String?> pickFolder(String title) async {
    final path = await getDirectoryPath(
        confirmButtonText: 'Open');
    return path;
  }
}
