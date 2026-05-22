import 'package:robyne/shared/models/track.dart';
import 'package:robyne/core/plugin/plugin_models.dart';

/// 统一插件协议
abstract class MusicSourcePlugin {
  /// 插件元信息
  PluginMeta get meta;

  /// 搜索歌曲
  Future<List<RemoteTrack>> search(String keyword, {int page = 1, int limit = 30});

  /// 获取播放源
  Future<MediaSource> getMediaSource(RemoteTrack track);

  /// 获取歌词（可选）
  Future<LyricData?> getLyric(RemoteTrack track);
}
