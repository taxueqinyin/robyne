import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../../../core/database/app_database.dart' as db;
import '../../../core/database/legacy_storage_migration.dart';
import '../../../core/storage/local_file_store.dart';
import '../../downloads/domain/download_audio_format.dart';
import '../domain/lyric_settings.dart';
import '../domain/shortcut_action.dart';
import '../domain/shortcut_binding.dart';
import '../domain/shortcut_settings.dart';
import '../domain/user_settings.dart';

class SettingsRepository {
  SettingsRepository({
    required db.AppDatabase database,
    required LocalFileStore fileStore,
    LegacyStorageMigration? legacyMigration,
  }) : _database = database,
       _fileStore = fileStore,
       _legacyMigration = legacyMigration;

  static const defaultCacheSizeBytes = 1024 * 1024 * 1024;

  static const _cacheSizeKey = 'storage.cache_size_bytes';
  static const _cacheDirectoryKey = 'storage.cache_directory';
  static const _downloadsDirectoryKey = 'storage.downloads_directory';
  static const _downloadAudioFormatKey = 'downloads.audio_format';
  static const _shortcutPrefix = 'shortcuts.';
  static const _desktopLyricsEnabledKey = 'lyrics.desktop.enabled';
  static const _desktopLyricsAlwaysOnTopKey = 'lyrics.desktop.always_on_top';
  static const _desktopLyricsLockedKey = 'lyrics.desktop.locked';
  static const _desktopLyricsDoubleLineKey = 'lyrics.desktop.double_line';
  static const _desktopLyricFontFamilyKey = 'lyrics.desktop.font_family';
  static const _desktopLyricFontSizeKey = 'lyrics.desktop.font_size';
  static const _desktopLyricTextColorKey = 'lyrics.desktop.text_color';
  static const _desktopLyricStrokeColorKey = 'lyrics.desktop.stroke_color';
  static const _desktopLyricWindowLeftKey = 'lyrics.desktop.window_left';
  static const _desktopLyricWindowTopKey = 'lyrics.desktop.window_top';
  static const _activeThemeIdKey = 'theme.active_id';
  static const _themeModeOverrideKey = 'theme.mode_override';
  static const _themeSettingValuesKey = 'theme.setting_values';
  static const _disabledShortcutValue = '__disabled__';

  final db.AppDatabase _database;
  final LocalFileStore _fileStore;
  final LegacyStorageMigration? _legacyMigration;

  Future<UserSettings> load() async {
    await _legacyMigration?.ensureMigrated();
    final rows = await _database.select(_database.appSettings).get();
    final values = <String, String>{for (final row in rows) row.key: row.value};

    final defaultCacheDirectory = await _fileStore.cacheDirectory();
    final defaultDownloadsDirectory = await _fileStore.downloadsDirectory();
    final cacheDirectory = await _ensureDirectory(
      values[_cacheDirectoryKey],
      fallback: defaultCacheDirectory,
    );
    final downloadsDirectory = await _ensureDirectory(
      values[_downloadsDirectoryKey],
      fallback: defaultDownloadsDirectory,
    );
    if (values[_cacheDirectoryKey] != null &&
        values[_cacheDirectoryKey] != cacheDirectory.path) {
      await _write(_cacheDirectoryKey, cacheDirectory.path);
    }
    if (values[_downloadsDirectoryKey] != null &&
        values[_downloadsDirectoryKey] != downloadsDirectory.path) {
      await _write(_downloadsDirectoryKey, downloadsDirectory.path);
    }

    return UserSettings(
      cacheSizeBytes:
          int.tryParse(values[_cacheSizeKey] ?? '') ?? defaultCacheSizeBytes,
      cacheDirectoryPath: cacheDirectory.path,
      downloadsDirectoryPath: downloadsDirectory.path,
      downloadAudioFormat: _downloadAudioFormat(
        values[_downloadAudioFormatKey],
      ),
      shortcuts: _shortcutSettings(values),
      lyricSettings: _lyricSettings(values),
      activeThemeId: (values[_activeThemeIdKey]?.trim().isEmpty ?? true)
          ? UserSettings.defaultActiveThemeId
          : values[_activeThemeIdKey]!.trim(),
      themeModeOverrideName:
          (values[_themeModeOverrideKey]?.trim().isEmpty ?? true)
          ? UserSettings.defaultThemeModeOverrideName
          : values[_themeModeOverrideKey]!.trim(),
      themeSettingValues: _themeSettingValues(values[_themeSettingValuesKey]),
    );
  }

  Future<UserSettings> setActiveThemeId(String id) async {
    await _write(_activeThemeIdKey, id.trim());
    return load();
  }

  Future<UserSettings> setThemeModeOverride(String name) async {
    await _write(_themeModeOverrideKey, name.trim());
    return load();
  }

  Future<UserSettings> setThemeSettingValue(
    String themeId,
    String key,
    Object? value,
  ) async {
    final current = _themeSettingValues(await _readRaw(_themeSettingValuesKey));
    final composite = '$themeId/$key';
    if (value == null) {
      current.remove(composite);
    } else {
      current[composite] = value;
    }
    await _write(_themeSettingValuesKey, jsonEncode(current));
    return load();
  }

  Future<String?> _readRaw(String key) async {
    final row = await (_database.select(
      _database.appSettings,
    )..where((row) => row.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<UserSettings> setCacheSizeBytes(int bytes) async {
    final sanitized = bytes
        .clamp(64 * 1024 * 1024, 50 * 1024 * 1024 * 1024)
        .toInt();
    await _write(_cacheSizeKey, sanitized.toString());
    return load();
  }

  Future<UserSettings> setCacheDirectory(String path) async {
    final directory = await _ensureDirectory(path);
    await _write(_cacheDirectoryKey, directory.path);
    return load();
  }

  Future<UserSettings> setDownloadsDirectory(String path) async {
    final directory = await _ensureDirectory(path);
    await _write(_downloadsDirectoryKey, directory.path);
    return load();
  }

  Future<UserSettings> setDownloadAudioFormat(
    DownloadAudioFormat format,
  ) async {
    await _write(_downloadAudioFormatKey, format.name);
    return load();
  }

  Future<UserSettings> setShortcutBinding(
    ShortcutAction action,
    ShortcutBinding? binding,
  ) async {
    final key = '$_shortcutPrefix${action.storageKey}';
    if (binding == null) {
      await _write(key, _disabledShortcutValue);
      return load();
    }
    await _write(key, binding.serialize());
    return load();
  }

  Future<UserSettings> setLyricSettings(LyricSettings settings) async {
    await _write(
      _desktopLyricsEnabledKey,
      settings.desktopLyricsEnabled.toString(),
    );
    await _write(
      _desktopLyricsAlwaysOnTopKey,
      settings.desktopLyricsAlwaysOnTop.toString(),
    );
    await _write(
      _desktopLyricsLockedKey,
      settings.desktopLyricsLocked.toString(),
    );
    await _write(
      _desktopLyricsDoubleLineKey,
      settings.desktopLyricsDoubleLine.toString(),
    );
    await _write(
      _desktopLyricFontFamilyKey,
      settings.desktopLyricFontFamily?.trim() ?? '',
    );
    await _write(
      _desktopLyricFontSizeKey,
      settings.desktopLyricFontSize
          .clamp(LyricSettings.minFontSize, LyricSettings.maxFontSize)
          .toString(),
    );
    await _write(
      _desktopLyricTextColorKey,
      settings.desktopLyricTextColorValue.toString(),
    );
    await _write(
      _desktopLyricStrokeColorKey,
      settings.desktopLyricStrokeColorValue.toString(),
    );
    await _write(
      _desktopLyricWindowLeftKey,
      settings.desktopLyricWindowLeft?.toString() ?? '',
    );
    await _write(
      _desktopLyricWindowTopKey,
      settings.desktopLyricWindowTop?.toString() ?? '',
    );
    return load();
  }

  Future<void> _write(String key, String value) async {
    await _legacyMigration?.ensureMigrated();
    await _database
        .into(_database.appSettings)
        .insert(
          db.AppSettingsCompanion(key: Value(key), value: Value(value)),
          mode: InsertMode.insertOrReplace,
        );
  }

  Future<Directory> _ensureDirectory(
    String? path, {
    Directory? fallback,
  }) async {
    final rawPath = path?.trim();
    final normalizedPath = rawPath == null || rawPath.isEmpty
        ? null
        : p.normalize(rawPath);
    final directory = normalizedPath == null || normalizedPath.isEmpty
        ? fallback
        : Directory(normalizedPath);
    final resolved = directory ?? await _fileStore.supportDirectory();
    if (!await resolved.exists()) {
      await resolved.create(recursive: true);
    }
    return resolved;
  }

  static Map<String, Object> _themeSettingValues(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return <String, Object>{};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return <String, Object>{};
      }
      return <String, Object>{
        for (final entry in decoded.entries)
          entry.key.toString(): entry.value as Object,
      };
    } on Object {
      return <String, Object>{};
    }
  }

  static DownloadAudioFormat _downloadAudioFormat(String? value) {
    return DownloadAudioFormat.values.firstWhere(
      (format) => format.name == value,
      orElse: () => DownloadAudioFormat.original,
    );
  }

  static ShortcutSettings _shortcutSettings(Map<String, String> values) {
    var settings = ShortcutSettings.defaults();
    for (final action in ShortcutAction.values) {
      final raw = values['$_shortcutPrefix${action.storageKey}'];
      if (raw == _disabledShortcutValue) {
        settings = settings.copyWithBinding(action, null);
        continue;
      }
      final binding = ShortcutBinding.tryParse(raw);
      if (binding != null) {
        settings = settings.copyWithBinding(action, binding);
      }
    }
    return settings;
  }

  static LyricSettings _lyricSettings(Map<String, String> values) {
    const defaults = LyricSettings.defaults();
    final fontFamily = values[_desktopLyricFontFamilyKey]?.trim();
    return LyricSettings(
      desktopLyricsEnabled: values[_desktopLyricsEnabledKey] == 'true',
      desktopLyricsAlwaysOnTop: values[_desktopLyricsAlwaysOnTopKey] == null
          ? defaults.desktopLyricsAlwaysOnTop
          : values[_desktopLyricsAlwaysOnTopKey] == 'true',
      desktopLyricsLocked: values[_desktopLyricsLockedKey] == 'true',
      desktopLyricsDoubleLine: values[_desktopLyricsDoubleLineKey] == 'true',
      desktopLyricFontFamily: fontFamily == null || fontFamily.isEmpty
          ? null
          : fontFamily,
      desktopLyricFontSize:
          int.tryParse(values[_desktopLyricFontSizeKey] ?? '') ??
          defaults.desktopLyricFontSize,
      desktopLyricTextColorValue:
          int.tryParse(values[_desktopLyricTextColorKey] ?? '') ??
          defaults.desktopLyricTextColorValue,
      desktopLyricStrokeColorValue:
          int.tryParse(values[_desktopLyricStrokeColorKey] ?? '') ??
          defaults.desktopLyricStrokeColorValue,
      desktopLyricWindowLeft: double.tryParse(
        values[_desktopLyricWindowLeftKey] ?? '',
      ),
      desktopLyricWindowTop: double.tryParse(
        values[_desktopLyricWindowTopKey] ?? '',
      ),
    ).copyWith();
  }
}
