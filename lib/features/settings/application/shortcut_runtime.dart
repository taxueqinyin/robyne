import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/shortcut_action.dart';
import '../domain/shortcut_binding.dart';

final shortcutCaptureActiveProvider =
    NotifierProvider<ShortcutCaptureActiveNotifier, bool>(
      ShortcutCaptureActiveNotifier.new,
    );

class ShortcutCaptureActiveNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setActive(bool active) {
    state = active;
  }
}

ShortcutBinding? shortcutBindingFromKeyEvent(
  KeyEvent event, {
  required int tapCount,
}) {
  if (event is! KeyDownEvent || isModifierKey(event.logicalKey)) {
    return null;
  }
  final pressed = HardwareKeyboard.instance.logicalKeysPressed;
  return ShortcutBinding(
    triggerKeyId: event.logicalKey.keyId,
    control:
        pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight),
    alt:
        pressed.contains(LogicalKeyboardKey.altLeft) ||
        pressed.contains(LogicalKeyboardKey.altRight),
    shift:
        pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight),
    meta:
        pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight),
    tapCount: tapCount,
  );
}

bool isModifierKey(LogicalKeyboardKey key) {
  return key == LogicalKeyboardKey.shiftLeft ||
      key == LogicalKeyboardKey.shiftRight ||
      key == LogicalKeyboardKey.controlLeft ||
      key == LogicalKeyboardKey.controlRight ||
      key == LogicalKeyboardKey.altLeft ||
      key == LogicalKeyboardKey.altRight ||
      key == LogicalKeyboardKey.metaLeft ||
      key == LogicalKeyboardKey.metaRight;
}

class ShortcutTracker {
  ShortcutTracker({this.doubleTapWindow = const Duration(milliseconds: 350)});

  final Duration doubleTapWindow;
  ShortcutBinding? _pendingDoubleTapBinding;
  DateTime? _pendingDoubleTapAt;

  T? match<T>(KeyEvent event, List<(T, ShortcutBinding)> matches) {
    if (event is! KeyDownEvent) {
      return null;
    }
    if (matches.isEmpty) {
      if (!isModifierKey(event.logicalKey)) {
        reset();
      }
      return null;
    }

    final now = DateTime.now();
    final single = _firstMatch(matches, tapCount: 1);
    final doubleTap = _firstMatch(matches, tapCount: 2);

    if (doubleTap != null && _isDoubleTapReady(doubleTap.$2, now)) {
      reset();
      return doubleTap.$1;
    }

    if (single != null) {
      if (doubleTap != null) {
        _pendingDoubleTapBinding = single.$2;
        _pendingDoubleTapAt = now;
      } else {
        reset();
      }
      return single.$1;
    }

    if (doubleTap != null) {
      _pendingDoubleTapBinding = doubleTap.$2.copyWith(tapCount: 1);
      _pendingDoubleTapAt = now;
    }
    return null;
  }

  void reset() {
    _pendingDoubleTapBinding = null;
    _pendingDoubleTapAt = null;
  }

  (T, ShortcutBinding)? _firstMatch<T>(
    List<(T, ShortcutBinding)> matches, {
    required int tapCount,
  }) {
    for (final match in matches) {
      if (match.$2.tapCount == tapCount) {
        return match;
      }
    }
    return null;
  }

  bool _isDoubleTapReady(ShortcutBinding binding, DateTime now) {
    final pendingBinding = _pendingDoubleTapBinding;
    final pendingAt = _pendingDoubleTapAt;
    if (pendingBinding == null || pendingAt == null) {
      return false;
    }
    if (!pendingBinding.sameChord(binding)) {
      return false;
    }
    return now.difference(pendingAt) <= doubleTapWindow;
  }
}

List<(ShortcutAction, ShortcutBinding)> matchingShortcutActions(
  KeyEvent event,
  Map<ShortcutAction, ShortcutBinding?> bindings,
) {
  if (event is! KeyDownEvent) {
    return const <(ShortcutAction, ShortcutBinding)>[];
  }
  final matches = <(ShortcutAction, ShortcutBinding)>[];
  for (final entry in bindings.entries) {
    final binding = entry.value;
    if (binding != null && binding.matchesSinglePress(event)) {
      matches.add((entry.key, binding));
    }
  }
  return matches;
}
