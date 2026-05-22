import 'package:robyne/shared/models/track.dart';
import 'package:robyne/core/metadata/local_scanner.dart';
import 'package:logging/logging.dart';

final _log = Logger('LocalMusicService');

/// 本地音乐应用服务 - 管理本地音乐扫描与缓存
class LocalMusicService {
  final LocalScanner _scanner;
  List<LocalTrack> _tracks = [];

  LocalMusicService(this._scanner);

  /// 当前已扫描的本地曲目（不可变视图）
  List<LocalTrack> get tracks => List.unmodifiable(_tracks);

  /// 扫描指定目录下的本地音乐文件
  Future<List<LocalTrack>> scanDirectory(String path) async {
    _log.info('Scanning directory: $path');

    try {
      _tracks = await _scanner.scanDirectory(path);
      _log.info('Scan completed: ${_tracks.length} tracks found');
      return _tracks;
    } catch (e) {
      _log.severe('Failed to scan directory $path: $e');
      rethrow;
    }
  }
}
