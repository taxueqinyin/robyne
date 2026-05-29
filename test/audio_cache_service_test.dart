import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/result/result.dart';
import 'package:robyne/core/storage/local_file_store.dart';
import 'package:robyne/features/player/domain/media_source.dart';
import 'package:robyne/features/player/domain/playback_item.dart';
import 'package:robyne/features/player/infrastructure/local_audio_cache_service.dart';

void main() {
  test('returns cached media source before the remote source', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'robyne_cache_hit_test_',
    );
    addTearDown(() async {
      await tempDirectory.delete(recursive: true);
    });
    final downloader = _FakeAudioDownloader(<int>[1, 2, 3]);
    final cache = LocalAudioCacheService(
      fileStore: LocalFileStore(baseDirectory: tempDirectory),
      downloader: downloader,
      maxBytes: 1024,
    );
    final item = _pluginItem('A');
    const remote = MediaSource(
      url: 'https://example.com/a.mp3',
      headers: <String, String>{'Referer': 'https://example.com'},
    );

    final stored = await cache.cache(item, remote);
    expect(stored.isOk, isTrue);

    final resolved = await cache.resolve(item, remote);
    final source = switch (resolved) {
      Ok(:final value) => value,
      Failure(:final error) => fail(error.toString()),
    };

    expect(source.url, isNot(remote.url));
    expect(File(source.url).existsSync(), isTrue);
    expect(source.headers, isEmpty);
    expect(downloader.downloadCount, 1);
  });

  test(
    'miss returns the remote source and cache failure does not affect playback',
    () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'robyne_cache_miss_test_',
      );
      addTearDown(() async {
        await tempDirectory.delete(recursive: true);
      });
      final downloader = _FailingAudioDownloader();
      final cache = LocalAudioCacheService(
        fileStore: LocalFileStore(baseDirectory: tempDirectory),
        downloader: downloader,
        maxBytes: 1024,
      );
      final item = _pluginItem('A');
      const remote = MediaSource(url: 'https://example.com/a.mp3');

      final resolved = await cache.resolve(item, remote);
      expect(resolved.fold((source) => source.url, (_) => ''), remote.url);

      final cached = await cache.cache(item, remote);
      expect(cached, isA<Failure>());
    },
  );

  test(
    'evicts least recently used cache entries when the limit is exceeded',
    () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'robyne_cache_lru_test_',
      );
      addTearDown(() async {
        await tempDirectory.delete(recursive: true);
      });
      final downloader = _QueueAudioDownloader(<List<int>>[
        List<int>.filled(60, 1),
        List<int>.filled(60, 2),
        List<int>.filled(60, 3),
      ]);
      final cache = LocalAudioCacheService(
        fileStore: LocalFileStore(baseDirectory: tempDirectory),
        downloader: downloader,
        maxBytes: 120,
      );

      await cache.cache(
        _pluginItem('A'),
        const MediaSource(url: 'https://e/a.mp3'),
      );
      await cache.cache(
        _pluginItem('B'),
        const MediaSource(url: 'https://e/b.mp3'),
      );
      await cache.resolve(
        _pluginItem('A'),
        const MediaSource(url: 'https://e/a.mp3'),
      );
      await cache.cache(
        _pluginItem('C'),
        const MediaSource(url: 'https://e/c.mp3'),
      );

      expect(
        (await cache.resolve(
          _pluginItem('A'),
          const MediaSource(url: 'https://e/a.mp3'),
        )).fold((source) => source.url, (_) => ''),
        isNot('https://e/a.mp3'),
      );
      expect(
        (await cache.resolve(
          _pluginItem('B'),
          const MediaSource(url: 'https://e/b.mp3'),
        )).fold((source) => source.url, (_) => ''),
        'https://e/b.mp3',
      );
      expect(
        (await cache.resolve(
          _pluginItem('C'),
          const MediaSource(url: 'https://e/c.mp3'),
        )).fold((source) => source.url, (_) => ''),
        isNot('https://e/c.mp3'),
      );
    },
  );
}

PlaybackItem _pluginItem(String id) {
  return PlaybackItem.plugin(
    platform: 'Test',
    musicId: id,
    title: id,
    raw: <String, Object?>{'id': id},
  );
}

class _FakeAudioDownloader implements AudioDownloader {
  _FakeAudioDownloader(this.bytes);

  final List<int> bytes;
  int downloadCount = 0;

  @override
  Future<List<int>> download(MediaSource source) async {
    downloadCount += 1;
    return bytes;
  }
}

class _FailingAudioDownloader implements AudioDownloader {
  @override
  Future<List<int>> download(MediaSource source) async {
    throw Exception('download failed');
  }
}

class _QueueAudioDownloader implements AudioDownloader {
  _QueueAudioDownloader(this.responses);

  final List<List<int>> responses;

  @override
  Future<List<int>> download(MediaSource source) async {
    return responses.removeAt(0);
  }
}
