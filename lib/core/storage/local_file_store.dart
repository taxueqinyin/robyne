import 'dart:io';

import 'package:path_provider/path_provider.dart';

class LocalFileStore {
  LocalFileStore({Directory? baseDirectory}) : _baseDirectory = baseDirectory;

  final Directory? _baseDirectory;

  Future<Directory> pluginsDirectory() async {
    final supportDirectory =
        _baseDirectory ?? await getApplicationSupportDirectory();
    final directory = Directory('${supportDirectory.path}/plugins');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }
}
