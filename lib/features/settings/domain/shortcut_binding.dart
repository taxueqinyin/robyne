import 'dart:convert';

import 'package:flutter/services.dart';

class ShortcutBinding {
  const ShortcutBinding({
    required this.triggerKeyId,
    this.control = false,
    this.alt = false,
    this.shift = false,
    this.meta = false,
    this.tapCount = 1,
  });

  final int triggerKeyId;
  final bool control;
  final bool alt;
  final bool shift;
  final bool meta;
  final int tapCount;

  LogicalKeyboardKey? get triggerKey =>
      LogicalKeyboardKey.findKeyByKeyId(triggerKeyId);

  ShortcutBinding copyWith({
    int? triggerKeyId,
    bool? control,
    bool? alt,
    bool? shift,
    bool? meta,
    int? tapCount,
  }) {
    return ShortcutBinding(
      triggerKeyId: triggerKeyId ?? this.triggerKeyId,
      control: control ?? this.control,
      alt: alt ?? this.alt,
      shift: shift ?? this.shift,
      meta: meta ?? this.meta,
      tapCount: tapCount ?? this.tapCount,
    );
  }

  bool sameChord(ShortcutBinding other) {
    return triggerKeyId == other.triggerKeyId &&
        control == other.control &&
        alt == other.alt &&
        shift == other.shift &&
        meta == other.meta;
  }

  bool matchesSinglePress(KeyEvent event) {
    return event.logicalKey.keyId == triggerKeyId &&
        _isPressed(
              LogicalKeyboardKey.controlLeft,
              LogicalKeyboardKey.controlRight,
            ) ==
            control &&
        _isPressed(LogicalKeyboardKey.altLeft, LogicalKeyboardKey.altRight) ==
            alt &&
        _isPressed(
              LogicalKeyboardKey.shiftLeft,
              LogicalKeyboardKey.shiftRight,
            ) ==
            shift &&
        _isPressed(LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.metaRight) ==
            meta;
  }

  String serialize() {
    return jsonEncode(toJson());
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'triggerKeyId': triggerKeyId,
      'control': control,
      'alt': alt,
      'shift': shift,
      'meta': meta,
      'tapCount': tapCount,
    };
  }

  static ShortcutBinding? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final map = decoded.cast<String, Object?>();
      return fromJsonMap(map);
    } catch (_) {
      return null;
    }
  }

  static ShortcutBinding? fromJsonMap(Map<String, Object?> map) {
    final triggerKeyId = map['triggerKeyId'];
    final tapCount = map['tapCount'];
    if (triggerKeyId is! num) {
      return null;
    }
    return ShortcutBinding(
      triggerKeyId: triggerKeyId.toInt(),
      control: map['control'] == true,
      alt: map['alt'] == true,
      shift: map['shift'] == true,
      meta: map['meta'] == true,
      tapCount: tapCount is num && tapCount.toInt() > 1 ? 2 : 1,
    );
  }

  static bool _isPressed(LogicalKeyboardKey left, LogicalKeyboardKey right) {
    final keyboard = HardwareKeyboard.instance;
    return keyboard.logicalKeysPressed.contains(left) ||
        keyboard.logicalKeysPressed.contains(right);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ShortcutBinding &&
        other.triggerKeyId == triggerKeyId &&
        other.control == control &&
        other.alt == alt &&
        other.shift == shift &&
        other.meta == meta &&
        other.tapCount == tapCount;
  }

  @override
  int get hashCode =>
      Object.hash(triggerKeyId, control, alt, shift, meta, tapCount);
}

extension ShortcutBindingLabelX on ShortcutBinding {
  String get displayLabel {
    final parts = <String>[
      if (control) 'Ctrl',
      if (alt) 'Alt',
      if (shift) 'Shift',
      if (meta) 'Meta',
      _triggerLabel(),
    ];
    final chord = parts.join(' + ');
    return tapCount > 1 ? '双击 $chord' : chord;
  }

  String _triggerLabel() {
    final key = triggerKey;
    if (key == null) {
      return '未知按键';
    }
    if (key == LogicalKeyboardKey.space) {
      return 'Space';
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      return '←';
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      return '→';
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      return '↑';
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      return '↓';
    }
    final label = key.keyLabel.trim();
    if (label.isNotEmpty) {
      return label.length == 1 ? label.toUpperCase() : label;
    }
    return key.debugName ?? '未知按键';
  }
}
