import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:robyne/core/database/app_database.dart' as db;
import 'package:robyne/core/storage/local_file_store.dart';
import 'package:robyne/core/theme/domain/theme_layout_override.dart';
import 'package:robyne/core/theme/domain/theme_layout.dart';
import 'package:robyne/core/theme/domain/theme_regions.dart';
import 'package:robyne/features/downloads/domain/download_audio_format.dart';
import 'package:robyne/features/settings/domain/lyric_settings.dart';
import 'package:robyne/features/settings/domain/shortcut_action.dart';
import 'package:robyne/features/settings/domain/shortcut_binding.dart';
import 'package:robyne/features/settings/infrastructure/settings_repository.dart';

void main() {
  test('persists L2 layout overrides per theme and survives reload', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'robyne_layout_override_test_',
    );
    addTearDown(() async {
      await tempDirectory.delete(recursive: true);
    });
    final database = db.AppDatabase.memory();
    addTearDown(database.close);
    final repository = SettingsRepository(
      database: database,
      fileStore: LocalFileStore(baseDirectory: tempDirectory),
    );

    final override = ThemeLayoutOverride(
      desktopArrangement: RobyneArrangement.parse(<Object?>[
        <String, Object?>{'region': 'content', 'slot': 'center'},
        <String, Object?>{'region': 'navBar', 'slot': 'right', 'size': 0.20},
      ], formFactor: RobyneFormFactor.desktop),
      contentStyle: ThemeListStyle.grid,
    );
    await repository.setThemeLayoutOverride('official.dark', override);

    final loaded = await repository.load();
    expect(loaded.themeLayoutOverrides['official.dark'], override);
    expect(loaded.themeLayoutOverrides['official.light'], isNull);

    await repository.setThemeLayoutOverride('official.dark', null);
    final cleared = await repository.load();
    expect(cleared.themeLayoutOverrides['official.dark'], isNull);
  });

  test('loads defaults and persists storage settings', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'robyne_settings_test_',
    );
    addTearDown(() async {
      await tempDirectory.delete(recursive: true);
    });
    final database = db.AppDatabase.memory();
    addTearDown(database.close);
    final repository = SettingsRepository(
      database: database,
      fileStore: LocalFileStore(baseDirectory: tempDirectory),
    );

    final initial = await repository.load();
    expect(initial.cacheSizeBytes, SettingsRepository.defaultCacheSizeBytes);
    expect(initial.cacheDirectoryPath, endsWith('cache'));
    expect(initial.downloadsDirectoryPath, endsWith('downloads'));
    expect(initial.downloadAudioFormat, DownloadAudioFormat.original);
    expect(initial.shortcuts[ShortcutAction.playPause]?.displayLabel, 'Space');
    expect(
      initial.shortcuts[ShortcutAction.currentLyricLine]?.displayLabel,
      '←',
    );
    expect(initial.shortcuts[ShortcutAction.desktopLyrics], isNull);
    expect(initial.lyricSettings, const LyricSettings.defaults());
    expect(initial.lyricSettings.desktopLyricWindowLeft, isNull);
    expect(initial.lyricSettings.desktopLyricWindowTop, isNull);
    expect(initial.sidebarWidth, isNull);

    final customCache = Directory(p.join(tempDirectory.path, 'custom-cache'));
    final customDownloads = Directory(
      p.join(tempDirectory.path, 'custom-downloads'),
    );
    await repository.setCacheSizeBytes(256 * 1024 * 1024);
    await repository.setCacheDirectory(customCache.path);
    await repository.setDownloadsDirectory(customDownloads.path);
    await repository.setDownloadAudioFormat(DownloadAudioFormat.mp3);
    await repository.setShortcutBinding(
      ShortcutAction.nextTrack,
      ShortcutBinding(
        triggerKeyId: LogicalKeyboardKey.keyK.keyId,
        control: true,
      ),
    );
    await repository.setShortcutBinding(ShortcutAction.playPause, null);
    await repository.setLyricSettings(
      const LyricSettings.defaults().copyWith(
        desktopLyricsEnabled: true,
        desktopLyricsAlwaysOnTop: false,
        desktopLyricsLocked: true,
        desktopLyricsDoubleLine: true,
        desktopLyricFontFamily: 'SimHei',
        desktopLyricFontSize: 44,
        desktopLyricTextColorValue: 0xFFE767AF,
        desktopLyricStrokeColorValue: 0xFFFFC82E,
        desktopLyricWindowLeft: 123.5,
        desktopLyricWindowTop: 456.25,
      ),
    );
    await repository.setSidebarWidth(212.5);

    final saved = await repository.load();
    expect(saved.cacheSizeBytes, 256 * 1024 * 1024);
    expect(saved.cacheDirectoryPath, customCache.path);
    expect(saved.downloadsDirectoryPath, customDownloads.path);
    expect(saved.downloadAudioFormat, DownloadAudioFormat.mp3);
    expect(saved.shortcuts[ShortcutAction.playPause], isNull);
    expect(saved.shortcuts[ShortcutAction.nextTrack]?.displayLabel, 'Ctrl + K');
    expect(saved.lyricSettings.desktopLyricsEnabled, isTrue);
    expect(saved.lyricSettings.desktopLyricsAlwaysOnTop, isFalse);
    expect(saved.lyricSettings.desktopLyricsLocked, isTrue);
    expect(saved.lyricSettings.desktopLyricsDoubleLine, isTrue);
    expect(saved.lyricSettings.desktopLyricFontFamily, 'SimHei');
    expect(saved.lyricSettings.desktopLyricFontSize, 44);
    expect(saved.lyricSettings.desktopLyricTextColorValue, 0xFFE767AF);
    expect(saved.lyricSettings.desktopLyricStrokeColorValue, 0xFFFFC82E);
    expect(saved.lyricSettings.desktopLyricWindowLeft, 123.5);
    expect(saved.lyricSettings.desktopLyricWindowTop, 456.25);
    expect(saved.sidebarWidth, 212.5);
    await repository.setSidebarWidth(null);
    expect((await repository.load()).sidebarWidth, isNull);
    expect(await customCache.exists(), isTrue);
    expect(await customDownloads.exists(), isTrue);
  });

  test('normalizes stored Windows-style storage paths', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'robyne_settings_path_test_',
    );
    addTearDown(() async {
      await tempDirectory.delete(recursive: true);
    });
    final database = db.AppDatabase.memory();
    addTearDown(database.close);
    final repository = SettingsRepository(
      database: database,
      fileStore: LocalFileStore(baseDirectory: tempDirectory),
    );

    final mixedCachePath = '${tempDirectory.path}/mixed-cache';
    await repository.setCacheDirectory(mixedCachePath);

    final saved = await repository.load();
    expect(saved.cacheDirectoryPath, p.normalize(mixedCachePath));
  });

  test('desktop lyric font size is clamped into supported range', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'robyne_settings_lyric_font_test_',
    );
    addTearDown(() async {
      await tempDirectory.delete(recursive: true);
    });
    final database = db.AppDatabase.memory();
    addTearDown(database.close);
    final repository = SettingsRepository(
      database: database,
      fileStore: LocalFileStore(baseDirectory: tempDirectory),
    );

    await repository.setLyricSettings(
      const LyricSettings.defaults().copyWith(desktopLyricFontSize: 999),
    );
    expect(
      (await repository.load()).lyricSettings.desktopLyricFontSize,
      LyricSettings.maxFontSize,
    );

    await repository.setLyricSettings(
      const LyricSettings.defaults().copyWith(desktopLyricFontSize: 1),
    );
    expect(
      (await repository.load()).lyricSettings.desktopLyricFontSize,
      LyricSettings.minFontSize,
    );
  });
}
