import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/features/downloads/infrastructure/download_file_namer.dart';
import 'package:robyne/features/player/domain/playback_item.dart';

void main() {
  test('uses readable song artist and source file names', () {
    final item = PlaybackItem.plugin(
      platform: 'NetEase',
      musicId: '1',
      title: 'Song:Name',
      artist: 'Artist/Name',
      raw: const <String, Object?>{'id': '1'},
    );

    expect(
      downloadFileNameForItem(item, Uri.parse('https://e.test/a.mp3?token=1')),
      'Song_Name - Artist_Name - NetEase.mp3',
    );
  });

  test('falls back for missing metadata and extension', () {
    final item = PlaybackItem.plugin(
      platform: '',
      musicId: '1',
      title: '',
      raw: const <String, Object?>{'id': '1'},
    );

    expect(
      downloadFileNameForItem(item, Uri.parse('https://e.test/media')),
      'Unknown title - Unknown artist - Unknown source.audio',
    );
  });

  test('uses target extension when download format converts audio', () {
    final item = PlaybackItem.plugin(
      platform: 'bilibili',
      musicId: '1',
      title: 'Song',
      artist: 'Artist',
      raw: const <String, Object?>{'id': '1'},
    );

    expect(
      downloadFileNameForItem(
        item,
        Uri.parse('https://e.test/audio.m4s'),
        targetExtension: '.mp3',
      ),
      'Song - Artist - bilibili.mp3',
    );
  });
}
