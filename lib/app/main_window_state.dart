import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

/// The geometry of the main window as persisted across application launches.
///
/// The values are in logical pixels and use the same screen coordinate space
/// as `window_manager`. A null [position] means the window had no usable
/// saved location, so the caller should fall back to the platform default.
class MainWindowState {
  const MainWindowState({
    required this.size,
    this.position,
    this.maximized = false,
  });

  static const Size defaultSize = Size(1280, 720);
  static const Size minimumSize = Size(400, 360);

  final Size size;
  final Offset? position;
  final bool maximized;

  MainWindowState copyWith({
    Size? size,
    Object? position = _positionSentinel,
    bool? maximized,
  }) {
    return MainWindowState(
      size: size ?? this.size,
      position: identical(position, _positionSentinel)
          ? this.position
          : position as Offset?,
      maximized: maximized ?? this.maximized,
    );
  }
}

const Object _positionSentinel = Object();

/// Persists the main-window geometry outside the app database.
///
/// Window creation happens before Riverpod or Drift initialize, so the state
/// has to be available through a small standalone store in `bootstrap`.
class MainWindowStateStore {
  MainWindowStateStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences;

  static const storageKey = 'window.main.v1';

  SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync? get _prefs {
    if (_preferences != null) {
      return _preferences;
    }
    try {
      return _preferences = SharedPreferencesAsync();
    } catch (_) {
      return null;
    }
  }

  Future<MainWindowState?> load() async {
    final preferences = _prefs;
    if (preferences == null) {
      return null;
    }
    try {
      final raw = await preferences.getString(storageKey);
      if (raw == null || raw.trim().isEmpty) {
        return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final width = _finiteDouble(decoded['width']);
      final height = _finiteDouble(decoded['height']);
      if (width == null || height == null) {
        return null;
      }
      final left = _finiteDouble(decoded['left']);
      final top = _finiteDouble(decoded['top']);
      final position = left == null || top == null ? null : Offset(left, top);
      return MainWindowState(
        size: Size(
          width.clamp(MainWindowState.minimumSize.width, double.infinity),
          height.clamp(MainWindowState.minimumSize.height, double.infinity),
        ),
        position: position,
        maximized: decoded['maximized'] == true,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(MainWindowState state) async {
    final preferences = _prefs;
    if (preferences == null) {
      return;
    }
    try {
      await preferences.setString(
        storageKey,
        jsonEncode(<String, Object?>{
          'width': state.size.width,
          'height': state.size.height,
          if (state.position case final position?) 'left': position.dx,
          if (state.position case final position?) 'top': position.dy,
          'maximized': state.maximized,
        }),
      );
    } catch (_) {
      // Window persistence is best-effort and must never block shutdown.
    }
  }

  static double? _finiteDouble(Object? value) {
    if (value is! num || !value.isFinite) {
      return null;
    }
    return value.toDouble();
  }
}

/// Restores a saved geometry inside the current display work area.
///
/// Monitor topology can change while the app is closed. Keeping the top-left
/// point visible prevents a saved position on an unplugged monitor from
/// opening the window entirely off-screen.
Rect restoreMainWindowBounds({
  required MainWindowState state,
  required Rect workArea,
}) {
  final size = Size(
    _positiveDimension(
      state.size.width,
      minimum: MainWindowState.minimumSize.width,
      maximum: workArea.width,
    ),
    _positiveDimension(
      state.size.height,
      minimum: MainWindowState.minimumSize.height,
      maximum: workArea.height,
    ),
  );
  final saved = state.position;
  if (saved == null) {
    return Rect.fromLTWH(
      workArea.left + (workArea.width - size.width) / 2,
      workArea.top + (workArea.height - size.height) / 2,
      size.width,
      size.height,
    );
  }
  final maxLeft = math.max(workArea.left, workArea.right - size.width);
  final maxTop = math.max(workArea.top, workArea.bottom - size.height);
  return Rect.fromLTWH(
    saved.dx.clamp(math.min(workArea.left, maxLeft), maxLeft),
    saved.dy.clamp(math.min(workArea.top, maxTop), maxTop),
    size.width,
    size.height,
  );
}

double _positiveDimension(
  double value, {
  required double minimum,
  required double maximum,
}) {
  if (maximum < minimum) {
    return minimum;
  }
  return value.clamp(minimum, maximum);
}

/// Platform capability guard shared by bootstrap and the lifecycle listener.
bool get supportsMainWindowPersistence =>
    !Platform.environment.containsKey('FLUTTER_TEST') &&
    (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
