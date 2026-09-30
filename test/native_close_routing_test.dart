import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native window close reuses the Flutter title-bar close decision', () {
    final bootstrap = File('lib/app/bootstrap.dart').readAsStringSync();
    final source = File(
      'lib/app/desktop_tray_controller.dart',
    ).readAsStringSync();

    // The window is held before it is first shown, so a native close cannot
    // slip through during startup.
    expect(bootstrap, contains('setPreventClose(true)'));
    expect(
      bootstrap.indexOf('setPreventClose(true)'),
      lessThan(bootstrap.indexOf('windowManager.show()')),
    );

    // The controller observes native window events in addition to tray events.
    expect(source, contains('with TrayListener, WindowListener'));
    expect(source, contains('windowManager.addListener(this)'));

    final handlerStart = source.indexOf('void onWindowClose()');
    expect(handlerStart, isNonNegative);
    final handler = source.substring(
      handlerStart,
      source.indexOf('Future<void> onTitleBarClose()', handlerStart),
    );
    expect(handler, contains('_closing'));
    expect(handler, contains('onTitleBarClose()'));
  });

  test('exiting releases the native close before closing the window', () {
    final source = File(
      'lib/app/desktop_tray_controller.dart',
    ).readAsStringSync();

    final exitStart = source.indexOf('Future<void> _exitApplication()');
    expect(exitStart, isNonNegative);
    final exitHandler = source.substring(
      exitStart,
      source.indexOf('Future<void> dispose()', exitStart),
    );
    expect(
      exitHandler.indexOf('setPreventClose(false)'),
      lessThan(exitHandler.indexOf('windowManager.close()')),
    );
  });
}
