import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/features/lyrics/application/desktop_lyric_theme_service.dart';
import 'package:robyne/features/settings/application/shortcut_runtime.dart';
import 'package:robyne/features/settings/domain/shortcut_binding.dart';

void main() {
  test('shortcut tracker resolves second tap to double-tap action', () {
    final tracker = ShortcutTracker(
      doubleTapWindow: const Duration(seconds: 1),
    );
    final singleTap = ShortcutBinding(
      triggerKeyId: LogicalKeyboardKey.arrowLeft.keyId,
    );
    final doubleTap = singleTap.copyWith(tapCount: 2);

    final event = KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.arrowLeft,
      logicalKey: LogicalKeyboardKey.arrowLeft,
      timeStamp: Duration.zero,
    );
    final matches = <(String, ShortcutBinding)>[
      ('current', singleTap),
      ('previous', doubleTap),
    ];

    expect(tracker.match(event, matches), 'current');
    expect(tracker.match(event, matches), 'previous');
  });

  test('desktop lyric theme keeps accent hue with darker background', () {
    final theme = DesktopLyricTheme.fromAccent(const Color(0xFF6AC9A2));
    final background = HSLColor.fromColor(theme.backgroundColor);
    final title = HSLColor.fromColor(theme.titleColor);
    final subtitle = HSLColor.fromColor(theme.subtitleColor);

    expect((background.hue - title.hue).abs(), lessThan(5));
    expect(background.lightness, lessThan(title.lightness));
    expect(subtitle.lightness, lessThan(title.lightness));
  });
}
