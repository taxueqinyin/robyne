import 'dart:io';

import 'package:path_provider/path_provider.dart';

class LocalFileStore {
  Future<Directory> pluginsDirectory() async {
    final supportDirectory = await getApplicationSupportDirectory();
    final directory = Directory('${supportDirectory.path}/plugins');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }
}
