import 'dart:io';

import 'package:path_provider/path_provider.dart';

class LocalFileStore {
  LocalFileStore({Directory? baseDirectory}) : _baseDirectory = baseDirectory;

  final Directory? _baseDirectory;

  Future<Directory> supportDirectory() async {
    return _baseDirectory ?? await getApplicationSupportDirectory();
  }

  Future<Directory> pluginsDirectory() async {
    final directory = Directory('${(await supportDirectory()).path}/plugins');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<Directory> dataDirectory() async {
    final directory = Directory('${(await supportDirectory()).path}/data');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<Directory> cacheDirectory() async {
    final directory = Directory('${(await supportDirectory()).path}/cache');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }
}
