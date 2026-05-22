import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:robyne/shared/models/track.dart';
import 'package:logging/logging.dart';

class LocalScanner {
  static const _supportedExtensions = ['.mp3', '.flac'];

  final _log = Logger('LocalScanner');

  Future<List<LocalTrack>> scanDirectory(String directoryPath) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) {
      _log.warning('Directory does not exist: $directoryPath');
      return [];
    }

    final tracks = <LocalTrack>[];

    await for (final entity in dir.list(recursive: true)) {
      if (entity is! File) continue;
      final ext = p.extension(entity.path).toLowerCase();
      if (!_supportedExtensions.contains(ext)) continue;

      try {
        final track = _fileToTrack(entity);
        tracks.add(track);
      } catch (e) {
        _log.warning('Failed to process file ${entity.path}: $e');
      }
    }

    _log.info('Scanned ${tracks.length} tracks from $directoryPath');
    return tracks;
  }

  LocalTrack _fileToTrack(File file) {
    final fileName = p.basenameWithoutExtension(file.path);
    final lrcPath = _findLrcFile(file);

    // Parse "artist - title" format, fallback to just title
    String title;
    String artist;

    if (fileName.contains(' - ')) {
      final parts = fileName.split(' - ');
      artist = parts[0].trim();
      title = parts.sublist(1).join(' - ').trim();
    } else {
      title = fileName.trim();
      artist = 'Unknown';
    }

    final id = file.path.hashCode.toRadixString(36);

    return LocalTrack(
      id: id,
      title: title,
      artist: artist,
      path: file.path,
      coverUrl: lrcPath,
    );
  }

  String? _findLrcFile(File audioFile) {
    final dir = p.dirname(audioFile.path);
    final baseName = p.basenameWithoutExtension(audioFile.path);
    final lrcPath = p.join(dir, '$baseName.lrc');
    final lrcFile = File(lrcPath);
    if (lrcFile.existsSync()) {
      return lrcPath;
    }
    return null;
  }
}
