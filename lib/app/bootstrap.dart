import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import '../core/debug/ime_trace.dart';
import '../features/lyrics/presentation/desktop_lyric_window.dart';
import '../features/tray/presentation/tray_panel_window.dart';
import 'app.dart';
import 'main_window_controller.dart';
import 'main_window_state.dart';
import 'window_arguments.dart';

Future<void> bootstrap([List<String> args = const <String>[]]) async {
  WidgetsFlutterBinding.ensureInitialized();
  ImeTraceProbe.install();

  final windowArguments = await _resolveWindowArguments();
  if (windowArguments.type == RobyneWindowType.desktopLyrics) {
    await configureDesktopLyricWindow();
    runApp(const DesktopLyricWindowApp());
    return;
  }

  if (windowArguments.type == RobyneWindowType.trayPanel) {
    await configureTrayPanelWindow();
    runApp(const TrayPanelWindowApp());
    return;
  }

  MediaKit.ensureInitialized();
  final mainWindowState = await loadMainWindowState();
  await _configureMainWindow(mainWindowState);
  final mainWindowController = MainWindowController(
    store: MainWindowStateStore(),
    initialState: mainWindowState,
    attach: true,
  );
  runApp(
    ProviderScope(
      overrides: [
        mainWindowControllerProvider.overrideWithValue(mainWindowController),
      ],
      child: const RobyneApp(),
    ),
  );
}

/// Hides the native title bar so the app can draw its own window controls.
///
/// `window_manager` keeps the resize borders and the system menu (Alt+Space,
/// Snap, the taskbar thumbnail buttons) alive after `TitleBarStyle.hidden`, so
/// the window stays a normal OS window — only the strip of chrome is gone,
/// replaced by the buttons the skin draws in the top bar.
Future<void> _configureMainWindow(MainWindowState? savedState) async {
  if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    return;
  }
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      titleBarStyle: TitleBarStyle.hidden,
      minimumSize: MainWindowState.minimumSize,
    ),
  );
  // Every native close entry point — Alt+F4, the Alt+Tab thumbnail's close
  // button and the taskbar's "Close window" command — arrives as WM_CLOSE.
  // Intercept it from the first visible frame so those paths reach the tray
  // close decision the Flutter title bar uses instead of destroying the
  // window outright.
  await windowManager.setPreventClose(true);
  if (savedState != null) {
    final workArea = await _mainWindowWorkArea(savedState.position);
    await windowManager.setBounds(
      restoreMainWindowBounds(state: savedState, workArea: workArea),
    );
    if (savedState.maximized) {
      await windowManager.maximize();
    }
  } else {
    await windowManager.center();
  }
  await windowManager.show();
  await windowManager.focus();
}

Future<Rect> _mainWindowWorkArea(Offset? savedPosition) async {
  try {
    final displays = await screenRetriever.getAllDisplays();
    for (final display in displays) {
      final area = _displayWorkArea(display);
      if (savedPosition != null && area.contains(savedPosition)) {
        return area;
      }
    }
    final primary = _displayWorkArea(await screenRetriever.getPrimaryDisplay());
    if (primary.width > 0 && primary.height > 0) {
      return primary;
    }
  } catch (_) {
    // The display binding can be unavailable during startup.
  }
  return windowManager.getBounds();
}

Rect _displayWorkArea(Display display) {
  final position = display.visiblePosition ?? Offset.zero;
  final size = display.visibleSize ?? display.size;
  return Rect.fromLTWH(position.dx, position.dy, size.width, size.height);
}

Future<RobyneWindowArguments> _resolveWindowArguments() async {
  if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    return const RobyneWindowArguments.main();
  }
  try {
    final controller = await WindowController.fromCurrentEngine();
    return RobyneWindowArguments.parse(controller.arguments);
  } catch (_) {
    return const RobyneWindowArguments.main();
  }
}
