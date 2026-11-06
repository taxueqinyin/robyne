import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/features/player/domain/playback_item.dart';
import 'package:robyne/features/playlists/application/playlist_providers.dart';
import 'package:robyne/features/playlists/domain/music_playlist.dart';
import 'package:robyne/features/playlists/presentation/playlists_page.dart';

void main() {
  test('overview and liked are distinct selections', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(selectedPlaylistIdProvider.notifier);

    expect(container.read(selectedPlaylistIdProvider), isNull);
    notifier.showOverview();
    expect(container.read(selectedPlaylistIdProvider), overviewPlaylistId);
    notifier.select('playlist:one');
    expect(container.read(selectedPlaylistIdProvider), 'playlist:one');
    notifier.showLiked();
    expect(container.read(selectedPlaylistIdProvider), isNull);
    notifier.showCollections();
    expect(
      container.read(selectedPlaylistIdProvider),
      overviewCollectionsPlaylistId,
    );
  });

  testWidgets('owned and saved playlists render in separate tabs', (
    tester,
  ) async {
    late ProviderContainer container;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container = ProviderContainer(
          overrides: [
            playlistControllerProvider.overrideWith(
              _ClassifiedPlaylistController.new,
            ),
          ],
        ),
        child: const MaterialApp(home: Scaffold(body: PlaylistsPage())),
      ),
    );
    addTearDown(container.dispose);

    container.read(selectedPlaylistIdProvider.notifier).showOverview();
    await _pumpUi(tester);
    expect(find.text('Created playlist'), findsOneWidget);
    expect(find.text('Saved playlist'), findsNothing);

    await tester.tap(find.text('Saved'));
    await _pumpUi(tester);
    expect(find.text('Created playlist'), findsNothing);
    expect(find.text('Saved playlist'), findsOneWidget);
  });

  testWidgets(
    'the section switch selects one tab and keeps 新建歌单 in the corner',
    (tester) async {
      late ProviderContainer container;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container = ProviderContainer(
            overrides: [
              playlistControllerProvider.overrideWith(
                _ClassifiedPlaylistController.new,
              ),
            ],
          ),
          child: const MaterialApp(home: Scaffold(body: PlaylistsPage())),
        ),
      );
      addTearDown(container.dispose);

      Color? tabFill(String key) {
        final tab = tester.widget<Container>(find.byKey(Key(key)));
        return (tab.decoration! as BoxDecoration).color;
      }

      container.read(selectedPlaylistIdProvider.notifier).showOverview();
      await _pumpUi(tester);

      final ownedSelectedFill = tabFill('playlists-tab-owned');
      final savedUnselectedFill = tabFill('playlists-tab-collections');
      expect(ownedSelectedFill, isNot(savedUnselectedFill));

      // 新建歌单 is a corner affordance: right of the title and above the
      // section switch, never a full-width row of its own.
      final button = find.byKey(const Key('playlists-new-button'));
      expect(button, findsOneWidget);
      final buttonRect = tester.getRect(button);
      expect(
        buttonRect.center.dx,
        greaterThan(tester.getRect(find.text('Playlists')).center.dx),
      );
      expect(
        buttonRect.bottom,
        lessThan(
          tester.getRect(find.byKey(const Key('playlists-tab-owned'))).top,
        ),
      );

      await tester.tap(find.text('Saved'));
      await _pumpUi(tester);
      expect(find.text('Saved playlist'), findsOneWidget);
      // Exactly one tab owns the selected fill, and the created tab does not
      // keep it while the saved section is on screen.
      expect(tabFill('playlists-tab-owned'), savedUnselectedFill);
      expect(tabFill('playlists-tab-collections'), ownedSelectedFill);
      expect(tester.getRect(button), buttonRect);

      await tester.tap(find.text('Created'));
      await _pumpUi(tester);
      expect(tabFill('playlists-tab-owned'), ownedSelectedFill);
      expect(tabFill('playlists-tab-collections'), savedUnselectedFill);
    },
  );

  testWidgets('a phone header keeps 新建歌单 compact and right aligned', (
    tester,
  ) async {
    tester.view.physicalSize =
        const Size(400, 800) * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    late ProviderContainer container;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container = ProviderContainer(
          overrides: [
            playlistControllerProvider.overrideWith(
              _ClassifiedPlaylistController.new,
            ),
          ],
        ),
        child: const MaterialApp(home: Scaffold(body: PlaylistsPage())),
      ),
    );
    addTearDown(container.dispose);
    container.read(selectedPlaylistIdProvider.notifier).showOverview();
    await _pumpUi(tester);

    final pageWidth = tester.getSize(find.byType(PlaylistsPage)).width;
    final buttonRect = tester.getRect(
      find.byKey(const Key('playlists-new-button')),
    );
    // The compact branch used to stretch the button across the content
    // column; it stays sized to its label and pinned to the right gutter.
    // (Sizes here come from the test font, so the check is relative to the
    // page rather than a literal width.)
    expect(buttonRect.width, lessThan(pageWidth * 0.8));
    expect(buttonRect.right, greaterThan(pageWidth - 40));
    expect(
      buttonRect.bottom,
      lessThan(
        tester.getRect(find.byKey(const Key('playlists-tab-owned'))).top,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone liked view links to the full playlist overview', (
    tester,
  ) async {
    tester.view.physicalSize =
        const Size(400, 800) * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    late ProviderContainer container;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container = ProviderContainer(
          overrides: [
            playlistControllerProvider.overrideWith(
              _ClassifiedPlaylistController.new,
            ),
          ],
        ),
        child: const MaterialApp(home: Scaffold(body: PlaylistsPage())),
      ),
    );
    addTearDown(container.dispose);
    await _pumpUi(tester);

    expect(find.byKey(const Key('playlists-all-entry')), findsOneWidget);
    await tester.tap(find.byKey(const Key('playlists-all-entry')));
    await _pumpUi(tester);

    expect(container.read(selectedPlaylistIdProvider), overviewPlaylistId);
    expect(find.text('Created playlist'), findsOneWidget);
  });

  testWidgets('creates Chinese playlists and confirms destructive actions', (
    tester,
  ) async {
    late _FakePlaylistController controller;
    late ProviderContainer container;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container = ProviderContainer(
          overrides: [
            playlistControllerProvider.overrideWith(() {
              controller = _FakePlaylistController();
              return controller;
            }),
          ],
        ),
        child: const MaterialApp(home: Scaffold(body: PlaylistsPage())),
      ),
    );
    addTearDown(container.dispose);
    await _pumpUi(tester);

    // The default destination is liked songs. Creating belongs to the
    // playlist overview, so go back to the list before using the button.
    container.read(selectedPlaylistIdProvider.notifier).showOverview();
    await _pumpUi(tester);

    await tester.tap(find.text('New playlist'));
    await _pumpUi(tester);
    await tester.enterText(find.byType(TextField), '中文歌单');
    await tester.tap(find.text('Create'));
    await _pumpUi(tester);
    expect(controller.createdNames, contains('中文歌单'));
    container.read(selectedPlaylistIdProvider.notifier).select('playlist:1');
    await _pumpUi(tester);
    expect(find.text('中文歌单'), findsOneWidget);

    container
        .read(selectedPlaylistIdProvider.notifier)
        .select('playlist:delete');
    await _pumpUi(tester);
    await tester.tap(find.text('待删歌单'));
    await _pumpUi(tester);
    // The row actions are mouse-hover affordances. Re-adding is the undo.
    await _hoverTrack(tester, const ValueKey<String>('track-plugin:Test:A'));
    await tester.tap(
      find.widgetWithIcon(IconButton, Icons.remove_circle_outline).first,
    );
    await _pumpUi(tester);
    expect(controller.removedItems, contains('plugin:Test:A'));

    await tester.tap(
      find.widgetWithIcon(IconButton, Icons.delete_outline).first,
    );
    await _pumpUi(tester);
    expect(find.text('Delete playlist'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await _pumpUi(tester);
    expect(controller.deletedPlaylistIds, isEmpty);

    await tester.tap(
      find.widgetWithIcon(IconButton, Icons.delete_outline).first,
    );
    await _pumpUi(tester);
    await tester.tap(find.text('Delete'));
    await _pumpUi(tester);
    expect(controller.deletedPlaylistIds, contains('playlist:delete'));
  });

  testWidgets('track remove and more buttons reveal on mouse hover', (
    tester,
  ) async {
    late ProviderContainer container;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container = ProviderContainer(
          overrides: [
            playlistControllerProvider.overrideWith(
              _TrackActionsController.new,
            ),
          ],
        ),
        child: const MaterialApp(home: Scaffold(body: PlaylistsPage())),
      ),
    );
    addTearDown(container.dispose);
    container
        .read(selectedPlaylistIdProvider.notifier)
        .select('playlist:track-actions');
    await _pumpUi(tester);

    final track = find.byKey(const ValueKey<String>('track-plugin:Test:A'));
    final remove = find.widgetWithIcon(IconButton, Icons.remove_circle_outline);
    final more = find.widgetWithIcon(IconButton, Icons.more_horiz);
    expect(track, findsOneWidget);
    expect(remove, findsNothing);
    expect(more, findsNothing);

    final mouse = await _hoverTrack(
      tester,
      const ValueKey<String>('track-plugin:Test:A'),
    );
    expect(remove, findsOneWidget);
    expect(more, findsOneWidget);
    await tester.tap(remove);
    await _pumpUi(tester);

    await mouse.removePointer();
    await tester.pump();
    expect(remove, findsNothing);
    expect(more, findsNothing);
  });

  testWidgets('track actions stay visible for keyboard focus', (tester) async {
    late ProviderContainer container;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container = ProviderContainer(
          overrides: [
            playlistControllerProvider.overrideWith(
              _TrackActionsController.new,
            ),
          ],
        ),
        child: const MaterialApp(home: Scaffold(body: PlaylistsPage())),
      ),
    );
    addTearDown(container.dispose);
    container
        .read(selectedPlaylistIdProvider.notifier)
        .select('playlist:track-actions');
    await _pumpUi(tester);

    final remove = find.widgetWithIcon(IconButton, Icons.remove_circle_outline);
    final more = find.widgetWithIcon(IconButton, Icons.more_horiz);
    final row = find.descendant(
      of: find.byKey(const ValueKey<String>('track-plugin:Test:A')),
      matching: find.byType(InkWell),
    );
    expect(remove, findsNothing);
    expect(more, findsNothing);

    tester.widget<InkWell>(row.first).focusNode?.requestFocus();
    await _pumpUi(tester);
    expect(remove, findsOneWidget);
    expect(more, findsOneWidget);
  });

  testWidgets('a selected playlist keeps its selected fill while hovered', (
    tester,
  ) async {
    late ProviderContainer container;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container = ProviderContainer(
          overrides: [
            playlistControllerProvider.overrideWith(
              _SelectedPlaylistController.new,
            ),
          ],
        ),
        child: const MaterialApp(home: Scaffold(body: PlaylistsPage())),
      ),
    );
    addTearDown(container.dispose);
    container
        .read(selectedPlaylistIdProvider.notifier)
        .select('playlist:selected');
    await _pumpUi(tester);

    final card = find.byKey(
      const ValueKey<String>('selected-playlist-playlist:selected'),
    );
    expect(card, findsOneWidget);
    final before =
        (tester.widget<Container>(card).decoration as BoxDecoration).color;

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(card));
    await tester.pump();
    final hovered =
        (tester.widget<Container>(card).decoration as BoxDecoration).color;
    expect(hovered, before);
    await mouse.removePointer();
  });
}

Future<void> _pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Future<TestGesture> _hoverTrack(WidgetTester tester, Key trackKey) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: tester.getCenter(find.byKey(trackKey)));
  await tester.pump();
  return gesture;
}

class _FakePlaylistController extends PlaylistController {
  _FakePlaylistController()
    : _item = PlaybackItem.plugin(
        platform: 'Test',
        musicId: 'A',
        title: '测试歌曲',
        raw: const <String, Object?>{'id': 'A'},
      );

  final PlaybackItem _item;
  final List<String> createdNames = <String>[];
  final List<String> deletedPlaylistIds = <String>[];
  final List<String> removedItems = <String>[];

  late final List<MusicPlaylist> _playlists = <MusicPlaylist>[
    const MusicPlaylist(
      id: 'favorites',
      name: '我喜欢',
      isFavorites: true,
      items: <PlaybackItem>[],
    ),
    MusicPlaylist(
      id: 'playlist:delete',
      name: '待删歌单',
      isFavorites: false,
      items: <PlaybackItem>[_item],
    ),
  ];

  @override
  Future<List<MusicPlaylist>> build() async => _snapshot();

  @override
  Future<void> createPlaylist(String name) async {
    final playlistName = name.trim().isEmpty ? 'New playlist' : name.trim();
    createdNames.add(playlistName);
    _playlists.add(
      MusicPlaylist(
        id: 'playlist:${createdNames.length}',
        name: playlistName,
        isFavorites: false,
        items: const <PlaybackItem>[],
      ),
    );
    state = AsyncData(_snapshot());
  }

  @override
  Future<void> deletePlaylist(String id) async {
    deletedPlaylistIds.add(id);
    _playlists.removeWhere((playlist) => playlist.id == id);
    state = AsyncData(_snapshot());
  }

  @override
  Future<void> removeItem(String playlistId, String itemId) async {
    removedItems.add(itemId);
    final index = _playlists.indexWhere(
      (playlist) => playlist.id == playlistId,
    );
    if (index < 0) {
      return;
    }
    final playlist = _playlists[index];
    _playlists[index] = MusicPlaylist(
      id: playlist.id,
      name: playlist.name,
      isFavorites: playlist.isFavorites,
      items: playlist.items
          .where((playlistItem) => playlistItem.id != itemId)
          .toList(growable: false),
    );
    state = AsyncData(_snapshot());
  }

  List<MusicPlaylist> _snapshot() => List<MusicPlaylist>.unmodifiable(
    _playlists.map(
      (playlist) => MusicPlaylist(
        id: playlist.id,
        name: playlist.name,
        isFavorites: playlist.isFavorites,
        items: List<PlaybackItem>.unmodifiable(playlist.items),
      ),
    ),
  );
}

class _SelectedPlaylistController extends PlaylistController {
  @override
  Future<List<MusicPlaylist>> build() async => const <MusicPlaylist>[
    MusicPlaylist(
      id: 'playlist:selected',
      name: 'Selected playlist',
      isFavorites: false,
      items: <PlaybackItem>[],
    ),
  ];
}

class _ClassifiedPlaylistController extends PlaylistController {
  @override
  Future<List<MusicPlaylist>> build() async => const <MusicPlaylist>[
    MusicPlaylist(
      id: 'playlist:owned',
      name: 'Created playlist',
      isFavorites: false,
      items: <PlaybackItem>[],
    ),
    MusicPlaylist(
      id: 'collection:saved',
      name: 'Saved playlist',
      isFavorites: false,
      items: <PlaybackItem>[],
    ),
  ];
}

class _TrackActionsController extends PlaylistController {
  @override
  Future<List<MusicPlaylist>> build() async => <MusicPlaylist>[
    MusicPlaylist(
      id: 'playlist:track-actions',
      name: 'Track actions',
      isFavorites: false,
      items: <PlaybackItem>[
        PlaybackItem.plugin(
          platform: 'Test',
          musicId: 'A',
          title: '测试歌曲',
          raw: const <String, Object?>{'id': 'A'},
        ),
      ],
    ),
  ];

  @override
  Future<void> removeItem(String playlistId, String itemId) async {
    state = AsyncData(
      (state.value ?? const <MusicPlaylist>[])
          .map(
            (playlist) => playlist.id == playlistId
                ? playlist.copyWith(
                    items: playlist.items
                        .where((item) => item.id != itemId)
                        .toList(growable: false),
                  )
                : playlist,
          )
          .toList(growable: false),
    );
  }
}
