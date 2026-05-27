import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/result/result.dart';
import '../../plugin/application/plugin_providers.dart';
import '../../plugin/application/plugin_runtime_config.dart';
import '../../search/domain/music_item.dart';
import '../domain/audio_player_service.dart';
import '../infrastructure/media_kit_audio_player_service.dart';

final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) {
  final service = MediaKitAudioPlayerService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

final playerSnapshotsProvider = StreamProvider<PlayerSnapshot>((ref) {
  return ref.watch(audioPlayerServiceProvider).snapshots;
});

final playerControllerProvider =
    AsyncNotifierProvider<PlayerController, AppError?>(PlayerController.new);

class PlayerController extends AsyncNotifier<AppError?> {
  int _playRequestId = 0;

  @override
  AppError? build() => null;

  Future<void> playFromPlugin(MusicItem item) async {
    final requestId = _playRequestId + 1;
    _playRequestId = requestId;

    final runtimeFactory = ref.read(pluginRuntimeFactoryProvider);
    final repository = ref.read(pluginRepositoryProvider);
    final compat = ref.read(musicFreeCompatAdapterProvider);
    final audio = ref.read(audioPlayerServiceProvider);

    state = const AsyncData(null);
    final stopResult = await audio.stop();
    if (!_isCurrentPlayRequest(requestId)) {
      return;
    }
    if (stopResult case Failure<void>(:final error)) {
      state = AsyncData(error);
      return;
    }

    final pluginsResult = await repository.listPlugins();
    if (!_isCurrentPlayRequest(requestId)) {
      return;
    }

    final plugin = pluginsResult.fold(
      (plugins) => plugins
          .where((candidate) => candidate.enabled)
          .cast<dynamic>()
          .firstWhere(
            (candidate) => candidate.platform == item.platform,
            orElse: () => null,
          ),
      (error) => null,
    );

    if (plugin == null) {
      state = const AsyncData(
        AppError(
          code: 'plugin.not_found',
          message: 'No enabled plugin can play this item.',
        ),
      );
      return;
    }

    final runtime = await runtimeFactory.create();
    try {
      if (!_isCurrentPlayRequest(requestId)) {
        return;
      }

      final source = await File(plugin.sourcePath).readAsString();
      if (!_isCurrentPlayRequest(requestId)) {
        return;
      }

      final loaded = await runtime.loadPlugin(
        source,
        userVariables: Map<String, String>.from(plugin.userVariableValues),
      );
      if (!_isCurrentPlayRequest(requestId)) {
        return;
      }
      if (loaded case Failure<Map<String, Object?>>(:final error)) {
        state = AsyncData(error);
        return;
      }

      final mediaResult = await runtime.callMethod('getMediaSource', <Object?>[
        item.raw,
        'standard',
      ], timeout: pluginMethodTimeout);

      if (!_isCurrentPlayRequest(requestId)) {
        return;
      }

      final mediaSource = switch (mediaResult) {
        Ok<Object?>(:final value) => compat.mediaSourceFromPluginValue(value),
        Failure<Object?>(:final error) => Failure(error),
      };

      switch (mediaSource) {
        case Ok(:final value):
          final playResult = await audio.play(value);
          if (_isCurrentPlayRequest(requestId)) {
            state = AsyncData(playResult.fold((_) => null, (error) => error));
          }
        case Failure(:final error):
          if (_isCurrentPlayRequest(requestId)) {
            state = AsyncData(error);
          }
      }
    } finally {
      await runtime.dispose();
    }
  }

  Future<void> pause() async {
    _playRequestId += 1;
    final result = await ref.read(audioPlayerServiceProvider).pause();
    state = AsyncData(result.fold((_) => null, (error) => error));
  }

  Future<void> resume() async {
    _playRequestId += 1;
    final result = await ref.read(audioPlayerServiceProvider).resume();
    state = AsyncData(result.fold((_) => null, (error) => error));
  }

  Future<void> stop() async {
    _playRequestId += 1;
    final result = await ref.read(audioPlayerServiceProvider).stop();
    state = AsyncData(result.fold((_) => null, (error) => error));
  }

  bool _isCurrentPlayRequest(int requestId) {
    return _playRequestId == requestId;
  }
}
