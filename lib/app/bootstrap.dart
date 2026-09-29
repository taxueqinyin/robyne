import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';

import '../core/debug/ime_trace.dart';
import '../features/lyrics/presentation/desktop_lyric_window.dart';
import '../features/tray/presentation/tray_panel_window.dart';
import 'app.dart';
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
  await _configureMainWindow();
  runApp(const ProviderScope(child: RobyneApp()));
}

/// Hides the native title bar so the app can draw its own window controls.
///
/// `window_manager` keeps the resize borders and the system menu (Alt+Space,
/// Snap, the taskbar thumbnail buttons) alive after `TitleBarStyle.hidden`, so
/// the window stays a normal OS window — only the strip of chrome is gone,
/// replaced by the buttons the skin draws in the top bar.
Future<void> _configureMainWindow() async {
  if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    return;
  }
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      titleBarStyle: TitleBarStyle.hidden,
      minimumSize: Size(400, 360),
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );
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
