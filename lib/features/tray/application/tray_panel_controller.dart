import 'dart:async';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/window_arguments.dart';

const trayPanelControlChannel = WindowMethodChannel(
  'robyne.tray_panel.control',
  mode: ChannelMode.unidirectional,
);

class TrayPanelPayload {
  const TrayPanelPayload({
    required this.title,
    required this.artist,
    required this.playing,
    required this.liked,
    required this.desktopLyricsEnabled,
    required this.mode,
    this.artworkUrl,
  });

  const TrayPanelPayload.empty()
    : title = '暂无播放',
      artist = 'Robyne',
      playing = false,
      liked = false,
      desktopLyricsEnabled = false,
      mode = 'sequence',
      artworkUrl = null;

  final String title;
  final String artist;
  final bool playing;
  final bool liked;
  final bool desktopLyricsEnabled;
  final String mode;
  final String? artworkUrl;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'title': title,
      'artist': artist,
      'playing': playing,
      'liked': liked,
      'desktopLyricsEnabled': desktopLyricsEnabled,
      'mode': mode,
      'artworkUrl': artworkUrl,
    };
  }

  factory TrayPanelPayload.fromJson(Map<Object?, Object?> json) {
    return TrayPanelPayload(
      title: json['title']?.toString() ?? '暂无播放',
      artist: json['artist']?.toString() ?? '',
      playing: json['playing'] == true,
      liked: json['liked'] == true,
      desktopLyricsEnabled: json['desktopLyricsEnabled'] == true,
      mode: json['mode']?.toString() ?? 'sequence',
      artworkUrl: json['artworkUrl']?.toString(),
    );
  }

  /// Value equality lets the main isolate skip pushing a payload the panel
  /// already has; playback snapshots tick far faster than the menu changes.
  @override
  bool operator ==(Object other) {
    return other is TrayPanelPayload &&
        other.title == title &&
        other.artist == artist &&
        other.playing == playing &&
        other.liked == liked &&
        other.desktopLyricsEnabled == desktopLyricsEnabled &&
        other.mode == mode &&
        other.artworkUrl == artworkUrl;
  }

  @override
  int get hashCode => Object.hash(
    title,
    artist,
    playing,
    liked,
    desktopLyricsEnabled,
    mode,
    artworkUrl,
  );
}

IconData trayPanelModeIcon(String mode) {
  return switch (mode) {
    'random' => Icons.shuffle,
    'allLoop' => Icons.repeat,
    'singleLoop' => Icons.repeat_one,
    _ => Icons.format_list_numbered,
  };
}

class TrayPanelController {
  static const updateMethod = 'tray_panel.update';
  static const showMethod = 'tray_panel.show';
  static const hideMethod = 'tray_panel.hide';
  static const hiddenMethod = 'tray_panel.hidden';
  static const setAnchorMethod = 'tray_panel.set_anchor';
  static const sizeMethod = 'tray_panel.size';

  static const _retryCount = 8;
  static const _retryGap = Duration(milliseconds: 150);

  WindowController? _controller;
  Future<WindowController?>? _creatingController;
  bool _visible = false;
  Size _panelSize = const Size(288, 360);

  bool get isSupported =>
      !kIsWeb &&
      (Platform.isWindows || Platform.isLinux || Platform.isMacOS) &&
      !Platform.environment.containsKey('FLUTTER_TEST');

  /// Whether the panel is currently on screen.
  bool get isVisible => _visible;

  /// The panel's logical size, once it has reported itself.
  Size get panelSize => _panelSize;

  /// Updates the cached size the panel reports back after its first layout.
  void updatePanelSize(Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }
    _panelSize = size;
  }

  /// Synchronises the parent's toggle state when the panel hides itself.
  ///
  /// The panel closes on focus loss, like a native context menu. Without this
  /// signal the parent still believes it is open and the next tray click only
  /// sends another hide, so the menu can only ever be opened once.
  void markHidden() {
    _visible = false;
  }

  /// Creates the panel engine once during startup.
  ///
  /// The panel is created lazily otherwise, which puts a whole Flutter engine
  /// boot on the user-visible path of the very first tray click.
  Future<void> warmUp() async {
    if (!isSupported) {
      return;
    }
    await _ensureController();
  }

  Future<void> sync(TrayPanelPayload payload) async {
    if (!isSupported || !_visible) {
      return;
    }
    final controller = await _ensureController();
    if (controller == null || !_visible) {
      return;
    }
    await _invokeWithRetry(controller, updateMethod, payload.toJson());
  }

  /// Shows the panel, priming it with [payload] so the first frame is real.
  ///
  /// [anchor] is the tray icon's screen rect and [workArea] the bounds the
  /// panel must stay inside. Both go to the panel, which positions itself once
  /// it has measured its own height: the controller cannot know that height
  /// before the panel lays out, and guessing it left the menu visibly off.
  Future<void> show({
    TrayPanelPayload? payload,
    Rect? anchor,
    Rect? workArea,
  }) async {
    if (!isSupported) {
      return;
    }
    final controller = await _ensureController();
    if (controller == null) {
      return;
    }
    if (payload != null) {
      await _invokeWithRetry(controller, updateMethod, payload.toJson());
    }
    if (anchor != null && workArea != null) {
      await _invokeWithRetry(controller, setAnchorMethod, <String, double>{
        'left': anchor.left,
        'top': anchor.top,
        'right': anchor.right,
        'bottom': anchor.bottom,
        'workLeft': workArea.left,
        'workTop': workArea.top,
        'workRight': workArea.right,
        'workBottom': workArea.bottom,
      });
    }
    // Ask the panel's engine to show and focus itself. Calling
    // WindowController.show() directly skips that path, so the panel never
    // records when it became visible and can be dismissed by the first blur.
    await _invokeWithRetry(controller, showMethod);
    _visible = true;
  }

  /// A freshly created window's Dart engine can still be booting when the
  /// first message arrives, so priming calls are retried briefly instead of
  /// being dropped and leaving the menu blank.
  Future<void> _invokeWithRetry(
    WindowController controller,
    String method, [
    Object? arguments,
  ]) async {
    for (var attempt = 0; attempt < _retryCount; attempt += 1) {
      try {
        await controller.invokeMethod<void>(method, arguments);
        return;
      } catch (_) {
        if (attempt == _retryCount - 1) {
          return;
        }
        await Future<void>.delayed(_retryGap);
      }
    }
  }

  Future<void> hide() async {
    if (!isSupported) {
      return;
    }
    final controller = _controller;
    if (controller == null || !_visible) {
      return;
    }
    await controller.hide();
    _visible = false;
  }

  Future<void> dispose() async {
    _controller = null;
  }

  Future<WindowController?> _ensureController() async {
    final existing = _controller;
    if (existing != null) return existing;
    final creating = _creatingController;
    if (creating != null) return creating;
    final future = _createController();
    _creatingController = future;
    try {
      return await future;
    } finally {
      if (identical(_creatingController, future)) {
        _creatingController = null;
      }
    }
  }

  Future<WindowController?> _createController() async {
    try {
      final controller = await WindowController.create(
        WindowConfiguration(
          hiddenAtLaunch: true,
          arguments: const RobyneWindowArguments.trayPanel().encode(),
        ),
      );
      _controller = controller;
      return controller;
    } on Object {
      _controller = null;
      return null;
    }
  }
}
