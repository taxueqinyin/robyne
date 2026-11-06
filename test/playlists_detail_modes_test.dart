import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/theme/application/theme_providers.dart';
import 'package:robyne/core/theme/domain/theme_layout_override.dart';
import 'package:robyne/features/downloads/domain/download_audio_format.dart';
import 'package:robyne/features/player/domain/playback_item.dart';
import 'package:robyne/features/playlists/application/playlist_providers.dart';
import 'package:robyne/features/playlists/domain/music_playlist.dart';
import 'package:robyne/features/playlists/presentation/playlists_page.dart';
import 'package:robyne/features/settings/application/settings_providers.dart';
import 'package:robyne/features/settings/domain/lyric_settings.dart';
import 'package:robyne/features/settings/domain/shortcut_settings.dart';
import 'package:robyne/features/settings/domain/user_settings.dart';

import 'support/xuan_fixture.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  test(
    'playlist share text starts with identity and then one song per line',
    () {
      final text = playlistShareText(_playlist());
      expect(text.split('\n'), <String>[
        '深夜通勤',
        '深夜适合慢慢听',
        '第一首 | 歌手甲 | Test',
        '第二首 | 歌手乙 | Test',
      ]);
    },
  );

  testWidgets('detail header exposes all five actions and the metadata', (
    tester,
  ) async {
    await _pumpDetail(tester);
    expect(find.text('深夜通勤'), findsOneWidget);
    expect(find.text('深夜适合慢慢听'), findsOneWidget);
    expect(find.byKey(const Key('playlists-play-button')), findsOneWidget);
    expect(find.byKey(const Key('playlists-download-button')), findsOneWidget);
    expect(find.byKey(const Key('playlists-batch-button')), findsOneWidget);
    expect(find.byKey(const Key('playlists-share-button')), findsOneWidget);
    expect(find.byKey(const Key('playlists-edit-button')), findsOneWidget);
    expect(find.byKey(const Key('playlists-new-button')), findsNothing);
  });

  testWidgets('share opens an editable text field with every playlist song', (
    tester,
  ) async {
    await _pumpDetail(tester);
    await tester.tap(find.byKey(const Key('playlists-share-button')));
    await _pump(tester);

    final field = find.byKey(const Key('playlists-share-text'));
    expect(field, findsOneWidget);
    final controller = tester.widget<TextField>(field).controller!;
    expect(controller.text, playlistShareText(_playlist()));
    await tester.enterText(field, '${controller.text}\n自定义一行');
    expect(controller.text, contains('自定义一行'));
  });

  testWidgets('download and batch modes are distinct and can be exited', (
    tester,
  ) async {
    await _pumpDetail(tester);

    await tester.tap(find.byKey(const Key('playlists-download-button')));
    await _pump(tester);
    expect(find.byKey(const Key('playlists-download-toolbar')), findsOneWidget);
    expect(find.text('标准品质'), findsWidgets);
    expect(find.byKey(const Key('playlists-exit-download')), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNWidgets(2));

    await tester.tap(find.byKey(const Key('playlists-exit-download')));
    await _pump(tester);
    expect(find.byKey(const Key('playlists-download-toolbar')), findsNothing);

    await tester.tap(find.byKey(const Key('playlists-batch-button')));
    await _pump(tester);
    expect(find.byKey(const Key('playlists-batch-toolbar')), findsOneWidget);
    expect(find.text('已选中0首'), findsOneWidget);
    await tester.tap(find.byKey(const Key('playlists-select-all')));
    await _pump(tester);
    expect(find.text('已选中2首'), findsOneWidget);
    await tester.tap(find.byKey(const Key('playlists-exit-batch')));
    await _pump(tester);
    expect(find.byKey(const Key('playlists-batch-toolbar')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'edit saves the name, description and cover through the controller',
    (tester) async {
      final controller = _FakePlaylistController();
      await _pumpDetail(tester, controller: controller);
      await tester.tap(find.byKey(const Key('playlists-edit-button')));
      await _pump(tester);

      expect(find.byKey(const Key('playlists-edit-dialog')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('playlists-edit-name')),
        '新的名字',
      );
      await tester.enterText(
        find.byKey(const Key('playlists-edit-description')),
        '新的简介',
      );
      await tester.enterText(
        find.byKey(const Key('playlists-edit-cover')),
        'https://example.test/cover.png',
      );
      await tester.tap(find.byKey(const Key('playlists-edit-save')));
      await _pump(tester);

      expect(controller.updatedName, '新的名字');
      expect(controller.updatedDescription, '新的简介');
      expect(controller.updatedCover, 'https://example.test/cover.png');
      expect(find.byKey(const Key('playlists-edit-dialog')), findsNothing);
    },
  );

  testWidgets('batch delete removes every selected track', (tester) async {
    final controller = _FakePlaylistController();
    await _pumpDetail(tester, controller: controller);
    await tester.tap(find.byKey(const Key('playlists-batch-button')));
    await _pump(tester);
    await tester.tap(find.byKey(const Key('playlists-select-all')));
    await _pump(tester);
    await tester.tap(find.text('删除').last);
    await _pump(tester);
    await tester.tap(find.text('删除').last);
    await _pump(tester);

    expect(controller.removedGroups, hasLength(1));
    expect(controller.removedGroups.single, hasLength(2));
  });
}

Future<void> _pumpDetail(
  WidgetTester tester, {
  _FakePlaylistController? controller,
}) async {
  late ProviderContainer container;
  final playlistController = controller ?? _FakePlaylistController();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container = ProviderContainer(
        overrides: [
          baseThemePackageProvider.overrideWithValue(xuanFixture()),
          settingsControllerProvider.overrideWith(_FakeSettingsController.new),
          playlistControllerProvider.overrideWith(() => playlistController),
        ],
      ),
      child: const MaterialApp(home: Scaffold(body: PlaylistsPage())),
    ),
  );
  addTearDown(container.dispose);
  container.read(selectedPlaylistIdProvider.notifier).select('playlist:detail');
  await _pump(tester);
}

Future<void> _pump(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

MusicPlaylist _playlist() => MusicPlaylist(
  id: 'playlist:detail',
  name: '深夜通勤',
  description: '深夜适合慢慢听',
  isFavorites: false,
  items: <PlaybackItem>[
    PlaybackItem.plugin(
      platform: 'Test',
      musicId: 'A',
      title: '第一首',
      artist: '歌手甲',
      raw: const <String, Object?>{'id': 'A'},
    ),
    PlaybackItem.plugin(
      platform: 'Test',
      musicId: 'B',
      title: '第二首',
      artist: '歌手乙',
      raw: const <String, Object?>{'id': 'B'},
    ),
  ],
);

class _FakePlaylistController extends PlaylistController {
  String? updatedName;
  String? updatedDescription;
  String? updatedCover;
  final List<Set<String>> removedGroups = <Set<String>>[];

  @override
  Future<List<MusicPlaylist>> build() async => <MusicPlaylist>[_playlist()];

  @override
  Future<void> updatePlaylistInfo(
    String id, {
    required String name,
    required String description,
    String? coverUrl,
  }) async {
    updatedName = name;
    updatedDescription = description;
    updatedCover = coverUrl;
  }

  @override
  Future<void> removeItems(String playlistId, Set<String> itemIds) async {
    removedGroups.add(itemIds);
  }
}

class _FakeSettingsController extends SettingsController {
  @override
  Future<UserSettings> build() async => UserSettings(
    cacheSizeBytes: 0,
    cacheDirectoryPath: 'cache',
    downloadsDirectoryPath: 'downloads',
    downloadAudioFormat: DownloadAudioFormat.original,
    shortcuts: ShortcutSettings.defaults(),
    lyricSettings: const LyricSettings.defaults(),
    activeThemeId: 'xuan',
    themeModeOverrideName: 'system',
    themeSettingValues: const <String, Object>{},
    themeLayoutOverrides: const <String, ThemeLayoutOverride>{},
  );
}
