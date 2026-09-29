import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

import '../../errors/app_error.dart';
import '../domain/theme_package.dart';
import 'theme_asset_resolver.dart';
import 'theme_path_guard.dart';

/// Materialises a loaded skin as a standalone skin directory.
///
/// This is the executable half of `THEME_ROADMAP.md` D5: a built-in skin must
/// be able to become a user skin by copying it, with no privileges the user
/// skin does not also have. The test that matters is not "does the copy exist"
/// but "does the copy behave identically", so the export writes the manifest
/// verbatim and re-homes every declared asset next to it.
class ThemeExporter {
  const ThemeExporter({
    required this.themesDirectory,
    Future<Directory> Function()? sourceDirectory,
  }) : _sourceDirectory = sourceDirectory;

  /// Where exported skins are written.
  ///
  /// Resolved by the caller so the exporter and the repository agree on where
  /// user skins live.
  final Future<Directory> Function() themesDirectory;

  /// Where an already-installed user skin is read from.
  ///
  /// Almost always the same as [themesDirectory]; they are separate because
  /// "read the original" and "write the copy" being the same path would mean
  /// exporting a skin onto itself. Defaults to [themesDirectory].
  final Future<Directory> Function()? _sourceDirectory;

  Future<Directory> get _source async =>
      await (_sourceDirectory?.call() ?? themesDirectory());

  /// Writes [theme] into `<themes>/<dir>/` and returns the target directory.
  ///
  /// An existing directory is replaced: re-exporting after editing a skin is
  /// the normal workflow, and refusing to overwrite would push users toward
  /// deleting by hand. Only the skin's own directory is ever touched.
  Future<ThemeExportResult> export(ThemePackage theme) async {
    final root = await themesDirectory();
    final directory = Directory(
      p.join(root.path, ThemePathGuard.directoryName(theme.id)),
    );
    // Belt and braces: `directoryName` already neutralises traversal, but an
    // export must never be able to write outside the themes directory.
    if (!ThemePathGuard.isWithin(root.path, directory.path)) {
      return ThemeExportResult.failure(
        const AppError(code: 'theme_export', message: '皮肤 id 不合法'),
      );
    }
    try {
      // Capture the manifest before replacing the target. A user skin can be
      // re-exported onto itself; deleting first would remove the very bytes
      // we are about to copy.
      final manifest = await _manifestBytes(theme);
      if (manifest == null) {
        return ThemeExportResult.failure(
          AppError(
            code: 'theme_export',
            message: '找不到「${theme.name}」的 theme.json',
          ),
        );
      }

      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
      await directory.create(recursive: true);

      await File(p.join(directory.path, 'theme.json')).writeAsBytes(manifest);

      final assets = <String>{
        if (theme.assets.background != null) theme.assets.background!,
        if (theme.assets.font != null) theme.assets.font!,
        if (theme.assets.logo != null) theme.assets.logo!,
        if (theme.assets.avatar != null) theme.assets.avatar!,
        if (theme.assets.hero != null) theme.assets.hero!,
        // An icon font ships like any other asset: a copied skin that lost it
        // would silently fall back to Material glyphs, which is exactly the
        // kind of "the copy looks different" bug D5 exists to prevent.
        if (theme.assets.iconFont != null) theme.assets.iconFont!,
        // Per-icon artwork is referenced from `icons`, not `assets`, so it
        // travels only if it is collected explicitly. Both states are
        // collected: copying a skin must not quietly drop the selected-state
        // artwork and leave the copy flipping to a blank glyph.
        for (final icon in theme.icons.icons.values) ...<String>[
          if (icon.image != null) icon.image!,
          if (icon.activeImage != null) icon.activeImage!,
        ],
      };
      for (final asset in assets) {
        await _copyAsset(theme, asset, directory);
      }
      return ThemeExportResult.success(directory);
    } on Object catch (error) {
      return ThemeExportResult.failure(
        AppError(code: 'theme_export', message: error.toString()),
      );
    }
  }

  /// The bytes of the skin's manifest, from wherever it is currently loaded.
  ///
  /// A built-in skin is read back out of the bundle rather than re-serialised
  /// from [ThemePackage], because re-serialising would silently bake in
  /// today's parser defaults and make the copy differ from the original the
  /// moment a token is added. Identity of behaviour is the point of D5.
  Future<List<int>?> _manifestBytes(ThemePackage theme) async {
    if (theme.source == ThemeSource.builtIn) {
      final path =
          'assets/themes/${ThemePathGuard.directoryName(theme.id)}/theme.json';
      try {
        final data = await rootBundle.load(path);
        return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      } on Object {
        return null;
      }
    }
    // A user skin can simply be re-read from disk.
    final source = await _userManifestFile(theme);
    if (source == null || !await source.exists()) {
      return null;
    }
    return source.readAsBytes();
  }

  Future<File?> _userManifestFile(ThemePackage theme) async {
    final root = await _source;
    final file = File(
      p.join(root.path, ThemePathGuard.directoryName(theme.id), 'theme.json'),
    );
    return ThemePathGuard.isWithin(root.path, file.path) ? file : null;
  }

  /// Copies one declared asset next to the manifest, preserving its name.
  ///
  /// A missing asset is not an error: skins legitimately declare artwork they
  /// do not ship, and every consumer already falls back to a plain colour.
  Future<void> _copyAsset(
    ThemePackage theme,
    String asset,
    Directory target,
  ) async {
    final safe = ThemePathGuard.sanitizeAsset(asset);
    if (safe == null) {
      return;
    }
    final bytes = await _loadAssetBytes(theme, safe);
    if (bytes == null) {
      // A declared-but-absent asset is normal; every consumer falls back to a
      // plain colour, and so does the copy.
      return;
    }
    await _writeInto(target, safe, bytes);
  }

  /// Reads one asset's bytes from wherever the skin currently lives.
  ///
  /// A user skin is read straight from its own directory rather than through
  /// [ThemeAssetResolver], which builds its own repository around the real
  /// support directory. That indirection is right for rendering and wrong for
  /// copying: it cannot be pointed at another location, and reading through it
  /// would make "export a skin to where it already is" read from a file the
  /// export itself is about to delete.
  Future<Uint8List?> _loadAssetBytes(ThemePackage theme, String asset) async {
    if (theme.source == ThemeSource.builtIn) {
      return const ThemeAssetResolver().loadBytes(theme, asset);
    }
    final root = await _source;
    final file = File(
      p.join(root.path, ThemePathGuard.directoryName(theme.id), asset),
    );
    if (!ThemePathGuard.isWithin(root.path, file.path)) {
      return null;
    }
    try {
      if (!await file.exists()) {
        return null;
      }
      final length = await file.length();
      if (length > ThemeAssetResolver.maxAssetBytes) {
        return null;
      }
      return await file.readAsBytes();
    } on Object {
      return null;
    }
  }

  Future<void> _writeInto(
    Directory target,
    String relative,
    List<int> bytes,
  ) async {
    final destination = File(p.join(target.path, relative));
    if (!ThemePathGuard.isWithin(target.path, destination.path)) {
      return;
    }
    await destination.parent.create(recursive: true);
    await destination.writeAsBytes(bytes);
  }
}

/// Outcome of an export: the directory written, or why it failed.
class ThemeExportResult {
  const ThemeExportResult._({this.directory, this.error});

  final Directory? directory;
  final AppError? error;

  bool get isSuccess => error == null;

  static ThemeExportResult success(Directory directory) =>
      ThemeExportResult._(directory: directory);

  static ThemeExportResult failure(AppError error) =>
      ThemeExportResult._(error: error);
}

/// Serialises a skin for export when no original manifest is available.
///
/// Only used as a last resort: the exporter prefers the bytes it was parsed
/// from. Kept as JSON text so a user can open the copy in an editor and see
/// the same structure the authoring guide documents.
String encodeThemeManifest(Map<String, Object?> manifest) {
  return const JsonEncoder.withIndent('  ').convert(manifest);
}
