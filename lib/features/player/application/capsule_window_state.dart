import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

import 'capsule_window.dart';

/// The capsule's own window position, persisted separately from the shell's.
///
/// The two layouts are different windows in the user's head: the shell is
/// wherever they parked the library, the capsule is wherever they parked the
/// mini player. Sharing one geometry meant collapsing always started at the
/// shell's top-left corner — the capsule had no memory of its own.
///
/// Only the *position* is stored. The size is fully determined by
/// [CapsuleWindow] and by whether the playlist is open, so saving it would
/// let a stale value contradict the layout.
class CapsuleWindowState {
  const CapsuleWindowState({this.position});

  static const String storageKey = 'robyne.window.capsule';

  /// Null until the user has actually moved the capsule somewhere.
  final Offset? position;

  Map<String, Object?> toJson() => <String, Object?>{
    if (position case final p?) 'left': p.dx,
    if (position case final p?) 'top': p.dy,
  };

  static CapsuleWindowState? fromJson(Object? raw) {
    if (raw is! String || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final left = _finiteDouble(decoded['left']);
      final top = _finiteDouble(decoded['top']);
      if (left == null || top == null) {
        return null;
      }
      return CapsuleWindowState(position: Offset(left, top));
    } catch (_) {
      // A corrupt value must not stop the capsule from opening.
      return null;
    }
  }

  static double? _finiteDouble(Object? value) {
    if (value is! num || !value.isFinite) {
      return null;
    }
    return value.toDouble();
  }
}

/// Reads and writes [CapsuleWindowState] in the app's shared preferences.
class CapsuleWindowStateStore {
  Future<CapsuleWindowState?> load() async {
    final preferences = await SharedPreferences.getInstance();
    return CapsuleWindowState.fromJson(
      preferences.getString(CapsuleWindowState.storageKey),
    );
  }

  Future<void> save(CapsuleWindowState state) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        CapsuleWindowState.storageKey,
        jsonEncode(state.toJson()),
      );
    } catch (_) {
      // Position memory is best-effort and must never block the UI.
    }
  }
}

/// The capsule's rect for [position], kept inside [workArea].
///
/// Monitor topology changes while the app is closed, so a remembered position
/// on an unplugged monitor has to be pulled back on-screen rather than
/// opening the capsule somewhere invisible.
Rect capsuleBoundsAt({
  required Offset position,
  required Rect workArea,
  required bool playlistOpen,
}) {
  final size = Size(
    CapsuleWindow.windowWidth,
    CapsuleWindow.windowHeight(playlistOpen: playlistOpen),
  );
  final maxLeft = math.max<double>(workArea.left, workArea.right - size.width);
  final maxTop = math.max<double>(workArea.top, workArea.bottom - size.height);
  final left = position.dx.clamp(
    math.min<double>(workArea.left, maxLeft),
    maxLeft,
  );
  final top = position.dy.clamp(math.min<double>(workArea.top, maxTop), maxTop);
  return Rect.fromLTWH(left, top, size.width, size.height);
}
