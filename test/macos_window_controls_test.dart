import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the main window hides the native macOS window buttons', () {
    final source = File('lib/app/bootstrap.dart').readAsStringSync();
    final optionsStart = source.indexOf('waitUntilReadyToShow(');
    expect(optionsStart, isNonNegative);
    final options = source.substring(
      optionsStart,
      source.indexOf(');', optionsStart),
    );

    // `TitleBarStyle.hidden` alone is not enough on macOS: the plugin makes
    // the title bar transparent and then re-shows the standard buttons, which
    // left the window with two sets of minimise/maximise/close.
    expect(options, contains('titleBarStyle: TitleBarStyle.hidden'));
    expect(options, contains('windowButtonVisibility: false'));
  });
}
