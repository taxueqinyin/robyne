import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/application/theme_providers.dart';
import 'router.dart';

class RobyneApp extends ConsumerWidget {
  const RobyneApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lightTheme = ref.watch(lightThemeDataProvider);
    final darkTheme = ref.watch(darkThemeDataProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Robyne',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const <Locale>[Locale('en'), Locale('zh', 'CN')],
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      home: const RobyneShell(),
    );
  }
}
