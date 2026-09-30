import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import 'main_window_state.dart';

/// Captures the main window's geometry and restores it on launch.
///
/// Window events are best-effort on Windows: a drag can finish without a
/// reliable Dart callback. The periodic reconciliation therefore owns the
/// guarantees, while the custom title-bar close path calls [persistNow] for
/// an immediate final flush.
class MainWindowController with WindowListener {
  MainWindowController({
    required MainWindowStateStore store,
    MainWindowState? initialState,
    bool attach = false,
    Duration reconciliationInterval = const Duration(seconds: 2),
  }) : _store = store,
       _reconciliationInterval = reconciliationInterval,
       _lastNormalState =
           initialState ??
           const MainWindowState(size: MainWindowState.defaultSize) {
    if (attach) {
      this.attach();
    }
  }

  final MainWindowStateStore _store;
  final Duration _reconciliationInterval;
  bool _initialized = false;
  bool _saveInFlight = false;
  bool _saveAgain = false;
  bool _suspended = false;
  Timer? _reconciliationTimer;
  MainWindowState _lastNormalState;

  /// Stops persisting geometry while the window is in another shape.
  ///
  /// The capsule collapses the window to a few hundred pixels; without this
  /// the periodic reconciliation writes that as the shell's normal geometry,
  /// which is what made "close" restore a phone-sized window.
  void suspend() {
    _suspended = true;
  }

  void resume() {
    _suspended = false;
  }

  void attach() {
    if (_initialized || !supportsMainWindowPersistence) {
      return;
    }
    _initialized = true;
    windowManager.addListener(this);
    _reconciliationTimer = Timer.periodic(
      _reconciliationInterval,
      (_) => unawaited(_reconcileGeometry()),
    );
  }

  @override
  void onWindowResize() {
    unawaited(persistNow());
  }

  @override
  void onWindowResized() {
    unawaited(persistNow());
  }

  @override
  void onWindowMove() {
    unawaited(persistNow());
  }

  @override
  void onWindowMoved() {
    unawaited(persistNow());
  }

  @override
  void onWindowClose() {
    unawaited(persistNow());
  }

  @override
  void onWindowMaximize() {
    unawaited(persistNow());
  }

  @override
  void onWindowUnmaximize() {
    unawaited(persistNow());
  }

  Future<void> persistNow() async {
    if (_suspended) {
      return;
    }
    if (_saveInFlight) {
      _saveAgain = true;
      return;
    }
    _saveInFlight = true;
    try {
      final maximized = await windowManager.isMaximized();
      if (!maximized) {
        final bounds = await windowManager.getBounds();
        if (_hasUsableBounds(bounds)) {
          _lastNormalState = MainWindowState(
            size: bounds.size,
            position: bounds.topLeft,
            maximized: false,
          );
        }
      }
      await _store.save(_lastNormalState.copyWith(maximized: maximized));
    } catch (_) {
      // Window persistence is best-effort and must never block the UI.
    } finally {
      _saveInFlight = false;
      if (_saveAgain) {
        _saveAgain = false;
        unawaited(persistNow());
      }
    }
  }

  Future<void> _reconcileGeometry() async {
    if (_suspended) {
      return;
    }
    if (_saveInFlight) {
      return;
    }
    try {
      if (await windowManager.isMaximized()) {
        return;
      }
      final bounds = await windowManager.getBounds();
      if (!_hasUsableBounds(bounds)) {
        return;
      }
      if (_sameBounds(bounds, _lastNormalState)) {
        return;
      }
      await persistNow();
    } catch (_) {
      // The window can disappear while the timer is in flight.
    }
  }

  bool _sameBounds(Rect bounds, MainWindowState state) {
    final position = state.position;
    return position != null &&
        (bounds.left - position.dx).abs() < 1 &&
        (bounds.top - position.dy).abs() < 1 &&
        (bounds.width - state.size.width).abs() < 1 &&
        (bounds.height - state.size.height).abs() < 1;
  }

  bool _hasUsableBounds(Rect bounds) {
    return bounds.left.isFinite &&
        bounds.top.isFinite &&
        bounds.width.isFinite &&
        bounds.height.isFinite &&
        bounds.width > 0 &&
        bounds.height > 0;
  }

  void dispose() {
    _reconciliationTimer?.cancel();
    windowManager.removeListener(this);
  }
}

Future<MainWindowState?> loadMainWindowState() async {
  if (!supportsMainWindowPersistence) {
    return null;
  }
  return MainWindowStateStore().load();
}

final mainWindowControllerProvider = Provider<MainWindowController>((ref) {
  final controller = MainWindowController(store: MainWindowStateStore());
  ref.onDispose(controller.dispose);
  return controller;
});
