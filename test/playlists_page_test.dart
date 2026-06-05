import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/features/player/domain/playback_item.dart';
import 'package:robyne/features/playlists/application/playlist_providers.dart';
import 'package:robyne/features/playlists/domain/music_playlist.dart';
import 'package:robyne/features/playlists/presentation/playlists_page.dart';

void main() {
  testWidgets('creates Chinese playlists and confirms destructive actions', (
    tester,
  ) async {
    late _FakePlaylistController controller;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playlistControllerProvider.overrideWith(() {
            controller = _FakePlaylistController();
            return controller;
          }),
        ],
        child: const MaterialApp(home: Scaffold(body: PlaylistsPage())),
      ),
    );
    await _pumpUi(tester);

    await tester.tap(find.text('New playlist'));
    await _pumpUi(tester);
    await tester.enterText(find.byType(TextField), '中文歌单');
    await tester.tap(find.text('Create'));
    await _pumpUi(tester);
    expect(controller.createdNames, contains('中文歌单'));
    expect(find.text('中文歌单'), findsOneWidget);

    await tester.tap(find.text('待删歌单'));
    await _pumpUi(tester);
    await tester.tap(find.widgetWithIcon(IconButton, Icons.close).first);
    await _pumpUi(tester);
    expect(find.text('Remove track'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await _pumpUi(tester);
    expect(controller.removedItems, isEmpty);
    expect(find.text('测试歌曲'), findsOneWidget);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.close).first);
    await _pumpUi(tester);
    await tester.tap(find.text('Remove'));
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
}

Future<void> _pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
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
