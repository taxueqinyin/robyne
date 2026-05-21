import 'dart:convert';

import 'package:robyne/core/js_sandbox/sandbox_manager.dart';
import 'package:robyne/core/plugin/plugin_models.dart';

class PluginExecutor {
  final SandboxManager _sandbox;

  PluginExecutor(this._sandbox);

  Future<List<SearchResult>> search(
    String pluginName,
    String query, {
    int page = 1,
    String type = 'song',
  }) async {
    final result = await _sandbox.callPluginMethod(
      pluginName,
      'search',
      [query, page, type],
    );

    if (result == null) return [];

    final json = jsonDecode(result.toString()) as Map<String, dynamic>;
    final data = json['data'] as List? ?? [];

    return data
        .map((item) => SearchResult.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<MediaSource?> getMediaSource(
    String pluginName,
    Map<String, dynamic> musicItem,
  ) async {
    final result = await _sandbox.callPluginMethod(
      pluginName,
      'getMediaSource',
      [musicItem],
    );

    if (result == null) return null;

    final json = jsonDecode(result.toString()) as Map<String, dynamic>;
    if (json['url'] == null) return null;

    return MediaSource.fromJson(json);
  }

  Future<LyricResult?> getLyric(
    String pluginName,
    Map<String, dynamic> musicItem,
  ) async {
    final result = await _sandbox.callPluginMethod(
      pluginName,
      'getLyric',
      [musicItem],
    );

    if (result == null) return null;

    final json = jsonDecode(result.toString()) as Map<String, dynamic>;
    return LyricResult.fromJson(json);
  }

  Future<AlbumInfo?> getAlbumInfo(
    String pluginName,
    Map<String, dynamic> albumItem,
  ) async {
    try {
      final result = await _sandbox.callPluginMethod(
        pluginName,
        'getAlbumInfo',
        [albumItem],
      );

      if (result == null) return null;

      final json = jsonDecode(result.toString()) as Map<String, dynamic>;
      final musicList = (json['musicList'] as List?)
              ?.map((item) => SearchResult.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [];

      return AlbumInfo(
        musicList: musicList,
        description: json['description'] as String?,
        cover: json['cover'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}
