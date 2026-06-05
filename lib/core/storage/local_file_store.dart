import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LocalFileStore {
  LocalFileStore({Directory? baseDirectory}) : _baseDirectory = baseDirectory;

  final Directory? _baseDirectory;
  Future<Directory>? _fallbackSupportDirectory;

  Future<Directory> supportDirectory() async {
    final baseDirectory = _baseDirectory;
    if (baseDirectory != null) {
      return baseDirectory;
    }
    try {
      return await getApplicationSupportDirectory();
    } catch (_) {
      return _fallbackSupportDirectory ??= Directory.systemTemp.createTemp(
        'robyne_support_',
      );
    }
  }

  Future<Directory> pluginsDirectory() async {
    final directory = Directory(
      p.join((await supportDirectory()).path, 'plugins'),
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<Directory> dataDirectory() async {
    final directory = Directory(
      p.join((await supportDirectory()).path, 'data'),
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<Directory> cacheDirectory() async {
    final directory = Directory(
      p.join((await supportDirectory()).path, 'cache'),
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<Directory> downloadsDirectory() async {
    final directory = Directory(
      p.join((await supportDirectory()).path, 'downloads'),
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }
}
