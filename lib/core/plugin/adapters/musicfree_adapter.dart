import 'dart:convert';

import 'package:robyne/shared/models/track.dart';
import 'package:robyne/core/plugin/plugin_models.dart';
import 'package:robyne/core/plugin/plugin_protocol.dart';
import 'package:robyne/core/plugin/plugin_registry.dart';
import 'package:robyne/core/runtime/js_runtime.dart';
import 'package:robyne/core/runtime/runtime_exceptions.dart';
import 'package:logging/logging.dart';

final _log = Logger('MusicFreeAdapter');

/// MusicFree 插件适配器
class MusicFreeAdapter implements MusicSourcePlugin, PluginInstanceHolder {
  @override
  final PluginMeta meta;

  final JsRuntime _runtime;

  @override
  String get sourcePath => _sourcePath;
  final String _sourcePath;

  @override
  PluginStatus status;

  @override
  String? errorMessage;

  MusicFreeAdapter({
    required this.meta,
    required JsRuntime runtime,
    required String sourcePath,
  })  : _runtime = runtime,
        _sourcePath = sourcePath,
        status = PluginStatus.enabled;

  /// 插件在全局命名空间中的引用名（安全标识符）
  String get _globalRef => '__plugin_${_safeIdentifier(meta.id)}';

  // ─── MusicSourcePlugin 接口实现 ───

  @override
  Future<List<RemoteTrack>> search(
    String keyword, {
    int page = 1,
    int limit = 30,
  }) async {
    _log.info('[${meta.id}] search START: keyword="$keyword" page=$page');

    try {
      // 先检查插件是否已挂载
      final checkScript = '''
(function() {
  var plugin = globalThis.$_globalRef;
  if (!plugin) return JSON.stringify({error: 'plugin not mounted', ref: '$_globalRef'});
  if (typeof plugin.search !== 'function') return JSON.stringify({error: 'search method not found', keys: Object.keys(plugin).join(',')});
  return JSON.stringify({ok: true});
})();
''';
      _log.info('[${meta.id}] search: checking plugin mount...');
      final checkResult = _runtime.evaluate(
        checkScript,
        pluginId: meta.id,
        method: 'search_check',
      );
      _log.info('[${meta.id}] search check result: $checkResult');

      // 检查结果
      final checkStr = _extractString(checkResult);
      if (checkStr != null) {
        try {
          final checkJson = jsonDecode(checkStr) as Map<String, dynamic>;
          if (checkJson.containsKey('error')) {
            _log.severe('[${meta.id}] search check FAILED: ${checkJson['error']}');
            throw PluginExecutionError(
              message: 'Plugin check failed: ${checkJson['error']}',
              pluginId: meta.id,
              method: 'search',
            );
          }
          _log.info('[${meta.id}] search check PASSED');
        } catch (e) {
          if (e is PluginExecutionError) rethrow;
          _log.warning('[${meta.id}] search check parse error: $e');
        }
      }

      // MusicFree search 签名: search(query, page, type)
      // 使用全局 Promise 回调机制，避免 evaluateAsync 无法等待嵌套 Promise
      final script = '''
(function() {
  var plugin = globalThis.$_globalRef;
  try {
    var result = plugin.search(${jsonEncode(keyword)}, $page, "music");
    if (result && typeof result.then === 'function') {
      result.then(function(r) {
        globalThis.__searchResult = JSON.stringify(r);
        globalThis.__searchDone = true;
        globalThis.__searchError = null;
      }).catch(function(e) {
        globalThis.__searchResult = null;
        globalThis.__searchDone = true;
        globalThis.__searchError = e && e.message ? e.message : String(e);
      });
    } else {
      globalThis.__searchResult = JSON.stringify(result);
      globalThis.__searchDone = true;
      globalThis.__searchError = null;
    }
  } catch(e) {
    globalThis.__searchResult = null;
    globalThis.__searchDone = true;
    globalThis.__searchError = e && e.message ? e.message : String(e);
  }
  return 'search_started';
})();
''';

      _log.info('[${meta.id}] search: executing plugin.search()...');
      final startResult = _runtime.evaluate(
        script,
        pluginId: meta.id,
        method: 'search_start',
      );
      _log.info('[${meta.id}] search: start result=$startResult');

      // 轮询等待结果（XHR 请求需要时间）
      _log.info('[${meta.id}] search: polling for result...');
      final raw = await _pollForResult(
        timeout: const Duration(seconds: 20),
        interval: const Duration(milliseconds: 200),
      );

      if (raw == null) {
        _log.warning('[${meta.id}] search: got null result');
        return [];
      }

      _log.info('[${meta.id}] search: raw result length=${raw.length}, preview=${raw.length > 200 ? raw.substring(0, 200) : raw}');

      final list = _parseResultListFromString(raw, method: 'search');
      _log.info('[${meta.id}] search: parsed ${list.length} tracks');
      return list.map(_convertToTrack).toList();
    } on PluginExecutionError {
      rethrow;
    } on RuntimeTimeoutError {
      rethrow;
    } catch (e, st) {
      _log.severe('[${meta.id}] search FAILED: $e\n$st');
      throw PluginExecutionError(
        message: 'Search failed: $e',
        pluginId: meta.id,
        method: 'search',
        stackTrace: st.toString(),
      );
    }
  }

  /// 轮询等待 JS 异步结果
  Future<String?> _pollForResult({
    required Duration timeout,
    required Duration interval,
  }) async {
    final deadline = DateTime.now().add(timeout);
    var pollCount = 0;

    while (DateTime.now().isBefore(deadline)) {
      pollCount++;
      await Future.delayed(interval);

      try {
        final pollScript = '''
(function() {
  if (!globalThis.__searchDone) return 'pending';
  if (globalThis.__searchError) return JSON.stringify({__error: globalThis.__searchError});
  return globalThis.__searchResult;
})();
''';
        final pollResult = _runtime.evaluate(
          pollScript,
          pluginId: meta.id,
          method: 'poll',
        );

        final str = _extractString(pollResult);
        if (str == null || str == 'pending' || str.isEmpty) {
          if (pollCount % 10 == 0) {
            _log.info('[${meta.id}] poll #$pollCount: still pending...');
          }
          continue;
        }

        // 清理全局变量
        _runtime.evaluate(
          'delete globalThis.__searchResult; delete globalThis.__searchDone; delete globalThis.__searchError;',
          pluginId: meta.id,
          method: 'cleanup',
        );

        // 检查是否是错误
        if (str.startsWith('{"__error":')) {
          try {
            final errorJson = jsonDecode(str) as Map<String, dynamic>;
            final errorMsg = errorJson['__error'] as String?;
            _log.severe('[${meta.id}] search JS error: $errorMsg');
            throw PluginExecutionError(
              message: 'JS error: $errorMsg',
              pluginId: meta.id,
              method: 'search',
            );
          } catch (e) {
            if (e is PluginExecutionError) rethrow;
          }
        }

        _log.info('[${meta.id}] poll #$pollCount: got result');
        return str;
      } catch (e) {
        if (e is PluginExecutionError) rethrow;
        _log.warning('[${meta.id}] poll #$pollCount error: $e');
      }
    }

    _log.severe('[${meta.id}] search TIMEOUT after ${timeout.inSeconds}s');
    throw RuntimeTimeoutError(
      timeout: timeout,
      pluginId: meta.id,
      method: 'search',
    );
  }

  @override
  Future<MediaSource> getMediaSource(RemoteTrack track) async {
    _log.info('[${meta.id}] getMediaSource: ${track.title} (${track.id})');

    try {
      final musicItem = _trackToMusicItem(track);
      final script = '''
(function() {
  var plugin = globalThis.$_globalRef;
  if (!plugin || typeof plugin.getMediaSource !== 'function') {
    return JSON.stringify({error: 'getMediaSource method not found'});
  }
  var result = plugin.getMediaSource(${jsonEncode(musicItem)}, "standard");
  if (result && typeof result.then === 'function') {
    return result.then(function(r) { return JSON.stringify(r); });
  }
  return JSON.stringify(result);
})();
''';

      final raw = await _runtime.evaluateAsync(
        script,
        pluginId: meta.id,
        method: 'getMediaSource',
        timeout: const Duration(seconds: 15),
      );

      final json = _parseSingleResult(raw, method: 'getMediaSource');
      if (json == null) {
        throw PluginExecutionError(
          message: 'getMediaSource returned null',
          pluginId: meta.id,
          method: 'getMediaSource',
        );
      }
      return MediaSource(
        url: (json['url'] ?? '') as String,
        headers: _parseHeaders(json['headers']),
        contentType: json['type'] as String?,
      );
    } on PluginExecutionError {
      rethrow;
    } on RuntimeTimeoutError {
      rethrow;
    } catch (e, st) {
      _log.warning('[${meta.id}] getMediaSource failed: $e');
      throw PluginExecutionError(
        message: 'getMediaSource failed: $e',
        pluginId: meta.id,
        method: 'getMediaSource',
        stackTrace: st.toString(),
      );
    }
  }

  @override
  Future<LyricData?> getLyric(RemoteTrack track) async {
    _log.info('[${meta.id}] getLyric: ${track.title} (${track.id})');

    try {
      final musicItem = _trackToMusicItem(track);
      final script = '''
(function() {
  var plugin = globalThis.$_globalRef;
  if (!plugin || typeof plugin.getLyric !== 'function') {
    return JSON.stringify(null);
  }
  var result = plugin.getLyric(${jsonEncode(musicItem)});
  if (result && typeof result.then === 'function') {
    return result.then(function(r) { return JSON.stringify(r); });
  }
  return JSON.stringify(result);
})();
''';

      final raw = await _runtime.evaluateAsync(
        script,
        pluginId: meta.id,
        method: 'getLyric',
        timeout: const Duration(seconds: 10),
      );

      final json = _parseSingleResult(raw, method: 'getLyric', allowNull: true);
      if (json == null) return null;

      final rawLrc = json['lrc'] as String? ?? json['lyric'] as String? ?? '';
      if (rawLrc.isEmpty) return null;

      return LyricData(
        rawLrc: rawLrc,
        lines: _parseLrcLines(rawLrc),
      );
    } on PluginExecutionError {
      rethrow;
    } on RuntimeTimeoutError {
      rethrow;
    } catch (e, st) {
      _log.warning('[${meta.id}] getLyric failed: $e');
      throw PluginExecutionError(
        message: 'getLyric failed: $e',
        pluginId: meta.id,
        method: 'getLyric',
        stackTrace: st.toString(),
      );
    }
  }

  // ─── 内部辅助方法 ───

  /// 从 JsEvalResult 或 String 中提取字符串
  String? _extractString(dynamic result) {
    if (result == null) return null;
    if (result is String) return result;
    try {
      // JsEvalResult 有 stringResult 属性
      return result.stringResult as String?;
    } catch (_) {}
    try {
      return result.toString();
    } catch (_) {
      return null;
    }
  }

  /// 将 MusicFree 歌曲 JSON 转换为 RemoteTrack
  RemoteTrack _convertToTrack(Map<String, dynamic> json) {
    return RemoteTrack(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? json['name'] as String? ?? '',
      artist: json['artist'] as String? ?? json['singer'] as String? ?? '',
      album: json['album'] as String?,
      coverUrl: json['artwork'] as String? ?? json['cover'] as String?,
      pluginId: meta.id,
    );
  }

  /// 将 RemoteTrack 转换为 MusicFree 的 musicItem 格式
  Map<String, dynamic> _trackToMusicItem(RemoteTrack track) {
    return {
      'id': track.id,
      'title': track.title,
      'artist': track.artist,
      if (track.album != null) 'album': track.album,
      if (track.coverUrl != null) 'artwork': track.coverUrl,
      'platform': meta.id,
    };
  }

  /// 从字符串解析搜索结果列表
  List<Map<String, dynamic>> _parseResultListFromString(
    String raw, {
    required String method,
  }) {
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (e) {
      _log.warning('[${meta.id}] $method: JSON parse error: $e, raw preview: ${raw.length > 100 ? raw.substring(0, 100) : raw}');
      return [];
    }

    if (decoded == null) return [];

    // 可能直接是数组
    if (decoded is List) {
      return decoded
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

    if (decoded is! Map<String, dynamic>) return [];

    // MusicFree 格式: { isEnd: bool, data: [...] }
    final list = decoded['data'] ?? decoded['result'] ?? decoded['list'];
    if (list is List) {
      return list
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

    _log.warning('[${meta.id}] $method: unexpected result format, keys: ${decoded.keys.toList()}');
    return [];
  }

  /// 解析 JS 返回的单个结果
  Map<String, dynamic>? _parseSingleResult(
    dynamic result, {
    required String method,
    bool allowNull = false,
  }) {
    final rawString = _extractString(result);
    if (rawString == null || rawString.isEmpty || rawString == 'undefined' || rawString == 'null') {
      return allowNull ? null : {};
    }

    try {
      final decoded = jsonDecode(rawString);
      if (decoded == null) return allowNull ? null : {};
      if (decoded is! Map<String, dynamic>) {
        _log.warning(
          '[${meta.id}] $method: expected Map but got ${decoded.runtimeType}',
        );
        return allowNull ? null : {};
      }
      if (decoded.containsKey('error')) {
        final errorMsg = decoded['error'];
        _log.warning('[${meta.id}] $method: JS returned error: $errorMsg');
        throw PluginExecutionError(
          message: 'JS error: $errorMsg',
          pluginId: meta.id,
          method: method,
        );
      }
      return decoded;
    } on FormatException catch (e) {
      _log.warning('[${meta.id}] $method: JSON parse error: $e');
      return allowNull ? null : {};
    }
  }

  /// 解析 headers 字段
  Map<String, String>? _parseHeaders(dynamic headers) {
    if (headers == null) return null;
    if (headers is Map) {
      return headers.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return null;
  }

  /// 解析 LRC 格式歌词
  static List<LyricLine> _parseLrcLines(String rawLrc) {
    final lines = <LyricLine>[];
    final regex = RegExp(r'\[(\d{2}):(\d{2})\.?(\d{0,3})\](.*)');

    for (final line in rawLrc.split('\n')) {
      final match = regex.firstMatch(line.trim());
      if (match == null) continue;

      final minutes = int.parse(match.group(1)!);
      final seconds = int.parse(match.group(2)!);
      final millisStr = match.group(3) ?? '0';
      final millis = millisStr.length == 3
          ? int.parse(millisStr)
          : millisStr.length == 2
              ? int.parse(millisStr) * 10
              : int.parse(millisStr) * 100;

      lines.add(LyricLine(
        timestamp: Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: millis,
        ),
        text: match.group(4)?.trim() ?? '',
      ));
    }

    return lines;
  }

  /// 将 pluginId 转为合法的 JS 标识符
  static String _safeIdentifier(String pluginId) {
    return pluginId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  }
}
