import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:robyne/shared/providers/app_providers.dart';
import 'package:robyne/features/debug_home/debug_home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 设置日志级别 - 输出所有日志到控制台
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('[${record.level.name}] ${record.loggerName}: ${record.message}');
    if (record.error != null) {
      print('  Error: ${record.error}');
    }
  });

  // Init runtime
  final container = ProviderContainer();
  final bridge = container.read(runtimeBridgeProvider);
  await bridge.init();

  runApp(UncontrolledProviderScope(
    container: container,
    child: const RobyneApp(),
  ));
}

class RobyneApp extends ConsumerWidget {
  const RobyneApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'robyne',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const DebugHomePage(),
    );
  }
}
