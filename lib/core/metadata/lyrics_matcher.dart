import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:robyne/core/metadata/tag_reader.dart';
import 'package:robyne/core/plugin/plugin_manager.dart';

class LyricsMatcher {
  final TagReader _tagReader = TagReader();

  Future<String?> matchLyrics({
    required File audioFile,
    int? pluginId,
    Map<String, dynamic>? musicItem,
    PluginManager? pluginManager,
  }) async {
    // Level 1: Check embedded lyrics
    final tag = _tagReader.readTag(audioFile);
    if (tag?.lyrics != null && tag!.lyrics!.isNotEmpty) {
      return tag.lyrics;
    }

    // Level 2: Check .lrc file in same directory
    final lrcFile = _findLrcFile(audioFile);
    if (lrcFile != null && await lrcFile.exists()) {
      return await lrcFile.readAsString();
    }

    // Level 3: Fetch from plugin
    if (pluginId != null && musicItem != null && pluginManager != null) {
      final lyricResult = await pluginManager.getLyric(pluginId, musicItem);
      if (lyricResult?.rawLrc != null) {
        return lyricResult!.rawLrc;
      }
    }

    return null;
  }

  File? _findLrcFile(File audioFile) {
    final dir = p.dirname(audioFile.path);
    final baseName = p.basenameWithoutExtension(audioFile.path);

    // Try exact match first
    final exactMatch = File(p.join(dir, '$baseName.lrc'));
    if (exactMatch.existsSync()) return exactMatch;

    // Try with artist - title format
    final files = Directory(dir).listSync();
    for (final file in files) {
      if (file is File && p.extension(file.path).toLowerCase() == '.lrc') {
        final lrcBaseName = p.basenameWithoutExtension(file.path).toLowerCase();
        if (lrcBaseName.contains(baseName.toLowerCase()) ||
            baseName.toLowerCase().contains(lrcBaseName)) {
          return file;
        }
      }
    }

    return null;
  }
}
