import 'dart:async';

import 'package:robyne/core/result/result.dart';
import 'package:robyne/features/player/domain/audio_player_service.dart';
import 'package:robyne/features/player/domain/media_source.dart';

/// A stand-in audio backend for tests that care about queue wiring rather than
/// decoding: it records what it was asked to play and never touches a device.
class FakeAudioPlayerService implements AudioPlayerService {
  final _controller = StreamController<PlayerSnapshot>.broadcast();
  final playedUrls = <String>[];
  int stopCount = 0;
  PlayerSnapshot _snapshot = const PlayerSnapshot();

  @override
  PlayerSnapshot get snapshot => _snapshot;

  @override
  Stream<PlayerSnapshot> get snapshots async* {
    yield _snapshot;
    yield* _controller.stream;
  }

  void emit(PlayerSnapshot snapshot) {
    _snapshot = snapshot;
    _controller.add(snapshot);
  }

  @override
  Future<Result<void>> play(
    MediaSource source, {
    Duration startPosition = Duration.zero,
    Duration expectedDuration = Duration.zero,
  }) async {
    playedUrls.add(source.url);
    return const Ok(null);
  }

  @override
  Future<Result<void>> pause() async => const Ok(null);

  @override
  Future<Result<void>> resume() async => const Ok(null);

  @override
  Future<Result<void>> seek(Duration position) async => const Ok(null);

  @override
  Future<Result<void>> setVolume(double volume) async => const Ok(null);

  @override
  Future<Result<void>> stop() async {
    stopCount += 1;
    return const Ok(null);
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}
