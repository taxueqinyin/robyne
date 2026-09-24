import 'package:path/path.dart' as p;

/// Path hardening for skin data.
///
/// Skins are pure data, but the strings they carry become **file system
/// paths** (asset references, package ids). A skin must never be able to
/// address anything outside its own directory. Every join point in the
/// theme pipeline goes through these helpers so the guarantee lives in one
/// place instead of being re-derived (and forgotten) at each call site.
class ThemePathGuard {
  const ThemePathGuard._();

  /// Longest id we accept; keeps directory names sane on every platform.
  static const int maxIdLength = 64;

  /// Longest asset reference we accept.
  static const int maxAssetLength = 256;

  /// Turns an untrusted id into a single safe path segment.
  ///
  /// [fallbackId] is used when the id carries no usable characters, so a
  /// skin with `"id": ".."` or `"id": "///"` still installs somewhere
  /// harmless instead of resolving to its parent directory.
  static String sanitizeId(String id, {String fallbackId = 'theme'}) {
    var cleaned = id.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

    // Any run of two or more dots can only ever exist to traverse, since a
    // real id never needs `..`, `...` and friends.
    cleaned = cleaned.replaceAll(RegExp(r'\.{2,}'), '_');
    cleaned = cleaned.replaceAll(RegExp(r'^\.+'), '').trim();

    if (cleaned.isEmpty || cleaned == '.' || cleaned == '-') {
      cleaned = _orFallback(fallbackId);
    }
    if (cleaned.length > maxIdLength) {
      cleaned = cleaned.substring(0, maxIdLength);
    }
    return cleaned;
  }

  /// Maps a theme id to the directory name it is stored under.
  ///
  /// Built-in skins live in `assets/themes/` and user skins in the support
  /// directory, but **both must use the same id -> directory mapping** or a
  /// skin copied from one source to the other loses its assets. Historically
  /// the built-in resolver used `id.replaceAll('.', '-')` while the user
  /// repository used [sanitizeId] verbatim, so `official.dark` resolved to
  /// two different directories depending on where it was loaded from.
  ///
  /// Normalising through [sanitizeId] first keeps every existing guarantee
  /// (no traversal, no absolute paths), and the single `.` -> `-` pass keeps
  /// asset-flavoured names consistent with the shipped bundle directories.
  static String directoryName(String id, {String fallbackId = 'theme'}) {
    return sanitizeId(id, fallbackId: fallbackId).replaceAll('.', '-');
  }

  static String _orFallback(String fallbackId) {
    final cleaned = fallbackId.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    if (cleaned.isEmpty || cleaned == '.') {
      return 'theme';
    }
    return cleaned;
  }

  /// Validates a skin-declared asset reference such as `assets/bg.webp`.
  ///
  /// Returns `null` for anything that could escape the skin directory:
  /// parent traversals, absolute paths, drive letters and UNC shares. A UNC
  /// reference would make Windows open an SMB connection and leak the
  /// user's credentials, so it is rejected outright.
  static String? sanitizeAsset(String? asset) {
    final normalized = asset?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    if (normalized.length > maxAssetLength) {
      return null;
    }
    // UNC (`\\host\share`) and device paths never resolve inside a skin.
    if (normalized.startsWith(r'\\') || normalized.startsWith('//')) {
      return null;
    }
    final unix = normalized.replaceAll(r'\', '/');
    if (p.posix.isAbsolute(unix) || p.isAbsolute(normalized)) {
      return null;
    }
    final candidate = p.posix.normalize(unix);
    if (candidate == '.' || candidate.isEmpty) {
      return null;
    }
    final segments = p.posix.split(candidate);
    if (segments.contains('..')) {
      return null;
    }
    return candidate;
  }

  /// Resolves [asset] inside [rootDir], or `null` when it would escape.
  ///
  /// This is the belt to [sanitizeAsset]'s braces: it re-checks the fully
  /// joined path, so a future caller that forgets the first step still
  /// cannot write outside [rootDir].
  static String? resolveWithin(
    String rootDir,
    String? asset, {
    Future<bool> Function(String path)? exists,
  }) {
    final safe = sanitizeAsset(asset);
    if (safe == null) {
      return null;
    }
    final target = p.join(rootDir, p.joinAll(p.posix.split(safe)));
    if (!isWithin(rootDir, target)) {
      return null;
    }
    return target;
  }

  /// True when [target] is [rootDir] itself or lives underneath it.
  ///
  /// Compares canonical paths so `..`, symlinks and mixed separators cannot
  /// slip through a plain string prefix check.
  static bool isWithin(String rootDir, String target) {
    final root = p.canonicalize(rootDir);
    final resolved = p.canonicalize(target);
    if (resolved == root) {
      return true;
    }
    return p.isWithin(root, resolved);
  }

  /// Validates a relative path taken from an archive entry name.
  ///
  /// Returns `null` for absolute entries and for any entry that climbs out
  /// of the extraction root (Zip Slip).
  static String? sanitizeArchiveEntry(String name) {
    if (name.isEmpty) {
      return null;
    }
    if (name.length > maxAssetLength) {
      return null;
    }
    if (name.startsWith(r'\\') || name.startsWith('//')) {
      return null;
    }
    final unix = name.replaceAll(r'\', '/');
    if (p.posix.isAbsolute(unix) || p.isAbsolute(name)) {
      return null;
    }
    final normalized = p.posix.normalize(unix);
    if (normalized.isEmpty || normalized == '.') {
      return null;
    }
    if (p.posix.split(normalized).contains('..')) {
      return null;
    }
    return normalized;
  }
}
