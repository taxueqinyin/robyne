import 'dart:io';

import 'package:flutter/services.dart';

import '../domain/theme_package.dart';
import 'theme_asset_resolver.dart';

/// Loads a skin's bundled fonts so its declarations can actually name them.
///
/// Two kinds, both shipped the same way:
///
/// - `assets.font` — the text face, for `typography.fontFamily`
/// - `assets.icons.font` — an *icon* face, so `icons.*.glyph` code points can
///   index a real icon set (Lucide, Remix, bespoke) instead of Material's
///
/// Without this, both were parsed, path-hardened and counted against the size
/// budget but never registered with the engine, so a skin could only ever
/// reference a font the platform had already installed.
class ThemeFontLoader {
  const ThemeFontLoader({ThemeAssetResolver? resolver})
    : _resolver = resolver ?? const ThemeAssetResolver();

  final ThemeAssetResolver _resolver;

  /// Largest font file we will hand to the engine.
  ///
  /// A hostile or merely careless skin could ship a multi-hundred-MB font and
  /// stall startup; the documented package budget already implies a sane
  /// upper bound, and this keeps one bad asset from blocking the whole theme.
  static const int maxFontBytes = 2 * 1024 * 1024;

  /// Registers [theme]'s font and returns the family name to use.
  ///
  /// Returns `null` when the skin ships no font, when the asset cannot be
  /// resolved, or when loading fails — in every case the caller should fall
  /// back to `typography.family` (a platform font) rather than fail the skin.
  Future<String?> loadFamilyFor(ThemePackage theme) async {
    return _load(theme, theme.assets.font, _familyNameFor(theme));
  }

  /// Registers [theme]'s icon font and returns the family name to use.
  ///
  /// Returns `null` when the skin ships none. Icon declarations then fall back
  /// to whichever other form they used (`codePoint` in Material, or `image`),
  /// and ultimately to the built-in glyph.
  Future<String?> loadIconFamilyFor(ThemePackage theme) async {
    return _load(theme, theme.assets.iconFont, _iconFamilyFor(theme));
  }

  /// The family name a skin's icon font is registered under.
  ///
  /// Used by the widget layer even before (or without) a successful load, so
  /// the declaration and the renderer agree on one name.
  static String iconFamilyFor(ThemePackage theme) => _iconFamilyFor(theme);

  Future<String?> _load(
    ThemePackage theme,
    String? asset,
    String family,
  ) async {
    if (asset == null || asset.isEmpty) {
      return null;
    }
    if (_loadedFamilies.contains(family)) {
      return family;
    }
    if (_attemptedFamilies.contains(family)) {
      return null;
    }
    _attemptedFamilies.add(family);

    try {
      final bytes = await _readFontBytes(theme, asset);
      if (bytes == null || bytes.lengthInBytes > maxFontBytes) {
        return null;
      }
      final loader = FontLoader(family)..addFont(_byteStream(bytes));
      await loader.load();
      _loadedFamilies.add(family);
      return family;
    } on Object {
      // A corrupt font must degrade to the platform font, never to a broken
      // skin: this matches the parser's permissive contract.
      return null;
    }
  }

  static final Set<String> _loadedFamilies = <String>{};
  static final Set<String> _attemptedFamilies = <String>{};

  /// Deterministic family name derived from the skin id.
  ///
  /// FontLoader family names are process-global, so a skin id is used to keep
  /// two skins from colliding over the same family.
  static String _familyNameFor(ThemePackage theme) {
    return 'robyne_${_suffix(theme)}_${_safeId(theme)}';
  }

  /// Icon-font families get their own namespace.
  ///
  /// Distinct from the text family so a skin shipping one font for text and
  /// another for icons cannot accidentally register them under one name and
  /// have the second silently overwrite the first.
  ///
  /// Delegates to the package so the loader and the renderer cannot disagree
  /// about the name — computing it in both places is exactly how a shipped
  /// icon font ended up registered under a family nothing drew with.
  static String _iconFamilyFor(ThemePackage theme) =>
      theme.iconsFontFamily ??
      'robyne_${_suffix(theme)}_${_safeId(theme)}_icons';

  static String _suffix(ThemePackage theme) =>
      theme.source == ThemeSource.builtIn ? 'builtin' : 'user';

  static String _safeId(ThemePackage theme) =>
      theme.id.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');

  Future<ByteData?> _readFontBytes(ThemePackage theme, String asset) async {
    final resolver = _resolver;
    if (theme.source == ThemeSource.builtIn) {
      final path = await resolver.resolveFilePath(theme, asset);
      if (path == null) {
        return null;
      }
      final data = await rootBundle.load(path);
      if (data.lengthInBytes > maxFontBytes) {
        return null;
      }
      return data;
    }
    final path = await resolver.resolveFilePath(theme, asset);
    if (path == null) {
      return null;
    }
    final file = File(path);
    if (!await file.exists()) {
      return null;
    }
    final length = await file.length();
    if (length > maxFontBytes) {
      return null;
    }
    final bytes = await file.readAsBytes();
    return ByteData.view(
      bytes.buffer,
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    );
  }

  static Future<ByteData> _byteStream(ByteData data) async => data;
}
