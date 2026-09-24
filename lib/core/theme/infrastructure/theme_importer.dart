import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../../../core/errors/app_error.dart';
import '../domain/theme_package.dart';
import 'theme_asset_resolver.dart';
import 'theme_manifest_parser.dart';
import 'theme_path_guard.dart';

/// Imports skins from a folder or a `.rtheme` archive into the user
/// themes directory.
class ThemeImporter {
  const ThemeImporter({required this.themesDirectory});

  /// Resolved by the caller so the importer and repository agree on location.
  final Future<Directory> Function() themesDirectory;

  /// Imports every theme found at [sourcePath] and returns their packages.
  ///
  /// [sourcePath] may be a skin directory, a zip/`.rtheme` archive, or a
  /// directory that directly contains several skins.
  Future<ThemeImportResult> importFrom(String sourcePath) async {
    final source = FileSystemEntity.typeSync(sourcePath);
    if (source == FileSystemEntityType.notFound) {
      return ThemeImportResult.failure(
        const AppError(code: 'theme_import', message: '路径不存在'),
      );
    }
    try {
      if (source == FileSystemEntityType.file) {
        final theme = await _importArchive(sourcePath);
        return theme == null
            ? ThemeImportResult.failure(
                const AppError(
                  code: 'theme_import',
                  message: '压缩包内没有找到 theme.json',
                ),
              )
            : ThemeImportResult.success(<ThemePackage>[theme]);
      }
      return await _importDirectory(sourcePath);
    } on Object catch (error) {
      return ThemeImportResult.failure(
        AppError(code: 'theme_import', message: error.toString()),
      );
    }
  }

  Future<ThemeImportResult> _importDirectory(String rootPath) async {
    final root = Directory(rootPath);
    final direct = File(p.join(root.path, 'theme.json'));
    final candidates = <Directory>[];
    if (await direct.exists()) {
      candidates.add(root);
    } else {
      await for (final entity in root.list()) {
        if (entity is Directory) {
          candidates.add(entity);
        }
      }
    }

    final imported = <ThemePackage>[];
    final errors = <AppError>[];
    for (final candidate in candidates) {
      final theme = await _installDirectory(candidate);
      if (theme == null) {
        errors.add(
          AppError(
            code: 'theme_import',
            message: '无法导入：${p.basename(candidate.path)}',
          ),
        );
        continue;
      }
      imported.add(theme);
    }
    if (imported.isEmpty) {
      return ThemeImportResult.failure(errors.first);
    }
    return ThemeImportResult.success(imported, errors: errors);
  }

  Future<ThemePackage?> _importArchive(String archivePath) async {
    final bytes = await File(archivePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final tempRoot = await Directory.systemTemp.createTemp('robyne_theme_');
    try {
      var manifestName = 'theme.json';
      // Archives may wrap the skin in a top-level directory.
      String? prefix;
      for (final file in archive.files) {
        final name = file.name;
        if (name.endsWith('theme.json')) {
          prefix = name.substring(0, name.length - 'theme.json'.length);
          manifestName = name;
          break;
        }
      }
      if (prefix == null) {
        return null;
      }
      // Refuse archives that would blow past the package budget once
      // expanded. Checking up front avoids writing anything at all.
      if (!_withinBudget(archive.files)) {
        return null;
      }
      final root = tempRoot.path;
      for (final file in archive.files) {
        if (!file.name.startsWith(prefix)) {
          continue;
        }
        if (file.name == manifestName && file.isFile == false) {
          continue;
        }
        final relative = file.name.substring(prefix.length);
        if (relative.isEmpty) {
          continue;
        }
        // Zip Slip: entry names are attacker-controlled and may contain
        // `..` or be absolute. Anything that leaves the temp root is
        // skipped rather than written.
        final safe = ThemePathGuard.sanitizeArchiveEntry(relative);
        if (safe == null) {
          continue;
        }
        final targetPath = p.join(root, p.joinAll(p.posix.split(safe)));
        if (!ThemePathGuard.isWithin(root, targetPath)) {
          continue;
        }
        final target = File(targetPath);
        await target.parent.create(recursive: true);
        if (file.isFile) {
          await target.writeAsBytes(file.content as List<int>);
        }
      }
      final imported = await _installDirectory(tempRoot);
      return imported;
    } finally {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    }
  }

  /// Getcha budget guards: a hostile archive must not be able to expand into
  /// gigabytes on disk or in memory.
  static const int _maxArchiveEntries = 1000;
  static const int _maxArchiveBytes = 10 * 1024 * 1024;

  static bool _withinBudget(List<ArchiveFile> files) {
    if (files.length > _maxArchiveEntries) {
      return false;
    }
    var total = 0;
    for (final file in files) {
      total += file.size;
      if (total > _maxArchiveBytes) {
        return false;
      }
    }
    return true;
  }

  /// Copies a prepared directory into the user themes directory, replacing any
  /// existing install of the same id.
  Future<ThemePackage?> _installDirectory(Directory source) async {
    final manifest = File(p.join(source.path, 'theme.json'));
    if (!await manifest.exists()) {
      return null;
    }
    if (await manifest.length() > ThemePathGuard.maxAssetLength * 1024) {
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
    final rawId = decoded['id']?.toString().trim();
    final fallbackId = p.basename(source.path);
    final id = (rawId == null || rawId.isEmpty) ? fallbackId : rawId;
    final safeId = ThemePathGuard.directoryName(id, fallbackId: fallbackId);

    final root = (await themesDirectory()).path;
    final target = Directory(p.join(root, safeId));
    // A skin may only ever own a directory directly beneath themes/.
    if (!ThemePathGuard.isWithin(root, target.path) || target.path == root) {
      return null;
    }
    if (await target.exists()) {
      await target.delete(recursive: true);
    }
    await target.create(recursive: true);
    await _copyContents(source, target);
    final theme = await _readInstalled(target, safeId);
    if (theme != null && !await _withinSizeBudget(theme)) {
      // Roll the install back rather than shipping a skin that would OOM
      // the renderer.
      await target.delete(recursive: true).catchError((_) => target);
      return null;
    }
    return theme;
  }

  /// Enforces the documented 10MB package budget now that the skin is on
  /// disk. Imports that blow the budget are rejected.
  Future<bool> _withinSizeBudget(ThemePackage theme) async {
    final candidates = <String?>[
      theme.tokens.background.image,
      theme.assets.background,
      theme.assets.font,
    ];
    final assets = candidates.whereType<String>().toList(growable: false);
    if (assets.isEmpty) {
      return true;
    }
    final total = await const ThemeAssetResolver().measure(theme, assets);
    return total <= ThemeAssetResolver.maxPackageBytes;
  }

  Future<ThemePackage?> _readInstalled(Directory directory, String id) async {
    final manifest = File(p.join(directory.path, 'theme.json'));
    if (!await manifest.exists()) {
      return null;
    }
    try {
      final decoded =
          jsonDecode(await manifest.readAsString()) as Map<String, Object?>?;
      if (decoded == null) {
        return null;
      }
      return installThemeManifest(decoded, fallbackId: id);
    } on Object {
      return null;
    }
  }

  static Future<void> _copyContents(Directory source, Directory target) async {
    await for (final entity in source.list(recursive: false)) {
      final targetPath = p.join(target.path, p.basename(entity.path));
      if (entity is File) {
        await entity.copy(targetPath);
      } else if (entity is Directory) {
        final next = Directory(targetPath);
        await next.create(recursive: true);
        await _copyContents(entity, next);
      }
    }
  }
}

/// Outcome of an import attempt.
class ThemeImportResult {
  const ThemeImportResult._({
    required this.themes,
    required this.errors,
    this.error,
  });

  factory ThemeImportResult.success(
    List<ThemePackage> themes, {
    List<AppError> errors = const <AppError>[],
  }) {
    return ThemeImportResult._(themes: themes, errors: errors);
  }

  factory ThemeImportResult.failure(AppError error) {
    return ThemeImportResult._(
      themes: const <ThemePackage>[],
      errors: <AppError>[error],
      error: error,
    );
  }

  final List<ThemePackage> themes;
  final List<AppError> errors;

  /// Set only when the whole operation failed.
  final AppError? error;

  bool get isSuccess => error == null;
}

/// Parses an installed manifest, used by both the importer and repository.
ThemePackage? installThemeManifest(Object? raw, {required String fallbackId}) {
  return const ThemeManifestParser().tryParse(
    raw,
    source: ThemeSource.user,
    fallbackId: fallbackId,
  );
}
