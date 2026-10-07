import 'dart:convert';

import '../../../core/errors/app_error.dart';
import '../../../core/result/result.dart';

/// A single plugin source referenced by a plugin-list manifest.
class PluginListEntry {
  const PluginListEntry({required this.url, this.name});

  /// Absolute http(s) URL of a plugin JavaScript file.
  final String url;

  /// Optional human-readable label, used only for reporting.
  final String? name;

  /// What to show while this entry is being imported.
  String get label =>
      (name == null || name!.trim().isEmpty) ? url : '${name!.trim()} ($url)';
}

/// A JSON document that lists plugin URLs instead of being a plugin itself.
///
/// Real-world manifests are hand-maintained, so parsing stays deliberately
/// permissive: an object with a `plugins` array, a bare array, bare strings,
/// and the common key aliases (`url`/`src`/`link`/`path`) all parse. Entries
/// that are not absolute http(s) URLs are dropped rather than fatal, so one
/// bad row cannot sink the rest of the list.
class PluginListManifest {
  const PluginListManifest({required this.entries});

  static const _maxEntries = 200;

  final List<PluginListEntry> entries;

  bool get isEmpty => entries.isEmpty;

  int get length => entries.length;

  /// Parses [raw] as a plugin list, resolving relative URLs against [base].
  ///
  /// Returns `Ok(null)` when [raw] is not a plugin list at all, which lets
  /// callers fall through to treating the document as a plugin source.
  static Result<PluginListManifest?> parse(String raw, {Uri? base}) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || !_looksLikeJson(trimmed)) {
      return const Ok(null);
    }

    Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } catch (_) {
      return const Ok(null);
    }

    final entries = _entriesFrom(decoded, base);
    if (entries == null) {
      return const Ok(null);
    }

    return Ok(PluginListManifest(entries: entries));
  }

  static bool _looksLikeJson(String source) {
    final first = source.codeUnitAt(0);
    return first == 0x7B /* { */ || first == 0x5B /* [ */;
  }

  /// Returns null when the decoded value is not shaped like a plugin list.
  static List<PluginListEntry>? _entriesFrom(Object? decoded, Uri? base) {
    final list = switch (decoded) {
      final Map<dynamic, dynamic> map => _pluginListFromMap(map),
      final List<dynamic> list => list,
      _ => null,
    };
    if (list == null) {
      return null;
    }

    final entries = <PluginListEntry>[];
    final seen = <String>{};
    for (final item in list) {
      if (entries.length >= _maxEntries) {
        break;
      }
      final entry = _entryFrom(item, base);
      if (entry == null || !seen.add(entry.url)) {
        continue;
      }
      entries.add(entry);
    }
    return entries;
  }

  /// The array under a `plugins`-style key, or null when there is none.
  static List<dynamic>? _pluginListFromMap(Map<dynamic, dynamic> map) {
    for (final key in const <Object>[
      'plugins',
      'pluginList',
      'plugin_list',
      'list',
      'data',
      'items',
    ]) {
      final value = map[key];
      if (value is List) {
        return value;
      }
    }
    return null;
  }

  static PluginListEntry? _entryFrom(Object? item, Uri? base) {
    String? url;
    String? name;
    if (item is String) {
      url = item;
    } else if (item is Map) {
      url = _firstString(item, const <Object>[
        'url',
        'src',
        'source',
        'link',
        'path',
        'download',
        'downloadUrl',
        'download_url',
      ]);
      name = _firstString(item, const <Object>[
        'name',
        'title',
        'label',
        'platform',
      ]);
    }
    if (url == null) {
      return null;
    }

    final resolved = _resolveUrl(url, base);
    if (resolved == null) {
      return null;
    }
    return PluginListEntry(url: resolved, name: name);
  }

  static String? _firstString(Map<dynamic, dynamic> map, List<Object> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  static String? _resolveUrl(String raw, Uri? base) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final parsed = Uri.tryParse(trimmed);
    if (parsed == null) {
      return null;
    }
    Uri uri;
    try {
      uri = parsed.hasScheme || base == null ? parsed : base.resolveUri(parsed);
    } catch (_) {
      return null;
    }
    if (!uri.hasAbsolutePath ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    return uri.toString();
  }
}

/// Failure returned when a plugin-list manifest is valid but unusable.
const AppError pluginListEmptyError = AppError(
  code: 'plugin.list_empty',
  message: 'The plugin list did not contain any plugin URLs.',
);
