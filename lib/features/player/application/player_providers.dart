import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/result/result.dart';
import '../../downloads/application/download_providers.dart';
import '../../plugin/application/plugin_providers.dart';
import '../../plugin/application/plugin_runtime_config.dart';
import '../../search/domain/music_item.dart';
import '../../settings/application/settings_providers.dart';
import '../domain/audio_player_service.dart';
import '../infrastructure/media_kit_audio_player_service.dart';
import '../domain/media_source.dart';
import '../domain/playback_item.dart';
import '../infrastructure/local_audio_cache_service.dart';
import 'player_state_repository.dart';

const _backgroundAudioCacheEnabled = false;

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

final playbackCompletionListenerProvider = Provider<void>((ref) {
  var wasCompleted = false;
  ref.listen<AsyncValue<PlayerSnapshot>>(playerSnapshotsProvider, (
    previous,
    next,
  ) {
    final completed = next.value?.completed ?? false;
    if (completed && !wasCompleted) {
      unawaited(
        ref.read(playerControllerProvider.notifier).handlePlaybackCompleted(),
      );
    }
    wasCompleted = completed;
    final snapshot = next.value;
    if (snapshot != null) {
      ref.read(playerControllerProvider.notifier).syncSnapshot(snapshot);
    }
  });
});

final audioCacheServiceProvider = Provider<LocalAudioCacheService>((ref) {
  final settingsRepository = ref.watch(settingsRepositoryProvider);
  return LocalAudioCacheService(
    fileStore: ref.watch(localFileStoreProvider),
    database: ref.watch(appDatabaseProvider),
    legacyMigration: ref.watch(legacyStorageMigrationProvider),
    maxBytesReader: () async =>
        (await settingsRepository.load()).cacheSizeBytes,
    cacheDirectoryReader: () async {
      final settings = await settingsRepository.load();
      final directory = Directory(settings.cacheDirectoryPath);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return directory;
    },
  );
});

final playbackRandomProvider = Provider<Random>((ref) {
  return Random();
});

final playerStateRepositoryProvider = Provider<PlayerStateRepository>((ref) {
  return PlayerStateRepository(
    database: ref.watch(appDatabaseProvider),
    legacyMigration: ref.watch(legacyStorageMigrationProvider),
  );
});

final playerControllerProvider =
    AsyncNotifierProvider<PlayerController, PlayerControllerState>(
      PlayerController.new,
    );

class PlayerControllerState {
  const PlayerControllerState({
    this.error,
    this.queue = const <PlaybackItem>[],
    this.history = const <PlaybackHistoryEntry>[],
    this.currentItem,
    this.playbackMode = PlaybackMode.sequence,
    this.volume = 100,
    this.lastPosition = Duration.zero,
    this.lastDuration = Duration.zero,
    this.restoreTargetPosition = Duration.zero,
  });

  final AppError? error;
  final List<PlaybackItem> queue;
  final List<PlaybackHistoryEntry> history;
  final PlaybackItem? currentItem;
  final PlaybackMode playbackMode;
  final double volume;
  final Duration lastPosition;
  final Duration lastDuration;
  final Duration restoreTargetPosition;

  int get currentIndex {
    final item = currentItem;
    if (item == null) {
      return -1;
    }
    return queue.indexWhere((candidate) => candidate.id == item.id);
  }

  PlayerControllerState copyWith({
    AppError? error,
    List<PlaybackItem>? queue,
    List<PlaybackHistoryEntry>? history,
    PlaybackItem? currentItem,
    PlaybackMode? playbackMode,
    double? volume,
    Duration? lastPosition,
    Duration? lastDuration,
    Duration? restoreTargetPosition,
    bool clearError = false,
    bool clearCurrentItem = false,
  }) {
    return PlayerControllerState(
      error: clearError ? null : error ?? this.error,
      queue: queue ?? this.queue,
      history: history ?? this.history,
      currentItem: clearCurrentItem ? null : currentItem ?? this.currentItem,
      playbackMode: playbackMode ?? this.playbackMode,
      volume: volume ?? this.volume,
      lastPosition: lastPosition ?? this.lastPosition,
      lastDuration: lastDuration ?? this.lastDuration,
      restoreTargetPosition:
          restoreTargetPosition ?? this.restoreTargetPosition,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'queue': queue.map((item) => item.toJson()).toList(),
      'history': history.map((entry) => entry.toJson()).toList(),
      'currentItem': currentItem?.toJson(),
      'playbackMode': playbackMode.name,
      'volume': volume,
      'lastPositionMs': lastPosition.inMilliseconds,
      'lastDurationMs': lastDuration.inMilliseconds,
    };
  }

  static PlayerControllerState fromJson(Map<String, Object?> json) {
    return PlayerControllerState(
      queue: _playbackItems(json['queue']),
      history: _historyEntries(json['history']),
      currentItem: json['currentItem'] is Map
          ? PlaybackItem.fromJson(_objectMap(json['currentItem'] as Map))
          : null,
      playbackMode: PlaybackMode.values.firstWhere(
        (mode) => mode.name == json['playbackMode']?.toString(),
        orElse: () => PlaybackMode.sequence,
      ),
      volume: json['volume'] is num ? (json['volume']! as num).toDouble() : 100,
      lastPosition: json['lastPositionMs'] is num
          ? Duration(milliseconds: (json['lastPositionMs']! as num).toInt())
          : Duration.zero,
      lastDuration: json['lastDurationMs'] is num
          ? Duration(milliseconds: (json['lastDurationMs']! as num).toInt())
          : Duration.zero,
    );
  }

  static List<PlaybackItem> _playbackItems(Object? value) {
    if (value is! List) {
      return const <PlaybackItem>[];
    }
    return value
        .whereType<Map>()
        .map((item) => PlaybackItem.fromJson(_objectMap(item)))
        .toList(growable: false);
  }

  static List<PlaybackHistoryEntry> _historyEntries(Object? value) {
    if (value is! List) {
      return const <PlaybackHistoryEntry>[];
    }
    return value
        .whereType<Map>()
        .map((entry) => PlaybackHistoryEntry.fromJson(_objectMap(entry)))
        .toList(growable: false);
  }

  static Map<String, Object?> _objectMap(Map<dynamic, dynamic> value) {
    return value.map(
      (key, dynamic mapValue) => MapEntry(key.toString(), mapValue as Object?),
    );
  }
}

class PlayerController extends AsyncNotifier<PlayerControllerState> {
  static const _historyLimit = 1000;
  static const _restoreSnapshotGuardDuration = Duration(milliseconds: 1500);
  static const _persistDebounceDuration = Duration(seconds: 5);
  int _playRequestId = 0;
  String? _restoringItemId;
  Timer? _restoreGuardTimer;
  Timer? _persistTimer;
  PlayerControllerState? _pendingPersistState;
  bool _lifecycleHooksRegistered = false;

  @override
  FutureOr<PlayerControllerState> build() async {
    _registerLifecycleHooks();
    final saved = await ref.watch(playerStateRepositoryProvider).load();
    if (ref.mounted) {
      unawaited(ref.read(audioPlayerServiceProvider).setVolume(saved.volume));
    }
    return saved;
  }

  Future<void> playFromPlugin(MusicItem item) async {
    await playItem(PlaybackItem.fromMusicItem(item));
  }

  Future<void> playItem(PlaybackItem item, {bool recordHistory = true}) async {
    await _playItem(item, recordHistory: recordHistory);
  }

  Future<void> _playItem(
    PlaybackItem item, {
    required bool recordHistory,
    Duration startPosition = Duration.zero,
    Duration startDuration = Duration.zero,
  }) async {
    final requestId = _playRequestId + 1;
    _playRequestId = requestId;
    _setData(_current.copyWith(clearError: true));

    final stopResult = await ref.read(audioPlayerServiceProvider).stop();
    if (!ref.mounted) {
      return;
    }
    if (!_isCurrentPlayRequest(requestId)) {
      return;
    }
    if (stopResult case Failure<void>(:final error)) {
      _setData(_current.copyWith(error: error));
      return;
    }

    if (item.isPlugin) {
      final completedDownload = await ref
          .read(downloadRepositoryProvider)
          .completedForItem(item.id);
      if (!ref.mounted) {
        return;
      }
      if (!_isCurrentPlayRequest(requestId)) {
        return;
      }
      final downloadPath = completedDownload?.filePath;
      if (downloadPath != null && await File(downloadPath).exists()) {
        await _playResolvedItem(
          item,
          MediaSource(url: downloadPath),
          requestId,
          recordHistory: recordHistory,
          startPosition: startPosition,
          startDuration: startDuration,
        );
        return;
      }

      final cachedResult = await ref
          .read(audioCacheServiceProvider)
          .resolveCached(item);
      if (!ref.mounted) {
        return;
      }
      if (!_isCurrentPlayRequest(requestId)) {
        return;
      }
      switch (cachedResult) {
        case Ok<MediaSource?>(:final value):
          if (value != null) {
            await _playResolvedItem(
              item,
              value,
              requestId,
              recordHistory: recordHistory,
              startPosition: startPosition,
              startDuration: startDuration,
            );
            return;
          }
        case Failure<MediaSource?>():
          break;
      }
    }

    final rawSourceResult = item.isLocal
        ? await _mediaSourceFromLocalItem(item)
        : await _mediaSourceFromPluginItem(item, requestId);
    if (!ref.mounted) {
      return;
    }
    if (!_isCurrentPlayRequest(requestId)) {
      return;
    }

    final sourceResult = switch (rawSourceResult) {
      Ok(:final value) => await _resolveCachedSource(item, value),
      Failure(:final error) => Failure<MediaSource>(error),
    };
    if (!ref.mounted) {
      return;
    }
    if (!_isCurrentPlayRequest(requestId)) {
      return;
    }

    switch (sourceResult) {
      case Ok(:final value):
        await _playResolvedItem(
          item,
          value,
          requestId,
          recordHistory: recordHistory,
          startPosition: startPosition,
          startDuration: startDuration,
        );
      case Failure(:final error):
        if (_isCurrentPlayRequest(requestId)) {
          _setData(_current.copyWith(error: error));
        }
    }
  }

  Future<Result<MediaSource>> _mediaSourceFromLocalItem(
    PlaybackItem item,
  ) async {
    final path = item.localPath;
    if (path == null || !await File(path).exists()) {
      return Failure(
        AppError(
          code: 'local.file_missing',
          message: 'Local music file does not exist: ${path ?? item.title}',
        ),
      );
    }
    return Ok(MediaSource(url: path));
  }

  Future<Result<MediaSource>> _resolveCachedSource(
    PlaybackItem item,
    MediaSource source,
  ) async {
    if (!item.isPlugin) {
      return Ok(source);
    }
    final cache = ref.read(audioCacheServiceProvider);
    final resolved = await cache.resolve(item, source);
    switch (resolved) {
      case Ok<MediaSource>(:final value):
        if (_backgroundAudioCacheEnabled && value.url == source.url) {
          unawaited(cache.cache(item, source));
        }
        return Ok(value);
      case Failure<MediaSource>():
        if (_backgroundAudioCacheEnabled) {
          unawaited(cache.cache(item, source));
        }
        return Ok(source);
    }
  }

  Future<Result<MediaSource>> _mediaSourceFromPluginItem(
    PlaybackItem item,
    int requestId,
  ) async {
    final runtimeFactory = ref.read(pluginRuntimeFactoryProvider);
    final repository = ref.read(pluginRepositoryProvider);
    final compat = ref.read(musicFreeCompatAdapterProvider);

    final pluginsResult = await repository.listPlugins();
    if (!_isCurrentPlayRequest(requestId)) {
      return const Ok(MediaSource(url: ''));
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
      return const Failure(
        AppError(
          code: 'plugin.not_found',
          message: 'No enabled plugin can play this item.',
        ),
      );
    }

    final runtime = await runtimeFactory.create();
    try {
      if (!_isCurrentPlayRequest(requestId)) {
        return const Ok(MediaSource(url: ''));
      }

      final source = await File(plugin.sourcePath).readAsString();
      if (!_isCurrentPlayRequest(requestId)) {
        return const Ok(MediaSource(url: ''));
      }

      final loaded = await runtime.loadPlugin(
        source,
        userVariables: Map<String, String>.from(plugin.userVariableValues),
      );
      if (!_isCurrentPlayRequest(requestId)) {
        return const Ok(MediaSource(url: ''));
      }
      if (loaded case Failure<Map<String, Object?>>(:final error)) {
        return Failure(error);
      }

      final mediaResult = await runtime.callMethod('getMediaSource', <Object?>[
        item.raw,
        'standard',
      ], timeout: pluginMethodTimeout);

      if (!_isCurrentPlayRequest(requestId)) {
        return const Ok(MediaSource(url: ''));
      }

      return switch (mediaResult) {
        Ok<Object?>(:final value) => compat.mediaSourceFromPluginValue(value),
        Failure<Object?>(:final error) => Failure(error),
      };
    } finally {
      await runtime.dispose();
    }
  }

  Future<void> _playResolvedItem(
    PlaybackItem item,
    MediaSource source,
    int requestId, {
    required bool recordHistory,
    Duration startPosition = Duration.zero,
    Duration startDuration = Duration.zero,
  }) async {
    final audio = ref.read(audioPlayerServiceProvider);
    if (startPosition > Duration.zero) {
      _startRestoreGuard(item.id, requestId, startPosition);
    }
    final stateBeforePlay = _current;
    _setData(
      stateBeforePlay.copyWith(
        currentItem: item,
        queue: _queueWith(item),
        lastPosition: startPosition,
        lastDuration: item.duration ?? startDuration,
        restoreTargetPosition: startPosition,
        clearError: true,
      ),
    );
    final playResult = await audio.play(
      source,
      startPosition: startPosition,
      expectedDuration: item.duration ?? startDuration,
    );
    if (!ref.mounted) {
      return;
    }
    if (!_isCurrentPlayRequest(requestId)) {
      return;
    }
    switch (playResult) {
      case Ok<void>():
        final volumeResult = await audio.setVolume(_current.volume);
        if (!ref.mounted) {
          return;
        }
        if (!_isCurrentPlayRequest(requestId)) {
          return;
        }
        AppError? nextError;
        if (volumeResult case Failure<void>(:final error)) {
          nextError = error;
        }
        _setData(
          _current.copyWith(
            error: nextError,
            queue: _queueWith(item),
            currentItem: item,
            history: recordHistory ? _historyWith(item) : _current.history,
            lastPosition: startPosition,
            lastDuration: item.duration ?? startDuration,
            clearError: nextError == null,
          ),
        );
      case Failure<void>(:final error):
        _clearRestoreTracking(item.id);
        _setData(_current.copyWith(error: error));
    }
  }

  Future<void> pause() async {
    _playRequestId += 1;
    final result = await ref.read(audioPlayerServiceProvider).pause();
    if (!ref.mounted) {
      return;
    }
    _setData(
      _current.copyWith(error: result.fold((_) => null, (error) => error)),
    );
    await _flushPersist();
  }

  Future<void> resume() async {
    _playRequestId += 1;
    final result = await ref.read(audioPlayerServiceProvider).resume();
    if (!ref.mounted) {
      return;
    }
    _setData(
      _current.copyWith(error: result.fold((_) => null, (error) => error)),
    );
  }

  Future<void> resumeOrPlayCurrent() async {
    if (ref.read(audioPlayerServiceProvider).snapshot.currentSource != null) {
      await resume();
      return;
    }
    final current = _current;
    final item = current.currentItem;
    if (item == null) {
      return;
    }
    await _playItem(
      item,
      recordHistory: false,
      startPosition: current.lastPosition,
      startDuration: current.lastDuration,
    );
  }

  Future<void> seek(Duration position) async {
    _clearRestoreTracking(_current.currentItem?.id);
    if (ref.read(audioPlayerServiceProvider).snapshot.currentSource == null) {
      _setData(_current.copyWith(lastPosition: position));
      await _flushPersist();
      return;
    }
    final result = await ref.read(audioPlayerServiceProvider).seek(position);
    if (!ref.mounted) {
      return;
    }
    _setData(
      _current.copyWith(
        error: result.fold((_) => null, (error) => error),
        lastPosition: result is Ok<void> ? position : null,
        restoreTargetPosition: Duration.zero,
      ),
    );
    await _flushPersist();
  }

  Future<void> setVolume(double volume) async {
    final result = await ref.read(audioPlayerServiceProvider).setVolume(volume);
    if (!ref.mounted) {
      return;
    }
    _setData(
      _current.copyWith(
        error: result.fold((_) => null, (error) => error),
        volume: result is Ok<void> ? volume.clamp(0, 100).toDouble() : null,
      ),
    );
    await _flushPersist();
  }

  Future<void> stop() async {
    _playRequestId += 1;
    _clearRestoreTracking(_current.currentItem?.id);
    final result = await ref.read(audioPlayerServiceProvider).stop();
    if (!ref.mounted) {
      return;
    }
    _setData(
      _current.copyWith(
        error: result.fold((_) => null, (error) => error),
        clearCurrentItem: result is Ok<void>,
        lastPosition: result is Ok<void> ? Duration.zero : null,
        lastDuration: result is Ok<void> ? Duration.zero : null,
        restoreTargetPosition: result is Ok<void> ? Duration.zero : null,
      ),
    );
    await _flushPersist();
  }

  void syncSnapshot(PlayerSnapshot snapshot) {
    final current = state.value;
    if (current == null || current.currentItem == null) {
      return;
    }
    if (snapshot.currentSource == null) {
      return;
    }
    if (_restoringItemId == current.currentItem?.id) {
      return;
    }
    final nextDuration = _stableDuration(
      snapshotDuration: snapshot.duration,
      savedDuration: current.currentItem?.duration ?? current.lastDuration,
    );
    if (snapshot.position == current.lastPosition &&
        nextDuration == current.lastDuration) {
      return;
    }
    _setData(
      current.copyWith(
        lastPosition: snapshot.position,
        lastDuration: nextDuration,
        restoreTargetPosition: Duration.zero,
      ),
      schedulePersist: false,
    );
  }

  Future<void> removeFromQueue(String id) async {
    final current = _current;
    final removingCurrent = current.currentItem?.id == id;
    final queue = current.queue
        .where((item) => item.id != id)
        .toList(growable: false);
    if (removingCurrent) {
      await stop();
      if (!ref.mounted) {
        return;
      }
      _setData(_current.copyWith(queue: queue, clearCurrentItem: true));
      return;
    }
    _setData(current.copyWith(queue: queue));
  }

  Future<void> clearQueue() async {
    await stop();
    if (!ref.mounted) {
      return;
    }
    _setData(
      _current.copyWith(queue: const <PlaybackItem>[], clearCurrentItem: true),
    );
  }

  Future<void> clearHistory() async {
    await ref.read(playerStateRepositoryProvider).clearHistory();
    if (!ref.mounted) {
      return;
    }
    _setData(_current.copyWith(history: const <PlaybackHistoryEntry>[]));
  }

  Future<void> setPlaybackMode(PlaybackMode mode) async {
    _setData(_current.copyWith(playbackMode: mode));
  }

  Future<void> playNext() async {
    final next = _nextItem();
    if (next == null) {
      await stop();
      return;
    }
    await playItem(next);
  }

  Future<void> playPrevious() async {
    final current = _current;
    if (current.queue.isEmpty) {
      return;
    }
    final index = current.currentIndex;
    final previousIndex = index <= 0 ? 0 : index - 1;
    await playItem(current.queue[previousIndex]);
  }

  Future<void> handlePlaybackCompleted() async {
    if (_current.playbackMode == PlaybackMode.singleLoop) {
      final item = _current.currentItem;
      if (item != null) {
        await playItem(item, recordHistory: false);
      }
      return;
    }
    await playNext();
  }

  bool _isCurrentPlayRequest(int requestId) {
    return _playRequestId == requestId;
  }

  void _clearRestoreTracking(String? itemId) {
    if (_restoringItemId == itemId || itemId == null) {
      _restoringItemId = null;
      _restoreGuardTimer?.cancel();
      _restoreGuardTimer = null;
    }
  }

  void _startRestoreGuard(
    String itemId,
    int requestId,
    Duration targetPosition,
  ) {
    _restoreGuardTimer?.cancel();
    _restoringItemId = itemId;
    _restoreGuardTimer = Timer(_restoreSnapshotGuardDuration, () {
      if (!ref.mounted ||
          !_isCurrentPlayRequest(requestId) ||
          _restoringItemId != itemId) {
        return;
      }
      _restoringItemId = null;
      _restoreGuardTimer = null;
      final current = state.value;
      if (current?.currentItem?.id == itemId) {
        _setData(current!.copyWith(restoreTargetPosition: Duration.zero));
      }
    });
  }

  PlayerControllerState get _current =>
      state.value ?? const PlayerControllerState();

  void _setData(PlayerControllerState value, {bool schedulePersist = true}) {
    state = AsyncData(value);
    if (schedulePersist) {
      _schedulePersist(value);
    }
  }

  void _registerLifecycleHooks() {
    if (_lifecycleHooksRegistered) {
      return;
    }
    _lifecycleHooksRegistered = true;
    ref.onDispose(() {
      _restoreGuardTimer?.cancel();
      _persistTimer?.cancel();
      _pendingPersistState = null;
    });
  }

  void _schedulePersist(PlayerControllerState value) {
    _registerLifecycleHooks();
    _pendingPersistState = value;
    _persistTimer?.cancel();
    _persistTimer = Timer(_persistDebounceDuration, () {
      final pending = _pendingPersistState;
      _pendingPersistState = null;
      _persistTimer = null;
      if (pending != null) {
        unawaited(_persist(pending));
      }
    });
  }

  Future<void> _flushPersist() async {
    final pending = _pendingPersistState;
    _pendingPersistState = null;
    _persistTimer?.cancel();
    _persistTimer = null;
    if (pending != null) {
      await _persist(pending);
    }
  }

  Future<void> _persist(PlayerControllerState value) async {
    if (!ref.mounted) {
      return;
    }
    try {
      await ref.read(playerStateRepositoryProvider).save(value);
    } catch (_) {
      // Playback state persistence must never interrupt playback controls.
    }
  }

  List<PlaybackItem> _queueWith(PlaybackItem item) {
    final existing = _current.queue;
    if (existing.any((candidate) => candidate.id == item.id)) {
      return existing;
    }
    return <PlaybackItem>[...existing, item];
  }

  List<PlaybackHistoryEntry> _historyWith(PlaybackItem item) {
    final history = <PlaybackHistoryEntry>[
      ..._current.history,
      PlaybackHistoryEntry(item: item, playedAt: DateTime.now()),
    ];
    if (history.length <= _historyLimit) {
      return history;
    }
    return history.sublist(history.length - _historyLimit);
  }

  PlaybackItem? _nextItem() {
    final current = _current;
    final queue = current.queue;
    if (queue.isEmpty) {
      return null;
    }
    final index = current.currentIndex;
    return switch (current.playbackMode) {
      PlaybackMode.sequence =>
        index >= 0 && index < queue.length - 1 ? queue[index + 1] : null,
      PlaybackMode.allLoop => queue[(index + 1) % queue.length],
      PlaybackMode.singleLoop => current.currentItem,
      PlaybackMode.random => _randomNext(queue, index),
    };
  }

  PlaybackItem _randomNext(List<PlaybackItem> queue, int currentIndex) {
    if (queue.length == 1) {
      return queue.first;
    }
    final candidates = <PlaybackItem>[
      for (var index = 0; index < queue.length; index += 1)
        if (index != currentIndex) queue[index],
    ];
    return candidates[ref
        .read(playbackRandomProvider)
        .nextInt(candidates.length)];
  }

  Duration _stableDuration({
    required Duration snapshotDuration,
    required Duration savedDuration,
  }) {
    if (snapshotDuration <= Duration.zero) {
      return savedDuration;
    }
    if (savedDuration <= Duration.zero) {
      return snapshotDuration;
    }
    final difference = (snapshotDuration - savedDuration).abs();
    if (difference <= const Duration(seconds: 1)) {
      return savedDuration;
    }
    return snapshotDuration;
  }
}
