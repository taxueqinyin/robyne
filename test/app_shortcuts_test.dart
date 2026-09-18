import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/app/app.dart';
import 'package:robyne/core/result/result.dart';
import 'package:robyne/features/downloads/domain/download_audio_format.dart';
import 'package:robyne/features/lyrics/application/lyrics_providers.dart';
import 'package:robyne/features/lyrics/domain/lyric_document.dart';
import 'package:robyne/features/player/application/player_providers.dart';
import 'package:robyne/features/player/domain/audio_player_service.dart';
import 'package:robyne/features/player/domain/media_source.dart';
import 'package:robyne/features/player/domain/playback_item.dart';
import 'package:robyne/features/settings/application/settings_providers.dart';
import 'package:robyne/features/settings/domain/lyric_settings.dart';
import 'package:robyne/features/settings/domain/shortcut_action.dart';
import 'package:robyne/features/settings/domain/shortcut_binding.dart';
import 'package:robyne/features/settings/domain/shortcut_settings.dart';
import 'package:robyne/features/settings/domain/user_settings.dart';

void main() {
  testWidgets('app shell dispatches default playback and lyric shortcuts', (
    tester,
  ) async {
    final item = PlaybackItem.plugin(
      platform: 'Lyrics',
      musicId: 'song-1',
      title: 'Song',
      raw: const <String, Object?>{'id': 'song-1'},
    );
    final controller = _TrackingPlayerController(
      PlayerControllerState(
        queue: <PlaybackItem>[item],
        currentItem: item,
        volume: 40,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioPlayerServiceProvider.overrideWithValue(_FakeAudio()),
          playerControllerProvider.overrideWith(() => controller),
          settingsControllerProvider.overrideWith(() {
            return _SeededSettingsController();
          }),
          currentLyricsProvider.overrideWithValue(
            AsyncData(
              LyricDocument.parse(
                '[00:10.00]first\n[00:20.00]second\n[00:30.00]third',
                sourceType: LyricSourceType.plugin,
              ),
            ),
          ),
          currentPlaybackPositionProvider.overrideWithValue(
            const Duration(seconds: 22),
          ),
        ],
        child: const RobyneApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    expect(controller.resumeCount, 1);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
    expect(controller.seekCalls, <Duration>[
      const Duration(seconds: 20),
      const Duration(seconds: 10),
    ]);
  });

  testWidgets('desktop lyric shortcut toggles persisted lyric visibility', (
    tester,
  ) async {
    late _SeededSettingsController settingsController;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioPlayerServiceProvider.overrideWithValue(_FakeAudio()),
          settingsControllerProvider.overrideWith(() {
            settingsController = _SeededSettingsController(
              shortcuts: ShortcutSettings.defaults().copyWithBinding(
                ShortcutAction.desktopLyrics,
                ShortcutBinding(triggerKeyId: LogicalKeyboardKey.keyL.keyId),
              ),
            );
            return settingsController;
          }),
        ],
        child: const RobyneApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyL);
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyL);

    expect(settingsController.toggleDesktopLyricsEnabledCount, 1);
    expect(
      settingsController.state.value!.lyricSettings.desktopLyricsEnabled,
      isTrue,
    );
  });
}

class _SeededSettingsController extends SettingsController {
  _SeededSettingsController({
    this.shortcuts = const ShortcutSettings(
      bindings: <ShortcutAction, ShortcutBinding?>{},
    ),
  });

  final ShortcutSettings shortcuts;
  int toggleDesktopLyricsEnabledCount = 0;

  @override
  Future<UserSettings> build() async {
    return UserSettings(
      cacheSizeBytes: 1024 * 1024 * 1024,
      cacheDirectoryPath: 'C:/cache',
      downloadsDirectoryPath: 'C:/downloads',
      downloadAudioFormat: DownloadAudioFormat.original,
      shortcuts: shortcuts.bindings.isEmpty
          ? ShortcutSettings.defaults()
          : shortcuts,
      lyricSettings: const LyricSettings.defaults(),
    );
  }

  @override
  Future<void> toggleDesktopLyricsEnabled() async {
    toggleDesktopLyricsEnabledCount += 1;
    final current = state.value!;
    state = AsyncData(
      current.copyWith(
        lyricSettings: current.lyricSettings.copyWith(
          desktopLyricsEnabled: !current.lyricSettings.desktopLyricsEnabled,
        ),
      ),
    );
  }
}

class _TrackingPlayerController extends PlayerController {
  _TrackingPlayerController(this._state);

  final PlayerControllerState _state;
  int resumeCount = 0;
  final seekCalls = <Duration>[];

  @override
  Future<PlayerControllerState> build() async => _state;

  @override
  Future<void> resumeOrPlayCurrent() async {
    resumeCount += 1;
  }

  @override
  Future<void> seek(Duration position) async {
    seekCalls.add(position);
  }
}

class _FakeAudio implements AudioPlayerService {
  final _controller = StreamController<PlayerSnapshot>.broadcast();

  @override
  PlayerSnapshot get snapshot => const PlayerSnapshot();

  @override
  Stream<PlayerSnapshot> get snapshots async* {
    yield const PlayerSnapshot();
    yield* _controller.stream;
  }

  @override
  Future<Result<void>> play(
    MediaSource source, {
    Duration startPosition = Duration.zero,
    Duration expectedDuration = Duration.zero,
  }) async => const Ok(null);

  @override
  Future<Result<void>> pause() async => const Ok(null);

  @override
  Future<Result<void>> resume() async => const Ok(null);

  @override
  Future<Result<void>> seek(Duration position) async => const Ok(null);

  @override
  Future<Result<void>> setVolume(double volume) async => const Ok(null);

  @override
  Future<Result<void>> stop() async => const Ok(null);

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}
