import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import '../core/debug/ime_trace.dart';
import '../features/lyrics/presentation/desktop_lyric_window.dart';
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

  MediaKit.ensureInitialized();
  runApp(const ProviderScope(child: RobyneApp()));
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
