import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Image;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

import '../../storage/local_file_store.dart';
import '../domain/theme_package.dart';
import 'theme_path_guard.dart';
import 'theme_repository.dart';

/// Turns a skin's asset reference into something renderable.
///
/// A skin may ship artwork inside the app bundle (built-in) or on disk
/// (user-installed), so resolution has two cases. Missing files resolve to
/// null, letting callers fall back to plain colours.
class ThemeAssetResolver {
  const ThemeAssetResolver();

  /// Largest single asset we will decode, matching the documented 500KB
  /// budget. Oversized artwork is skipped rather than loaded: a few KB of
  /// PNG can decode into gigabytes of bitmap.
  static const int maxAssetBytes = 500 * 1024;

  /// Largest total package size we accept, matching the documented 10MB
  /// budget.
  static const int maxPackageBytes = 10 * 1024 * 1024;

  /// Resolves [asset] to a file path for [theme].
  ///
  /// Returns null when the asset is absent, the id is empty, or the file does
  /// not exist.
  Future<String?> resolveFilePath(ThemePackage theme, String? asset) async {
    final normalized = asset?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    if (theme.source == ThemeSource.builtIn) {
      return _resolveBuiltIn(theme, normalized);
    }
    final repository = FileThemeRepository(fileStore: LocalFileStore());
    return repository.resolveAssetPath(theme, normalized);
  }

  /// Resolves [asset] to bytes, for renderers that prefer memory images.
  Future<ImageBytes?> resolveBytes(ThemePackage theme, String? asset) async {
    final path = await resolveFilePath(theme, asset);
    if (path == null) {
      return null;
    }
    try {
      if (theme.source == ThemeSource.builtIn) {
        final data = await rootBundle.load(path);
        return ImageBytes(
          provider: MemoryImage(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          ),
          bytes: data.lengthInBytes,
        );
      }
      final file = File(path);
      if (!await file.exists()) {
        return null;
      }
      // Check the size before reading: a multi-gigabyte "background" would
      // otherwise be pulled into memory and then handed to the decoder.
      final length = await file.length();
      if (length > maxAssetBytes) {
        return null;
      }
      return ImageBytes(provider: FileImage(file), bytes: length);
    } on Object {
      return null;
    }
  }

  /// Resolves [asset] to raw bytes.
  ///
  /// Separate from [resolveBytes] because callers that only want to copy a
  /// file (the D5 exporter) should not have to unwrap an [ImageProvider] to
  /// get at the data. Enforces the same single-asset budget.
  Future<Uint8List?> loadBytes(ThemePackage theme, String? asset) async {
    final path = await resolveFilePath(theme, asset);
    if (path == null) {
      return null;
    }
    try {
      if (theme.source == ThemeSource.builtIn) {
        final data = await rootBundle.load(path);
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        return bytes.length <= maxAssetBytes ? bytes : null;
      }
      final file = File(path);
      if (!await file.exists()) {
        return null;
      }
      final length = await file.length();
      if (length > maxAssetBytes) {
        return null;
      }
      return await file.readAsBytes();
    } on Object {
      return null;
    }
  }

  String? _resolveBuiltIn(ThemePackage theme, String asset) {
    // Uses the shared id -> directory mapping so a built-in skin copied into
    // the user themes directory keeps resolving the same paths.
    final root = 'assets/themes/${ThemePathGuard.directoryName(theme.id)}';
    final safe = ThemePathGuard.sanitizeAsset(asset);
    if (safe == null) {
      return null;
    }
    return p.posix.join(root, safe);
  }

  /// Total size of a skin's assets, used to enforce the 10MB budget.
  Future<int> measure(ThemePackage theme, List<String> assets) async {
    var total = 0;
    for (final asset in assets) {
      final resolved = await resolveFilePath(theme, asset);
      if (resolved == null) {
        continue;
      }
      try {
        if (theme.source == ThemeSource.builtIn) {
          final data = await rootBundle.load(resolved);
          total += data.buffer.asUint8List().length;
        } else {
          final file = File(resolved);
          if (await file.exists()) {
            total += await file.length();
          }
        }
      } on Object {
        continue;
      }
    }
    return total;
  }
}

/// A resolved image plus its size in bytes.
class ImageBytes {
  const ImageBytes({required this.provider, required this.bytes});

  final ImageProvider provider;
  final int bytes;
}
