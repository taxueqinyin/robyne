import 'package:flutter/services.dart';

import 'shortcut_action.dart';
import 'shortcut_binding.dart';

class ShortcutSettings {
  const ShortcutSettings({
    required Map<ShortcutAction, ShortcutBinding?> bindings,
  }) : _bindings = bindings;

  factory ShortcutSettings.defaults() {
    return ShortcutSettings(
      bindings: <ShortcutAction, ShortcutBinding?>{
        ShortcutAction.playPause: ShortcutBinding(
          triggerKeyId: LogicalKeyboardKey.space.keyId,
        ),
        ShortcutAction.nextTrack: null,
        ShortcutAction.previousTrack: null,
        ShortcutAction.volumeUp: ShortcutBinding(
          triggerKeyId: LogicalKeyboardKey.arrowUp.keyId,
        ),
        ShortcutAction.volumeDown: ShortcutBinding(
          triggerKeyId: LogicalKeyboardKey.arrowDown.keyId,
        ),
        ShortcutAction.desktopLyrics: null,
        ShortcutAction.toggleFavorite: null,
        ShortcutAction.currentLyricLine: ShortcutBinding(
          triggerKeyId: LogicalKeyboardKey.arrowLeft.keyId,
        ),
        ShortcutAction.previousLyricLine: ShortcutBinding(
          triggerKeyId: LogicalKeyboardKey.arrowLeft.keyId,
          tapCount: 2,
        ),
        ShortcutAction.nextLyricLine: ShortcutBinding(
          triggerKeyId: LogicalKeyboardKey.arrowRight.keyId,
        ),
      },
    );
  }

  final Map<ShortcutAction, ShortcutBinding?> _bindings;

  Map<ShortcutAction, ShortcutBinding?> get bindings =>
      Map<ShortcutAction, ShortcutBinding?>.unmodifiable(_bindings);

  ShortcutBinding? operator [](ShortcutAction action) => _bindings[action];

  ShortcutSettings copyWithBinding(
    ShortcutAction action,
    ShortcutBinding? binding,
  ) {
    return ShortcutSettings(
      bindings: <ShortcutAction, ShortcutBinding?>{
        ..._bindings,
        action: binding,
      },
    );
  }

  ShortcutAction? conflictingAction(
    ShortcutAction action,
    ShortcutBinding? binding,
  ) {
    if (binding == null) {
      return null;
    }
    for (final entry in _bindings.entries) {
      if (entry.key == action) {
        continue;
      }
      final existing = entry.value;
      if (existing != null &&
          existing.tapCount == binding.tapCount &&
          existing.sameChord(binding)) {
        return entry.key;
      }
    }
    return null;
  }
}
