import 'dart:async';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/window_arguments.dart';
import '../../settings/domain/lyric_settings.dart';
import '../../settings/domain/shortcut_binding.dart';
import 'desktop_lyric_theme_service.dart';

final desktopLyricWindowControllerProvider =
    Provider<DesktopLyricWindowController>((ref) {
      return DesktopLyricWindowController();
    });

const desktopLyricControlChannel = WindowMethodChannel(
  'robyne.desktop_lyric.control',
  mode: ChannelMode.unidirectional,
);
const desktopLyricToggleEnabledMethod = 'desktop_lyric.toggle_enabled';
const desktopLyricToggleAlwaysOnTopMethod =
    'desktop_lyric.toggle_always_on_top';
const desktopLyricDecreaseFontSizeMethod = 'desktop_lyric.decrease_font_size';
const desktopLyricIncreaseFontSizeMethod = 'desktop_lyric.increase_font_size';
const desktopLyricPreviousTrackMethod = 'desktop_lyric.previous_track';
const desktopLyricTogglePlaybackMethod = 'desktop_lyric.toggle_playback';
const desktopLyricNextTrackMethod = 'desktop_lyric.next_track';
const desktopLyricToggleLockedMethod = 'desktop_lyric.toggle_locked';
const desktopLyricSetWindowPositionMethod = 'desktop_lyric.set_window_position';

class DesktopLyricPayload {
  const DesktopLyricPayload({
    required this.title,
    required this.lyric,
    required this.nextLyric,
    required this.subtitle,
    required this.theme,
    required this.lyricSettings,
    required this.isPlaying,
    this.toggleBinding,
  });

  const DesktopLyricPayload.empty()
    : title = 'Robyne',
      lyric = '暂无歌词',
      nextLyric = '',
      subtitle = '',
      theme = const DesktopLyricTheme.defaultTheme(),
      lyricSettings = const LyricSettings.defaults(),
      isPlaying = false,
      toggleBinding = null;

  final String title;
  final String lyric;
  final String nextLyric;
  final String subtitle;
  final DesktopLyricTheme theme;
  final LyricSettings lyricSettings;
  final bool isPlaying;
  final ShortcutBinding? toggleBinding;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'title': title,
      'lyric': lyric,
      'nextLyric': nextLyric,
      'subtitle': subtitle,
      'theme': theme.toJson(),
      'lyricSettings': lyricSettings.toJson(),
      'isPlaying': isPlaying,
      'toggleBinding': toggleBinding?.toJson(),
    };
  }

  factory DesktopLyricPayload.fromJson(Map<Object?, Object?> json) {
    return DesktopLyricPayload(
      title: json['title']?.toString() ?? 'Robyne',
      lyric: json['lyric']?.toString() ?? '暂无歌词',
      nextLyric: json['nextLyric']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      theme: json['theme'] is Map<Object?, Object?>
          ? DesktopLyricTheme.fromJson(json['theme'] as Map<Object?, Object?>)
          : const DesktopLyricTheme.defaultTheme(),
      lyricSettings: json['lyricSettings'] is Map<Object?, Object?>
          ? LyricSettings.fromJson(
              json['lyricSettings'] as Map<Object?, Object?>,
            )
          : const LyricSettings.defaults(),
      isPlaying: json['isPlaying'] == true,
      toggleBinding: json['toggleBinding'] is Map
          ? ShortcutBinding.fromJsonMap(
              (json['toggleBinding'] as Map).map(
                (key, dynamic value) =>
                    MapEntry(key.toString(), value as Object?),
              ),
            )
          : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is DesktopLyricPayload &&
        other.title == title &&
        other.lyric == lyric &&
        other.nextLyric == nextLyric &&
        other.subtitle == subtitle &&
        other.theme == theme &&
        other.lyricSettings == lyricSettings &&
        other.isPlaying == isPlaying &&
        other.toggleBinding == toggleBinding;
  }

  @override
  int get hashCode => Object.hash(
    title,
    lyric,
    nextLyric,
    subtitle,
    theme,
    lyricSettings,
    isPlaying,
    toggleBinding,
  );
}

class DesktopLyricWindowController {
  static const updateMethod = 'desktop_lyric.update';
  static const _retryCount = 6;
  static const _retryGap = Duration(milliseconds: 180);

  WindowController? _controller;
  bool _visible = false;

  bool get isSupported =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  Future<void> sync(DesktopLyricPayload payload) async {
    if (!isSupported) {
      return;
    }
    if (!payload.lyricSettings.desktopLyricsEnabled) {
      if (_controller == null || !_visible) {
        return;
      }
      try {
        await _controller!.hide();
      } catch (_) {
        _controller = null;
      } finally {
        _visible = false;
      }
      return;
    }

    if (_controller == null) {
      final controller = await WindowController.create(
        WindowConfiguration(
          hiddenAtLaunch: true,
          arguments: const RobyneWindowArguments.desktopLyrics().encode(),
        ),
      );
      _controller = controller;
      _visible = true;
      await _sendPayload(controller, payload, retry: true);
      return;
    }

    if (!_visible) {
      try {
        await _controller!.show();
        _visible = true;
      } catch (_) {
        _controller = null;
        _visible = false;
        return;
      }
    }

    await _sendPayload(_controller!, payload, retry: true);
  }

  Future<void> _sendPayload(
    WindowController controller,
    DesktopLyricPayload payload, {
    bool retry = false,
  }) async {
    for (var attempt = 0; attempt < (retry ? _retryCount : 1); attempt += 1) {
      try {
        await controller.invokeMethod<void>(updateMethod, payload.toJson());
        return;
      } catch (_) {
        if (attempt == _retryCount - 1) {
          rethrow;
        }
        await Future<void>.delayed(_retryGap);
      }
    }
  }
}
