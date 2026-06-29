import 'package:path/path.dart' as p;

import '../../player/domain/playback_item.dart';

String downloadFileNameForItem(
  PlaybackItem item,
  Uri? sourceUri, {
  String? targetExtension,
}) {
  final sourceExtension = p.extension(sourceUri?.path ?? '');
  final extension =
      _normalizedExtension(targetExtension) ??
      (sourceExtension.isEmpty ? '.audio' : sourceExtension);
  final title = _fileNamePart(item.title, fallback: 'Unknown title');
  final artist = _fileNamePart(item.artist, fallback: 'Unknown artist');
  final source = _fileNamePart(item.platform, fallback: 'Unknown source');
  return _limitFileName('$title - $artist - $source$extension');
}

String? _normalizedExtension(String? extension) {
  final trimmed = extension?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed.startsWith('.') ? trimmed : '.$trimmed';
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
