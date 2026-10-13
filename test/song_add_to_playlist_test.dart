import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/theme/application/theme_providers.dart';
import 'package:robyne/features/player/domain/playback_item.dart';
import 'package:robyne/features/playlists/application/playlist_providers.dart';
import 'package:robyne/features/playlists/domain/music_playlist.dart';
import 'package:robyne/shared/widgets/song_actions_menu.dart';

import 'support/xuan_fixture.dart';

const PlaybackItem _item = PlaybackItem(
  id: 'plugin:x:A',
  type: PlaybackItemType.plugin,
  title: '测试歌曲',
  platform: 'Test',
  artist: '测试歌手',
);

void main() {
  // `showSongActionsMenu` clears its process-wide "one menu at a time" flag
  // only after `showMenu` returns; a test that leaves a menu open would
  // otherwise block the next one.
  tearDown(endSongMenu);

  testWidgets('"add to playlist" lays out and closes on pick', (tester) async {
    final controller = _FakePlaylistController();
    final container = ProviderContainer(
      overrides: [
        baseThemePackageProvider.overrideWithValue(xuanFixture()),
        playlistControllerProvider.overrideWith(() => controller),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_harness(container));
    await tester.pump();

    await _openAddToPlaylistDialog(tester);
    expect(find.text('My playlist'), findsOneWidget);

    await tester.tap(find.text('My playlist'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(controller.added, <String>['playlist:0']);
    // The dialog must be gone. A dialog whose content never lays out leaves its
    // modal barrier on screen: every frame logs a layout assertion and every
    // later tap is swallowed, so the app looks frozen.
    expect(find.text('My playlist'), findsNothing);
  });

  testWidgets('the picker lists every playlist and can be dismissed', (
    tester,
  ) async {
    // One playlist fits without scrolling; the bug this covers is the *kind* of
    // scrollable the dialog uses, so the list has to be long enough that a
    // non-scrollable column would overflow.
    final controller = _FakePlaylistController(count: 20);
    final container = ProviderContainer(
      overrides: [
        baseThemePackageProvider.overrideWithValue(xuanFixture()),
        playlistControllerProvider.overrideWith(() => controller),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_harness(container));
    await tester.pump();

    await _openAddToPlaylistDialog(tester);
    expect(find.text('Playlist 19'), findsOneWidget);

    // The liked-songs playlist is not a destination you add to by hand.
    expect(find.text('我喜欢'), findsNothing);

    await tester.tap(find.text('取消'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Playlist 19'), findsNothing);
    expect(controller.added, isEmpty);
  });
  testWidgets('the picker fits a small window', (tester) async {
    // A window this short is where a non-scrollable picker overflows: the
    // assert-free layout is the regression, not any particular pixel.
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = _FakePlaylistController(count: 20);
    final container = ProviderContainer(
      overrides: [
        baseThemePackageProvider.overrideWithValue(xuanFixture()),
        playlistControllerProvider.overrideWith(() => controller),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_harness(container));
    await tester.pump();

    await _openAddToPlaylistDialog(tester);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('取消'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Playlist 19'), findsNothing);
  });
}

Widget _harness(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      home: Scaffold(
        body: Center(child: SongActionsMenuButton(item: _item)),
      ),
    ),
  );
}

Future<void> _openAddToPlaylistDialog(WidgetTester tester) async {
  await tester.tap(find.byType(IconButton));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.text('添加到歌单'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

class _FakePlaylistController extends PlaylistController {
  _FakePlaylistController({this.count = 1});

  final int count;
  final List<String> added = <String>[];

  @override
  Future<List<MusicPlaylist>> build() async => <MusicPlaylist>[
    const MusicPlaylist(
      id: 'favorites',
      name: '我喜欢',
      isFavorites: true,
      items: <PlaybackItem>[],
    ),
    for (var index = 0; index < count; index += 1)
      MusicPlaylist(
        id: 'playlist:$index',
        name: index == 0 ? 'My playlist' : 'Playlist $index',
        isFavorites: false,
        items: const <PlaybackItem>[],
      ),
  ];

  @override
  Future<void> addItem(String playlistId, PlaybackItem item) async {
    added.add(playlistId);
  }
}
