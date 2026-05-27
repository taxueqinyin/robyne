import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/result/result.dart';
import 'package:robyne/features/player/application/player_providers.dart';
import 'package:robyne/features/player/domain/audio_player_service.dart';
import 'package:robyne/features/player/domain/media_source.dart';
import 'package:robyne/features/plugin/application/plugin_providers.dart';
import 'package:robyne/features/plugin/domain/plugin_definition.dart';
import 'package:robyne/features/plugin/domain/plugin_repository.dart';
import 'package:robyne/features/plugin/domain/plugin_runtime.dart';
import 'package:robyne/features/search/domain/music_item.dart';

void main() {
  test(
    'late media resolution from an old play request cannot replace newer playback',
    () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'robyne_player_test_',
      );
      addTearDown(() async {
        await tempDirectory.delete(recursive: true);
      });
      final slowPath = await _writePluginFile(tempDirectory, 'slow.js');
      final fastPath = await _writePluginFile(tempDirectory, 'fast.js');
      final slowCompleter = Completer<void>();
      final runtimeFactory = _FakeRuntimeFactory(slowCompleter);
      final audio = _FakeAudioPlayerService();

      final container = ProviderContainer(
        overrides: [
          pluginRepositoryProvider.overrideWithValue(
            _FakePluginRepository(<PluginDefinition>[
              _plugin('slow', 'Slow', slowPath),
              _plugin('fast', 'Fast', fastPath),
            ]),
          ),
          pluginRuntimeFactoryProvider.overrideWithValue(runtimeFactory),
          audioPlayerServiceProvider.overrideWithValue(audio),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(playerControllerProvider.notifier);
      final slowPlay = controller.playFromPlugin(_musicItem('Slow'));
      await runtimeFactory.waitForSlowRuntimeStarted();

      await controller.playFromPlugin(_musicItem('Fast'));
      expect(audio.playedUrls, <String>['https://example.com/Fast.mp3']);

      slowCompleter.complete();
      await slowPlay;

      expect(audio.playedUrls, <String>['https://example.com/Fast.mp3']);
      expect(audio.stopCount, 2);
    },
  );

  test('pause and resume delegate to the audio service', () async {
    final audio = _FakeAudioPlayerService();
    final container = ProviderContainer(
      overrides: [audioPlayerServiceProvider.overrideWithValue(audio)],
    );
    addTearDown(container.dispose);

    final controller = container.read(playerControllerProvider.notifier);
    await controller.pause();
    await controller.resume();

    expect(audio.pauseCount, 1);
    expect(audio.resumeCount, 1);
  });
}

Future<String> _writePluginFile(Directory directory, String name) async {
  final file = File('${directory.path}/$name');
  await file.writeAsString('// $name');
  return file.path;
}

PluginDefinition _plugin(String id, String platform, String sourcePath) {
  return PluginDefinition(
    id: id,
    platform: platform,
    sourcePath: sourcePath,
    enabled: true,
    installedAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

MusicItem _musicItem(String platform) {
  return MusicItem(
    id: platform,
    platform: platform,
    title: platform,
    raw: <String, Object?>{'id': platform, 'title': platform},
  );
}

class _FakePluginRepository implements PluginRepository {
  _FakePluginRepository(this._plugins);

  final List<PluginDefinition> _plugins;

  @override
  Future<Result<List<PluginDefinition>>> listPlugins() async {
    return Ok(_plugins);
  }

  @override
  Future<Result<void>> deletePlugin(String id) async => const Ok(null);

  @override
  Future<Result<PluginDefinition>> importPluginFromPath(String path) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<PluginDefinition>> importPluginFromUrl(String url) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<PluginDefinition>> updateUserVariableValues(
    String id,
    Map<String, String> values,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<PluginDefinition>> setEnabled(String id, bool enabled) async {
    throw UnimplementedError();
  }
}

class _FakeRuntimeFactory implements PluginRuntimeFactory {
  _FakeRuntimeFactory(this._slowCompleter);

  final Completer<void> _slowCompleter;
  final _slowRuntimeStarted = Completer<void>();

  Future<void> waitForSlowRuntimeStarted() => _slowRuntimeStarted.future;

  @override
  Future<PluginRuntime> create() async {
    return _FakeRuntime(_slowCompleter, _slowRuntimeStarted);
  }
}

class _FakeRuntime implements PluginRuntime {
  _FakeRuntime(this._slowCompleter, this._slowRuntimeStarted);

  final Completer<void> _slowCompleter;
  final Completer<void> _slowRuntimeStarted;
  String _platform = 'unknown';

  @override
  Future<Result<Map<String, Object?>>> loadPlugin(
    String source, {
    Map<String, String> userVariables = const <String, String>{},
  }) async {
    _platform = source.contains('slow') ? 'Slow' : 'Fast';
    return Ok(<String, Object?>{'platform': _platform});
  }

  @override
  Future<Result<Object?>> callMethod(
    String method,
    List<Object?> arguments, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (_platform == 'Slow') {
      if (!_slowRuntimeStarted.isCompleted) {
        _slowRuntimeStarted.complete();
      }
      await _slowCompleter.future;
    }
    return Ok(<String, Object?>{'url': 'https://example.com/$_platform.mp3'});
  }

  @override
  Future<void> dispose() async {}
}

class _FakeAudioPlayerService implements AudioPlayerService {
  final playedUrls = <String>[];
  int stopCount = 0;
  int pauseCount = 0;
  int resumeCount = 0;

  @override
  PlayerSnapshot get snapshot => const PlayerSnapshot();

  @override
  Stream<PlayerSnapshot> get snapshots => const Stream<PlayerSnapshot>.empty();

  @override
  Future<Result<void>> play(MediaSource source) async {
    playedUrls.add(source.url);
    return const Ok(null);
  }

  @override
  Future<Result<void>> pause() async {
    pauseCount += 1;
    return const Ok(null);
  }

  @override
  Future<Result<void>> resume() async {
    resumeCount += 1;
    return const Ok(null);
  }

  @override
  Future<Result<void>> stop() async {
    stopCount += 1;
    return const Ok(null);
  }

  @override
  Future<void> dispose() async {}
}
