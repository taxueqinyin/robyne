import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import '../core/debug/ime_trace.dart';
import 'app.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  ImeTraceProbe.install();
  MediaKit.ensureInitialized();
  runApp(const ProviderScope(child: RobyneApp()));
}
