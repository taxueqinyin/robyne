import 'package:path/path.dart' as p;

import '../../player/domain/playback_item.dart';

String downloadFileNameForItem(PlaybackItem item, Uri? sourceUri) {
  final extension = p.extension(sourceUri?.path ?? '').isEmpty
      ? '.audio'
      : p.extension(sourceUri?.path ?? '');
  final title = _fileNamePart(item.title, fallback: 'Unknown title');
  final artist = _fileNamePart(item.artist, fallback: 'Unknown artist');
  final source = _fileNamePart(item.platform, fallback: 'Unknown source');
  return _limitFileName('$title - $artist - $source$extension');
}

String _fileNamePart(String? value, {required String fallback}) {
  final trimmed = value?.trim();
  final source = trimmed == null || trimmed.isEmpty ? fallback : trimmed;
  final sanitized = source
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final withoutTrailingDots = sanitized.replaceAll(RegExp(r'[. ]+$'), '');
  return withoutTrailingDots.isEmpty ? fallback : withoutTrailingDots;
}

String _limitFileName(String fileName) {
  const maxLength = 180;
  if (fileName.length <= maxLength) {
    return fileName;
  }
  final extension = p.extension(fileName);
  final stem = p.basenameWithoutExtension(fileName);
  return '${stem.substring(0, maxLength - extension.length)}$extension';
}
