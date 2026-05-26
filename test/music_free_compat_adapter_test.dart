import 'package:flutter_test/flutter_test.dart';
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
}
