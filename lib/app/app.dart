import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/application/theme_providers.dart';
import '../core/theme/application/theme_hot_reload.dart';
import '../core/theme/infrastructure/token_resolver.dart';
import 'desktop_tray_controller.dart';
import 'main_window_controller.dart';
import 'router.dart';

class RobyneApp extends ConsumerWidget {
  const RobyneApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keeps the skin file watcher alive for the whole app session. Editing
    // `theme.json` then hot-reloads the active skin without a restart.
    ref.watch(themeHotReloadProvider);
    final lightTheme = ref.watch(lightThemeDataProvider);
    final darkTheme = ref.watch(darkThemeDataProvider);
    final themeMode = ref.watch(themeModeProvider);
    // The skin's rhythm drives the cross-fade between themes: changing skins
    // is the one animation every user sees, and it is the obvious place for a
    // skin to say "I feel snappy" or "I feel unhurried".
    final motion = ref.watch(activeThemeMotionProvider);
    ref.watch(mainWindowControllerProvider).attach();
    ref.watch(desktopTrayControllerProvider).attach();

    return MaterialApp(
      title: 'Robyne',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const <Locale>[Locale('en'), Locale('zh', 'CN')],
      themeAnimationDuration: motion.medium,
      themeAnimationCurve: motion.curve.toCurve,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      home: Builder(
        builder: (context) {
          registerTrayRootContext(context);
          return const RobyneShell();
        },
      ),
    );
  }
}
