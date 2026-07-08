import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/features/discover/domain/online_collection.dart';
import 'package:robyne/features/plugin/infrastructure/music_free_compat_adapter.dart';

void main() {
  test('adapts MusicFree data search result into internal music items', () {
    final adapter = MusicFreeCompatAdapter();

    final result = adapter.searchResultFromPluginValue(
      <String, Object?>{
        'isEnd': true,
        'data': <Object?>[
          <String, Object?>{
            'id': 'song-1',
            'title': 'Track',
            'artist': 'Artist',
            'album': 'Album',
            'duration': 180,
            'artwork': 'https://example.com/a.jpg',
          },
        ],
      },
      pluginId: 'plugin:test',
      platform: 'demo',
      page: 1,
    );

    final searchResult = result.fold((value) => value, (error) => throw error);
    expect(searchResult.isEnd, isTrue);
    expect(searchResult.items, hasLength(1));
    expect(searchResult.items.first.title, 'Track');
    expect(searchResult.items.first.raw['id'], 'song-1');
  });

  test('adapts plugin media source and preserves headers', () {
    final adapter = MusicFreeCompatAdapter();

    final result = adapter.mediaSourceFromPluginValue(<String, Object?>{
      'url': 'http://example.com/audio.flac',
      'quality': 'standard',
      'headers': <String, Object?>{
        'User-Agent': 'Robyne',
        'Referer': 'https://example.com',
      },
    });

    final source = result.fold((value) => value, (error) => throw error);
    expect(source.url, 'http://example.com/audio.flac');
    expect(source.quality, 'standard');
    expect(source.headers['User-Agent'], 'Robyne');
  });

  test('adapts top list groups and ranking detail', () {
    final adapter = MusicFreeCompatAdapter();

    final groupsResult = adapter.topListGroupsFromPluginValue(
      <Object?>[
        <String, Object?>{
          'title': 'Official',
          'data': <Object?>[
            <String, Object?>{
              'id': 'top-1',
              'title': 'Top 50',
              'coverImg': 'https://example.com/top.jpg',
            },
          ],
        },
      ],
      pluginId: 'plugin:test',
      platform: 'Test',
    );

    final groups = groupsResult.fold((value) => value, (error) => throw error);
    expect(groups.single.title, 'Official');
    expect(groups.single.items.single.kind, OnlineCollectionKind.topList);

    final detailResult = adapter.collectionDetailFromPluginValue(
      <String, Object?>{
        'musicList': <Object?>[
          <String, Object?>{'id': 'song-1', 'title': 'Track'},
        ],
        'topListItem': <String, Object?>{
          'id': 'top-1',
          'title': 'Top 50',
          'description': 'Fresh every day',
        },
      },
      collection: groups.single.items.single,
      page: 1,
      assumeComplete: true,
    );

    final detail = detailResult.fold((value) => value, (error) => throw error);
    expect(detail.collection.description, 'Fresh every day');
    expect(detail.items.single.title, 'Track');
    expect(detail.isEnd, isTrue);
  });

  test('adapts recommend sheet tags, sheets, and paged sheet detail', () {
    final adapter = MusicFreeCompatAdapter();

    final tagsResult = adapter.recommendSheetTagsFromPluginValue(
      <String, Object?>{
        'pinned': <Object?>[
          <String, Object?>{'id': 'mood', 'title': 'Mood'},
        ],
        'data': <Object?>[
          <String, Object?>{
            'title': 'Scenes',
            'data': <Object?>[
              <String, Object?>{'id': 'work', 'title': 'Work'},
            ],
          },
        ],
      },
    );

    final tags = tagsResult.fold((value) => value, (error) => throw error);
    expect(tags.pinned.single.title, 'Mood');
    expect(tags.groups.single.tags.single.title, 'Work');

    final sheetPageResult = adapter.musicSheetPageFromPluginValue(
      <String, Object?>{
        'page': 1,
        'isEnd': false,
        'data': <Object?>[
          <String, Object?>{
            'id': 'sheet-1',
            'title': 'Late Night',
            'artist': 'Editor',
          },
        ],
      },
      pluginId: 'plugin:test',
      platform: 'Test',
      page: 1,
    );

    final sheetPage = sheetPageResult.fold(
      (value) => value,
      (error) => throw error,
    );
    expect(sheetPage.items.single.kind, OnlineCollectionKind.musicSheet);
    expect(sheetPage.items.single.description, 'Editor');

    final detailResult = adapter.collectionDetailFromPluginValue(
      <String, Object?>{
        'page': 2,
        'isEnd': true,
        'musicList': <Object?>[
          <String, Object?>{'id': 'song-2', 'title': 'Second Track'},
        ],
      },
      collection: sheetPage.items.single,
      page: 2,
    );

    final detail = detailResult.fold((value) => value, (error) => throw error);
    expect(detail.page, 2);
    expect(detail.items.single.title, 'Second Track');
    expect(detail.isEnd, isTrue);
  });
}
