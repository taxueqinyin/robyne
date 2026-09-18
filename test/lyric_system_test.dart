import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/database/app_database.dart' as db;
import 'package:robyne/features/lyrics/domain/lyric_document.dart';
import 'package:robyne/features/lyrics/infrastructure/lyric_repository.dart';
import 'package:robyne/features/player/domain/playback_item.dart';

void main() {
  test('parses synchronized LRC lines and applies offset for active line', () {
    final document = LyricDocument.parse(
      '[00:01.00]first\n[00:02.25][00:03.00]repeat',
      sourceType: LyricSourceType.plugin,
      offset: const Duration(milliseconds: 250),
    );

    expect(document.lines.map((line) => line.text), <String>[
      'first',
      'repeat',
      'repeat',
    ]);
    expect(document.activeIndex(const Duration(seconds: 2)), 1);
  });

  test('resolves current, previous, and next lyric starts', () {
    final document = LyricDocument.parse(
      '[00:10.00]first\n[00:20.00]second\n[00:30.00]third',
      sourceType: LyricSourceType.plugin,
      offset: const Duration(seconds: 1),
    );

    expect(
      document.startOfCurrentLine(const Duration(seconds: 22)),
      const Duration(seconds: 19),
    );
    expect(
      document.startOfPreviousLine(const Duration(seconds: 22)),
      const Duration(seconds: 9),
    );
    expect(
      document.startOfNextLine(const Duration(seconds: 22)),
      const Duration(seconds: 29),
    );
    expect(
      document.startOfNextLine(const Duration(seconds: 1)),
      const Duration(seconds: 9),
    );
  });

  test(
    'sidecar lyric wins over associated plugin lyric for local music',
    () async {
      final database = db.AppDatabase.memory();
      addTearDown(database.close);
      final tempDirectory = await Directory.systemTemp.createTemp(
        'robyne_lyric_priority_test_',
      );
      addTearDown(() async {
        await tempDirectory.delete(recursive: true);
      });
      final audio = File('${tempDirectory.path}/Song.mp3');
      await audio.writeAsBytes(<int>[1, 2, 3]);
      await File(
        '${tempDirectory.path}/Song.lrc',
      ).writeAsString('[00:01]sidecar');
      final item = PlaybackItem.local(path: audio.path);
      final repository = LyricRepository(database: database);
      await repository.associatePluginLyric(
        item: item,
        rawLyric: '[00:01]plugin',
        pluginPlatform: 'Lyrics',
        pluginRaw: const <String, Object?>{'id': '1'},
      );

      final document = await repository.loadForItem(item);

      expect(document?.sourceType, LyricSourceType.sidecar);
      expect(document?.lines.single.text, 'sidecar');
    },
  );
}
