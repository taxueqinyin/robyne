import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('left click restores the app and right click toggles the panel', () {
    final source = File(
      'lib/app/desktop_tray_controller.dart',
    ).readAsStringSync();
    final leftStart = source.indexOf('void onTrayIconMouseDown()');
    final rightStart = source.indexOf('void onTrayIconRightMouseDown()');
    final mouseUpStart = source.indexOf('void onTrayIconMouseUp()');

    expect(leftStart, isNonNegative);
    expect(rightStart, greaterThan(leftStart));
    expect(mouseUpStart, greaterThan(rightStart));

    final leftHandler = source.substring(leftStart, rightStart);
    final rightHandler = source.substring(rightStart, mouseUpStart);

    expect(leftHandler, contains('_restoreMainWindow()'));
    expect(leftHandler, isNot(contains('_togglePanel()')));
    expect(rightHandler, contains('_togglePanel()'));
    expect(rightHandler, isNot(contains('_restoreMainWindow()')));
  });
}
