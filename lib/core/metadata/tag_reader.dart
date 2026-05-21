import 'dart:io';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:path/path.dart' as p;

class AudioTag {
  final String? title;
  final String? artist;
  final String? album;
  final Uint8List? cover;
  final Duration? duration;
  final String? lyrics;

  const AudioTag({
    this.title,
    this.artist,
    this.album,
    this.cover,
    this.duration,
    this.lyrics,
  });
}

class TagReader {
  static const _supportedExtensions = {'.mp3', '.flac', '.wav', '.ogg', '.m4a', '.aac'};

  bool isSupportedAudioFile(String path) {
    final ext = p.extension(path).toLowerCase();
    return _supportedExtensions.contains(ext);
  }

  AudioTag? readTag(File file) {
    try {
      if (!isSupportedAudioFile(file.path)) return null;

      final metadata = readMetadata(file, getImage: true);

      return AudioTag(
        title: metadata.title,
        artist: metadata.artist,
        album: metadata.album,
        cover: null, // TODO: Fix cover extraction
        duration: metadata.duration,
        lyrics: metadata.lyrics,
      );
    } catch (e) {
      return null;
    }
  }

  Future<List<FileSystemEntity>> scanDirectory(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return [];

    final files = <FileSystemEntity>[];
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File && isSupportedAudioFile(entity.path)) {
        files.add(entity);
      }
    }
    return files;
  }

  String getFileNameWithoutExtension(String path) {
    return p.basenameWithoutExtension(path);
  }
}
