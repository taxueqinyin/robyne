import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';

class TagWriter {
  Future<void> updateTag(
    File file, {
    String? title,
    String? artist,
    String? album,
  }) async {
    try {
      final metadata = readMetadata(file, getImage: false);

      // Note: audio_metadata_reader currently only supports reading
      // For writing, we would need a different package or native implementation
      // This is a placeholder for future implementation
      throw UnimplementedError(
        'Tag writing not yet implemented. Consider using flutter_media_metadata for write support.',
      );
    } catch (e) {
      rethrow;
    }
  }
}
