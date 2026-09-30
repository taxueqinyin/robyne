import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../core/theme/domain/theme_strings.dart';
import '../core/theme/application/theme_providers.dart';
import '../features/player/application/player_providers.dart';
import '../features/player/domain/playback_item.dart';
import '../features/playlists/application/playlist_providers.dart';
import '../features/playlists/domain/music_playlist.dart';
import '../features/playlists/infrastructure/playlist_repository.dart';
import '../features/settings/application/settings_providers.dart';
import '../features/settings/domain/user_settings.dart';
import '../features/tray/application/tray_panel_controller.dart';
import 'main_window_controller.dart';
import 'navigation.dart';

/// Owns the Windows tray icon and the QQ-Music-style panel that hangs off it.
///
/// `tray_manager` only paints a native popup menu, which cannot show artwork
/// or per-track controls. So the icon stays native (for the taskbar overflow,
/// tooltip and click events) while the menu itself is a borderless second
/// Flutter window — the same mechanism the desktop lyric window already uses.
/// That keeps the menu fully skinnable, gives it hover states and artwork, and
/// avoids the native menu callback crash the old 0.6.x binding hit.
final desktopTrayControllerProvider = Provider<DesktopTrayController>((ref) {
  final controller = DesktopTrayController(ref);
  ref.onDispose(controller.dispose);
  // Listeners are registered while the provider is being created, which is
  // the only moment Riverpod guarantees `Ref.listen` is safe to call.
  controller.bind();
  return controller;
});

/// Lets widgets outside the main shell (the immersive player) trigger the same
/// close/restore behaviour the title-bar close button uses.
BuildContext? _trayRootContext;

void registerTrayRootContext(BuildContext context) {
  _trayRootContext = context;
}

class DesktopTrayController with TrayListener, WindowListener {
  DesktopTrayController(this._ref);

  /// The tray icon must be a real Windows `.ico`.
  ///
  /// `tray_manager` hands the path to `LoadImage`, which only understands
  /// ICO/CUR/BMP. A PNG leaves `hIcon` null and Windows then paints an empty
  /// slot, which is exactly the "invisible tray icon" symptom. The runner's
  /// ICO is already bundled for the window/taskbar icon, so the tray reuses
  /// the very same logo the taskbar shows.
  static const _iconAsset = 'windows/runner/resources/app_icon.ico';

  final Ref _ref;
  TrayPanelController? _panel;
  bool _initialized = false;
  bool _closing = false;
  bool _handlingClose = false;
  Future<void>? _pendingShow;

  bool get _isSupported =>
      !Platform.environment.containsKey('FLUTTER_TEST') &&
      (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  /// Subscribes to the state the panel mirrors; called from the provider body.
  void bind() {
    if (!_isSupported) {
      return;
    }
    _ref.listen<AsyncValue<PlayerControllerState>>(playerControllerProvider, (
      previous,
      next,
    ) {
      unawaited(_pushPayload());
    });
    _ref.listen(playerSnapshotsProvider, (previous, next) {
      unawaited(_pushPayload());
    });
    _ref.listen<AsyncValue<List<MusicPlaylist>>>(playlistControllerProvider, (
      previous,
      next,
    ) {
      unawaited(_pushPayload());
    });
    _ref.listen(settingsControllerProvider, (previous, next) {
      unawaited(_pushPayload());
    });
  }

  /// Called once from `RobyneApp.build`; safe to call repeatedly.
  void attach() {
    if (_initialized || !_isSupported) {
      return;
    }
    _initialized = true;
    _panel = TrayPanelController();
    unawaited(_panel!.warmUp());
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      // `bootstrap` already holds the native close with `setPreventClose`;
      // this listener is what turns that intercepted event into the shared
      // tray decision below.
      windowManager.addListener(this);
    } catch (_) {
      // The in-app title bar close button still works without the listener.
    }
    try {
      trayManager.addListener(this);
      await trayManager.setIcon(_iconAsset);
      await trayManager.setToolTip('Robyne');
      await _registerPanelControlChannel();
    } catch (_) {
      // A tray failure should never take the player down.
    }
  }

  /// The panel calls back into this isolate to actually change playback.
  ///
  /// `WindowMethodChannel` in unidirectional mode routes every window's
  /// invocations to the single registered handler, so the main isolate owns
  /// the controller state and the panel stays a dumb view.
  Future<void> _registerPanelControlChannel() async {
    await trayPanelControlChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'toggle-like':
          await _toggleLike();
          return true;
        case 'previous':
          await _ref.read(playerControllerProvider.notifier).playPrevious();
          return true;
        case 'toggle-playback':
          await _togglePlayback();
          return true;
        case 'next':
          await _ref.read(playerControllerProvider.notifier).playNext();
          return true;
        case 'cycle-mode':
          await _cyclePlaybackMode();
          return true;
        case 'toggle-desktop-lyrics':
          await _ref
              .read(settingsControllerProvider.notifier)
              .toggleDesktopLyricsEnabled();
          return true;
        case 'settings':
          await _openSettings();
          return true;
        case 'show':
          await _restoreMainWindow();
          return true;
        case 'exit':
          await _exitApplication();
          return true;
        case TrayPanelController.sizeMethod:
          final arguments = call.arguments;
          if (arguments is Map) {
            final width = (arguments['width'] as num?)?.toDouble();
            final height = (arguments['height'] as num?)?.toDouble();
            if (width != null && height != null) {
              _panel?.updatePanelSize(Size(width, height));
            }
          }
          return true;
        case TrayPanelController.hiddenMethod:
          _panel?.markHidden();
          return true;
        default:
          return null;
      }
    });
  }

  /// Builds the panel's view model from state the app already holds.
  ///
  /// Deliberately synchronous and database-free: playback snapshots arrive
  /// roughly every 100ms, so anything slower here would put a query on the
  /// playback hot path. `liked` is read off the playlist controller, which is
  /// the same source the player bar's heart uses.
  TrayPanelPayload _currentPayload() {
    final playerState = _ref.read(playerControllerProvider).value;
    final item = playerState?.currentItem;
    final playing = _ref.read(playerSnapshotsProvider).value?.playing ?? false;
    final settings = _ref.read(settingsControllerProvider).value;
    final desktopLyricsEnabled =
        settings?.lyricSettings.desktopLyricsEnabled ?? false;
    final playlists = _ref.read(playlistControllerProvider).value;
    final liked =
        item != null &&
        (playlists?.any(
              (playlist) =>
                  playlist.id == PlaylistRepository.favoritesId &&
                  playlist.items.any((entry) => entry.id == item.id),
            ) ??
            false);
    return TrayPanelPayload(
      title: item?.title ?? '暂无播放',
      artist: _artistLine(item),
      playing: playing,
      liked: liked,
      desktopLyricsEnabled: desktopLyricsEnabled,
      mode: (playerState?.playbackMode ?? PlaybackMode.sequence).name,
      artworkUrl: item?.artworkUrl,
    );
  }

  static String _artistLine(PlaybackItem? item) {
    if (item == null) {
      return 'Robyne';
    }
    final artist = item.artist?.trim();
    if (artist == null || artist.isEmpty) {
      return item.platform?.trim().isNotEmpty == true
          ? item.platform!.trim()
          : 'Robyne';
    }
    return artist;
  }

  TrayPanelPayload? _lastPushed;

  /// Pushes the latest track to the panel, but only when the menu would
  /// actually look different.
  ///
  /// The snapshot stream ticks several times a second while a track plays;
  /// forwarding every tick would cross the window boundary with an identical
  /// payload and rebuild the panel for nothing.
  Future<void> _pushPayload() async {
    final panel = _panel;
    if (panel == null) {
      return;
    }
    final payload = _currentPayload();
    if (_lastPushed == payload) {
      return;
    }
    try {
      await panel.sync(payload);
      _lastPushed = payload;
    } catch (_) {
      // The panel window may be mid-teardown; leaving `_lastPushed` untouched
      // means the next event retries instead of skipping the update.
    }
  }

  @override
  void onTrayIconMouseDown() {
    // The Windows tray binding reports a left click through this callback.
    // Left click restores the app; the panel belongs to the right click.
    unawaited(_restoreMainWindow());
  }

  @override
  void onTrayIconRightMouseDown() {
    unawaited(_togglePanel());
  }

  @override
  void onTrayIconMouseUp() {}

  @override
  void onTrayIconRightMouseUp() {}

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {}

  Future<void> _togglePanel() async {
    final panel = _panel;
    if (panel == null) {
      return;
    }
    if (panel.isVisible) {
      await panel.hide();
      return;
    }
    final pending = _pendingShow;
    if (pending != null) {
      return;
    }
    final show = _showPanel();
    _pendingShow = show;
    try {
      await show;
    } finally {
      _pendingShow = null;
    }
  }

  Future<void> _showPanel() async {
    final panel = _panel;
    if (panel == null) {
      return;
    }
    Rect? anchor;
    try {
      anchor = await trayManager.getBounds();
    } catch (_) {
      // A missing anchor just means the panel keeps its last position.
    }
    await panel.show(
      payload: _currentPayload(),
      anchor: anchor,
      workArea: await _workArea(),
    );
  }

  /// The display under the cursor, which is where the tray icon was clicked.
  ///
  /// `visiblePosition`/`visibleSize` are the monitor's *work area* — the
  /// screen minus the taskbar — so a bottom-docked panel lands above the bar
  /// instead of behind it. Falls back to the main window's bounds so a missing
  /// display binding never leaves the panel unplaceable.
  Future<Rect> _workArea() async {
    try {
      final cursor = await screenRetriever.getCursorScreenPoint();
      final displays = await screenRetriever.getAllDisplays();
      for (final display in displays) {
        final area = _workAreaOf(display);
        if (area.contains(cursor)) {
          return area;
        }
      }
      final primary = _workAreaOf(await screenRetriever.getPrimaryDisplay());
      if (primary.width > 0 && primary.height > 0) {
        return primary;
      }
    } catch (_) {
      // The display binding is optional; fall through to the window bounds.
    }
    final bounds = await windowManager.getBounds();
    return bounds;
  }

  static Rect _workAreaOf(Display display) {
    final position = display.visiblePosition ?? Offset.zero;
    final size = display.visibleSize ?? display.size;
    return Rect.fromLTWH(position.dx, position.dy, size.width, size.height);
  }

  Future<void> _togglePlayback() async {
    final snapshot = _ref.read(playerSnapshotsProvider).value;
    if (snapshot?.playing == true) {
      await _ref.read(playerControllerProvider.notifier).pause();
      return;
    }
    await _ref.read(playerControllerProvider.notifier).resumeOrPlayCurrent();
  }

  Future<void> _toggleLike() async {
    final item = _ref.read(playerControllerProvider).value?.currentItem;
    if (item == null) {
      return;
    }
    await _ref.read(playlistControllerProvider.notifier).toggleFavorite(item);
    await _pushPayload();
  }

  Future<void> _cyclePlaybackMode() async {
    final controller = _ref.read(playerControllerProvider.notifier);
    final current =
        _ref.read(playerControllerProvider).value?.playbackMode ??
        PlaybackMode.sequence;
    final next = switch (current) {
      PlaybackMode.sequence => PlaybackMode.allLoop,
      PlaybackMode.allLoop => PlaybackMode.singleLoop,
      PlaybackMode.singleLoop => PlaybackMode.random,
      PlaybackMode.random => PlaybackMode.sequence,
    };
    await controller.setPlaybackMode(next);
    await _pushPayload();
  }

  Future<void> _openSettings() async {
    await _restoreMainWindow();
    _ref.read(selectedTabProvider.notifier).select(RobyneTab.settings);
  }

  /// Restores and focuses the main window from any panel action or tray click.
  Future<void> _restoreMainWindow() async {
    try {
      await windowManager.show();
      await windowManager.focus();
    } catch (_) {}
  }

  /// Native close entry points routed to the same decision as the title bar.
  @override
  void onWindowClose() {
    if (_closing) {
      return;
    }
    unawaited(onTitleBarClose());
  }

  /// The Flutter-drawn close button's configurable decision.
  Future<void> onTitleBarClose() async {
    if (!_isSupported) {
      await _exitApplication();
      return;
    }
    if (_handlingClose) {
      return;
    }
    _handlingClose = true;
    try {
      final settings =
          _ref.read(settingsControllerProvider).value ??
          await _ref.read(settingsRepositoryProvider).load();
      switch (settings.trayCloseAction) {
        case TrayCloseAction.minimizeToTray:
          await _hideToTray();
        case TrayCloseAction.exit:
          await _exitApplication();
        case TrayCloseAction.ask:
          await _askCloseAction();
      }
    } finally {
      _handlingClose = false;
    }
  }

  Future<void> _askCloseAction() async {
    final context = _trayRootContext;
    if (context == null || !context.mounted) {
      await _hideToTray();
      return;
    }
    final strings = _readStrings();
    final choice = await showDialog<_CloseChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.resolve(ThemeStringKey.trayCloseTitle)),
        content: Text(strings.resolve(ThemeStringKey.trayCloseBody)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(_CloseChoice.minimize),
            child: Text(strings.resolve(ThemeStringKey.trayCloseMinimize)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_CloseChoice.exit),
            child: Text(strings.resolve(ThemeStringKey.trayCloseExit)),
          ),
        ],
      ),
    );
    if (choice == null) {
      return;
    }
    // Remember the answer so the prompt is a one-time interruption; the
    // settings page can change it later.
    await _ref
        .read(settingsControllerProvider.notifier)
        .setTrayCloseAction(
          choice == _CloseChoice.exit
              ? TrayCloseAction.exit
              : TrayCloseAction.minimizeToTray,
        );
    if (choice == _CloseChoice.exit) {
      await _exitApplication();
      return;
    }
    await _hideToTray();
  }

  ThemeStrings _readStrings() {
    final container = ProviderScope.containerOf(
      _trayRootContext!,
      listen: false,
    );
    return container.read(activeThemeStringsProvider);
  }

  Future<void> _hideToTray() async {
    await _panel?.hide();
    await windowManager.hide();
  }

  Future<void> _exitApplication() async {
    if (_closing) {
      return;
    }
    _closing = true;
    await _ref.read(mainWindowControllerProvider).persistNow();
    try {
      await _panel?.dispose();
      await trayManager.destroy();
    } catch (_) {}
    try {
      // The close is intercepted for the tray decision, so it has to be
      // released before the programmatic close can reach WM_DESTROY.
      // `destroy()` calls `PostQuitMessage` directly, while child Flutter
      // windows are still attached to this message loop. Closing the
      // top-level window lets Windows unwind each engine in the normal order.
      await windowManager.setPreventClose(false);
      await windowManager.close();
    } catch (_) {
      exit(0);
    }
  }

  Future<void> dispose() async {
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    try {
      await trayPanelControlChannel.setMethodCallHandler(null);
    } catch (_) {}
    await _panel?.dispose();
    _panel = null;
  }
}

enum _CloseChoice { minimize, exit }
