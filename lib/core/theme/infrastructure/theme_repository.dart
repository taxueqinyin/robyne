import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

import '../../storage/local_file_store.dart';
import '../domain/theme_layout.dart';
import '../domain/theme_package.dart';
import '../domain/theme_tokens.dart';
import 'theme_manifest.dart';
import 'theme_path_guard.dart';

/// Discovers and loads theme packages.
abstract class ThemeRepository {
  /// Every theme known to the app, built-in first then user themes.
  Future<List<ThemePackage>> listThemes();

  /// Reads a single theme by id, or `null` when it no longer exists.
  Future<ThemePackage?> loadTheme(String id);

  /// Directory holding user-installed skins. Built-in-only implementations
  /// should throw [UnsupportedError]; callers guard against it.
  Future<Directory> userThemesDirectory() =>
      throw UnsupportedError('This repository has no user theme directory');

  /// Deletes a user-installed skin. Returns false for built-in skins.
  Future<bool> deleteTheme(String id) async => false;
}

/// Loads themes from user-installed directories under `<support>/themes`.
///
/// Each theme is a directory (or an extracted `.rtheme` archive) containing
/// `theme.json` plus optional assets.
class FileThemeRepository implements ThemeRepository {
  FileThemeRepository({required LocalFileStore fileStore})
    : _fileStore = fileStore;

  final LocalFileStore _fileStore;

  Future<Directory> themesDirectory() async {
    final directory = Directory(
      p.join((await _fileStore.supportDirectory()).path, 'themes'),
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  @override
  Future<List<ThemePackage>> listThemes() async {
    final directory = await themesDirectory();
    final themes = <ThemePackage>[];
    final entries = await directory
        .list()
        .where((entity) => entity is Directory)
        .cast<Directory>()
        .toList();
    for (final entry in entries) {
      final theme = await _read(entry);
      if (theme != null) {
        themes.add(theme);
      }
    }
    return themes;
  }

  @override
  Future<ThemePackage?> loadTheme(String id) async {
    final directory = await themesDirectory();
    final candidate = Directory(p.join(directory.path, _sanitizeId(id)));
    if (!await candidate.exists()) {
      return null;
    }
    return _read(candidate);
  }

  @override
  Future<Directory> userThemesDirectory() => themesDirectory();

  @override
  Future<bool> deleteTheme(String id) async {
    final root = await themesDirectory();
    final directory = Directory(p.join(root.path, _sanitizeId(id)));
    // Never trust the id: deleting outside the themes directory would take
    // the whole support directory (database, plugins, downloads) with it.
    if (!ThemePathGuard.isWithin(root.path, directory.path)) {
      return false;
    }
    if (directory.path == root.path) {
      return false;
    }
    if (!await directory.exists()) {
      return false;
    }
    await directory.delete(recursive: true);
    return true;
  }

  /// Resolves an asset reference from a user theme directory.
  ///
  /// Only ever returns paths inside this skin's own directory; see
  /// [ThemePathGuard].
  Future<String?> resolveAssetPath(ThemePackage theme, String? asset) async {
    final directory = await themesDirectory();
    final root = p.join(directory.path, _sanitizeId(theme.id));
    final target = ThemePathGuard.resolveWithin(root, asset);
    if (target == null) {
      return null;
    }
    final file = File(target);
    if (!await file.exists()) {
      return null;
    }
    // Directories and device nodes are not artwork.
    if (!await FileSystemEntity.isFile(target)) {
      return null;
    }
    return file.path;
  }

  Future<ThemePackage?> _read(Directory directory) async {
    final manifest = File(p.join(directory.path, 'theme.json'));
    if (!await manifest.exists()) {
      return null;
    }
    Map<String, Object?>? decoded;
    try {
      decoded =
          jsonDecode(await manifest.readAsString()) as Map<String, Object?>?;
    } on Object {
      return null;
    }
    if (decoded == null) {
      return null;
    }
    final package = parseThemeManifest(
      decoded,
      source: ThemeSource.user,
      fallbackId: p.basename(directory.path),
    );
    return package;
  }

  /// Called through wherever a theme id becomes a directory name.
  ///
  /// Delegates to [ThemePathGuard.directoryName] so user and built-in skins
  /// agree on where a given id lives.
  static String _sanitizeId(String id) => ThemePathGuard.directoryName(id);
}

/// Loads the themes shipped inside the app bundle.
///
/// Built-in skins travel through exactly the same parser and models as user
/// skins: the official UI is itself just another theme package.
class BuiltInThemeRepository implements ThemeRepository {
  const BuiltInThemeRepository()
    : _ids = const <String>[
        'official.light',
        'official.dark',
        'official.midnight',
      ];

  static const String _assetRoot = 'assets/themes';

  final List<String> _ids;

  @override
  Future<List<ThemePackage>> listThemes() async {
    final themes = <ThemePackage>[];
    for (final id in _ids) {
      final theme = await loadTheme(id);
      if (theme != null) {
        themes.add(theme);
      }
    }
    return themes;
  }

  @override
  Future<ThemePackage?> loadTheme(String id) async {
    // Uses the shared id -> directory mapping so this always agrees with
    // ThemeAssetResolver's built-in resolution.
    final folder = ThemePathGuard.directoryName(id);
    final path = '$_assetRoot/$folder/theme.json';
    Map<String, Object?>? decoded;
    try {
      final raw = await rootBundle.loadString(path);
      decoded = jsonDecode(raw) as Map<String, Object?>?;
    } on Object {
      // A missing or corrupt built-in skin falls back to a synthetic one so
      // the app always has something to render with.
      return _synthetic(id);
    }
    if (decoded == null) {
      return _synthetic(id);
    }
    return parseThemeManifest(
      decoded,
      source: ThemeSource.builtIn,
      fallbackId: id,
    );
  }

  @override
  Future<Directory> userThemesDirectory() =>
      throw UnsupportedError('Built-in themes have no user directory');

  @override
  Future<bool> deleteTheme(String id) async => false;

  ThemePackage _synthetic(String id) {
    final isDark = !id.contains('light');
    return ThemePackage(
      id: id,
      name: isDark ? 'Robyne 暗色' : 'Robyne 亮色',
      author: 'Robyne',
      authorUrl: null,
      version: '1.0.0',
      description: '内置皮肤',
      preview: isDark ? '#14161A' : '#F7F8FA',
      tags: <String>[isDark ? 'dark' : 'light'],
      mode: isDark ? ThemeModePreference.dark : ThemeModePreference.light,
      schemaVersion: 1,
      tokens: const ThemeTokens.baseline(),
      layout: const ThemeLayout.baseline(),
      settings: const <ThemeSetting>[],
      assets: const ThemeAssets.empty(),
      source: ThemeSource.builtIn,
    );
  }
}
