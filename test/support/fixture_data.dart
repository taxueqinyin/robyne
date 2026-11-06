import 'package:robyne/core/theme/domain/theme_layout_override.dart';
import 'package:robyne/features/discover/domain/online_collection.dart';
import 'package:robyne/features/downloads/domain/download_audio_format.dart';
import 'package:robyne/features/downloads/domain/download_task.dart';
import 'package:robyne/features/player/domain/playback_item.dart';
import 'package:robyne/features/playlists/domain/music_playlist.dart';
import 'package:robyne/features/plugin/domain/plugin_definition.dart';
import 'package:robyne/features/search/domain/music_item.dart';
import 'package:robyne/features/search/domain/search_history_entry.dart';
import 'package:robyne/features/search/domain/search_result.dart';
import 'package:robyne/features/settings/domain/lyric_settings.dart';
import 'package:robyne/features/settings/domain/shortcut_settings.dart';
import 'package:robyne/features/settings/domain/user_settings.dart';

import 'fixture_artwork.dart';

/// The data every design board renders.
///
/// Boards exist to be *looked at*, so their content has to be plausible at a
/// glance: a board of `Track 1 / Artist 1` cannot show that MiSans renders a
/// long Chinese title without clipping, or that a quality chip sits where the
/// design puts it. Real titles and albums do that for free.
///
/// Everything is const and every field is literal — no `DateTime.now()`, no
/// random, no counter — because a golden that changes between runs is not a
/// golden, it is a flake.
abstract final class FixtureData {
  /// Lin's albums, in the order they came out, so a board's list reads like a
  /// discography rather than a shuffle.
  static String? artwork(int index) => FixtureArtwork.urlFor(index);

  static PlaybackItem track(
    int index, {
    Duration? duration,
    bool lossless = false,
  }) {
    const titles = <String>[
      '江南',
      '曹操',
      '不为谁而作的歌',
      '修炼爱情',
      '学不会',
      '可惜没如果',
      '她说',
      '背对背拥抱',
    ];
    const artists = <String>[
      '林俊杰',
      '林俊杰',
      '林俊杰',
      '林俊杰',
      '林俊杰',
      '林俊杰',
      '林俊杰 / 蔡卓妍',
      '林俊杰',
    ];
    const albums = <String>[
      '第二天堂',
      '曹操',
      '和自己对话',
      '新地球',
      '学不会',
      '新地球',
      '她说',
      'JJ 陆',
    ];
    const durations = <int>[265, 243, 279, 251, 268, 288, 256, 274];
    final i = index % titles.length;
    return PlaybackItem(
      id: 'fixture-track-$index',
      type: PlaybackItemType.local,
      title: titles[i],
      artist: artists[i],
      album: albums[i],
      duration: duration ?? Duration(seconds: durations[i]),
      artworkUrl: artwork(index),
      raw: <String, Object?>{'lossless': lossless},
    );
  }

  /// Eight tracks: enough to fill a 900dp column and force a scrollbar.
  static List<PlaybackItem> get tracks => <PlaybackItem>[
    for (var i = 0; i < 8; i += 1) track(i, lossless: i % 3 == 0),
  ];

  /// What the player bar and the queue render.
  static PlaybackItem get nowPlaying => track(2);

  static List<MusicPlaylist> get playlists => <MusicPlaylist>[
    MusicPlaylist(
      id: 'fixture-liked',
      name: '我喜欢',
      isFavorites: true,
      items: <PlaybackItem>[track(0), track(3), track(5)],
    ),
    MusicPlaylist(
      id: 'fixture-playlist-1',
      name: '深夜通勤',
      isFavorites: false,
      items: <PlaybackItem>[track(1), track(4)],
    ),
    MusicPlaylist(
      id: 'fixture-playlist-2',
      name: '开车听的',
      isFavorites: false,
      items: <PlaybackItem>[track(6), track(7), track(2)],
    ),
  ];

  /// Search results from two plugins, so the page shows its source filter.
  static SearchResult get searchResult => SearchResult(
    items: <MusicItem>[for (var i = 0; i < 8; i += 1) _musicItem(i)],
    page: 1,
    isEnd: false,
  );

  static MusicItem _musicItem(int index) {
    final t = track(index);
    return MusicItem(
      id: 'fixture-search-$index',
      pluginId: 'fixture-plugin-${index % 2}',
      platform: index % 2 == 0 ? '酷我' : '咪咕',
      title: t.title,
      artist: t.artist,
      album: t.album,
      duration: t.duration,
      artworkUrl: t.artworkUrl,
      raw: const <String, Object?>{},
    );
  }

  static List<SearchHistoryEntry> get searchHistory => <SearchHistoryEntry>[
    SearchHistoryEntry(
      keyword: '林俊杰',
      searchedAt: DateTime.utc(2026, 10, 14, 9, 12),
    ),
    SearchHistoryEntry(
      keyword: '修炼爱情',
      searchedAt: DateTime.utc(2026, 10, 14, 8, 40),
    ),
    SearchHistoryEntry(
      keyword: '江南 现场',
      searchedAt: DateTime.utc(2026, 10, 13, 22, 5),
    ),
  ];

  /// Two of each unfinished state: the downloads board is the only place the
  /// progress bar, the converting spinner and the failure text appear
  /// together, and a board with one row cannot show any of them.
  static List<DownloadTask> get downloads => <DownloadTask>[
    DownloadTask(
      id: 'fixture-dl-0',
      item: track(0),
      status: DownloadStatus.downloading,
      progress: 0.42,
      createdAt: DateTime.utc(2026, 10, 14, 10, 0),
      updatedAt: DateTime.utc(2026, 10, 14, 10, 2),
    ),
    DownloadTask(
      id: 'fixture-dl-1',
      item: track(1),
      status: DownloadStatus.converting,
      progress: 1,
      createdAt: DateTime.utc(2026, 10, 14, 9, 58),
      updatedAt: DateTime.utc(2026, 10, 14, 10, 1),
    ),
    DownloadTask(
      id: 'fixture-dl-2',
      item: track(2),
      status: DownloadStatus.queued,
      progress: 0,
      createdAt: DateTime.utc(2026, 10, 14, 9, 57),
      updatedAt: DateTime.utc(2026, 10, 14, 9, 57),
    ),
    DownloadTask(
      id: 'fixture-dl-3',
      item: track(3),
      status: DownloadStatus.failed,
      progress: 0.18,
      errorMessage: '源站返回 403',
      createdAt: DateTime.utc(2026, 10, 14, 9, 50),
      updatedAt: DateTime.utc(2026, 10, 14, 9, 52),
    ),
    DownloadTask(
      id: 'fixture-dl-4',
      item: track(4),
      status: DownloadStatus.completed,
      progress: 1,
      createdAt: DateTime.utc(2026, 10, 13, 21, 30),
      updatedAt: DateTime.utc(2026, 10, 13, 21, 33),
      completedAt: DateTime.utc(2026, 10, 13, 21, 33),
    ),
    DownloadTask(
      id: 'fixture-dl-5',
      item: track(5),
      status: DownloadStatus.completed,
      progress: 1,
      createdAt: DateTime.utc(2026, 10, 13, 21, 20),
      updatedAt: DateTime.utc(2026, 10, 13, 21, 24),
      completedAt: DateTime.utc(2026, 10, 13, 21, 24),
    ),
  ];

  static List<PluginDefinition> get plugins => <PluginDefinition>[
    PluginDefinition(
      id: 'fixture-plugin-0',
      platform: '酷我',
      sourcePath: 'fixture/plugins/kuwo.js',
      enabled: true,
      version: '1.4.2',
      author: 'fixture',
      description: '搜索、榜单、热门歌单',
      supportedSearchTypes: const <String>['music', 'album', 'artist'],
      installedAt: DateTime.utc(2026, 9, 2, 14, 0),
      updatedAt: DateTime.utc(2026, 10, 1, 11, 20),
    ),
    PluginDefinition(
      id: 'fixture-plugin-1',
      platform: '咪咕',
      sourcePath: 'fixture/plugins/migu.js',
      enabled: true,
      version: '0.9.7',
      author: 'fixture',
      description: '搜索、无损音质',
      installedAt: DateTime.utc(2026, 9, 12, 20, 30),
      updatedAt: DateTime.utc(2026, 9, 28, 8, 0),
    ),
    PluginDefinition(
      id: 'fixture-plugin-2',
      platform: '酷狗',
      sourcePath: 'fixture/plugins/kugou.js',
      enabled: false,
      version: '2.0.1',
      author: 'fixture',
      description: '搜索、歌词',
      installedAt: DateTime.utc(2026, 8, 20, 17, 45),
      updatedAt: DateTime.utc(2026, 8, 20, 17, 45),
    ),
    PluginDefinition(
      id: 'fixture-plugin-3',
      platform: '网易云',
      sourcePath: 'fixture/plugins/ncm.js',
      enabled: true,
      version: '1.1.0',
      author: 'fixture',
      description: '需要 Cookie 才能使用无损',
      userVariables: const <Map<String, Object?>>[
        <String, Object?>{'key': 'cookie', 'name': 'Cookie'},
      ],
      userVariableValues: const <String, String>{'cookie': ''},
      installedAt: DateTime.utc(2026, 10, 8, 13, 10),
      updatedAt: DateTime.utc(2026, 10, 8, 13, 10),
    ),
  ];

  /// The discovery shelves the home page composes: two ranking groups and a
  /// row of hot playlists, which is the minimum that exercises `banner`,
  /// `grid` and `card` in one board.
  static List<OnlineCollectionGroup> get topListGroups =>
      <OnlineCollectionGroup>[
        OnlineCollectionGroup(
          title: '排行榜',
          items: <OnlineCollectionItem>[
            _collection(0, '热歌榜', OnlineCollectionKind.topList),
            _collection(1, '新歌榜', OnlineCollectionKind.topList),
            _collection(2, '飙升榜', OnlineCollectionKind.topList),
            _collection(3, '原创榜', OnlineCollectionKind.topList),
          ],
        ),
        OnlineCollectionGroup(
          title: '全球榜',
          items: <OnlineCollectionItem>[
            _collection(4, 'Billboard 榜', OnlineCollectionKind.topList),
            _collection(5, 'UK 榜', OnlineCollectionKind.topList),
          ],
        ),
      ];

  static List<OnlineCollectionItem> get hotPlaylists => <OnlineCollectionItem>[
    _collection(0, '华语流行精选', OnlineCollectionKind.musicSheet),
    _collection(1, '深夜单曲循环', OnlineCollectionKind.musicSheet),
    _collection(2, '开车必备', OnlineCollectionKind.musicSheet),
    _collection(3, '雨天听的歌', OnlineCollectionKind.musicSheet),
    _collection(4, '咖啡店氛围', OnlineCollectionKind.musicSheet),
    _collection(5, '通勤十分钟', OnlineCollectionKind.musicSheet),
  ];

  static OnlineCollectionItem _collection(
    int index,
    String title,
    OnlineCollectionKind kind,
  ) {
    return OnlineCollectionItem(
      id: 'fixture-collection-$index',
      pluginId: 'fixture-plugin-0',
      platform: '酷我',
      kind: kind,
      title: title,
      description: '由插件提供 · 每周更新',
      artworkUrl: artwork(index),
      raw: const <String, Object?>{},
    );
  }

  static List<PlaybackHistoryEntry> get history => <PlaybackHistoryEntry>[
    for (var i = 0; i < 6; i += 1)
      PlaybackHistoryEntry(
        item: track(i),
        playedAt: DateTime.utc(2026, 10, 14, 10, 30 - i),
      ),
  ];

  /// Settings with paths and sizes a real user would have, so the general tab
  /// does not read as an empty form.
  static UserSettings get settings => UserSettings(
    cacheSizeBytes: 2 * 1024 * 1024 * 1024,
    cacheDirectoryPath: r'C:\Users\robyne\AppData\Roaming\robyne\cache',
    downloadsDirectoryPath: r'D:\Music\Robyne',
    downloadAudioFormat: DownloadAudioFormat.mp3,
    shortcuts: ShortcutSettings.defaults(),
    lyricSettings: const LyricSettings.defaults(),
    activeThemeId: 'xuan',
    themeModeOverrideName: 'dark',
    themeSettingValues: const <String, Object>{},
    themeLayoutOverrides: const <String, ThemeLayoutOverride>{},
  );
}
