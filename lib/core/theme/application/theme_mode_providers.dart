import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/settings/application/settings_providers.dart';

/// How the user wants brightness resolved: system, or forced light/dark.
///
/// `ThemeMode.system` means "defer to the skin's own preference".
final themeModeOverrideProvider =
    NotifierProvider<ThemeModeOverrideNotifier, ThemeMode>(
      ThemeModeOverrideNotifier.new,
    );

class ThemeModeOverrideNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final settings = ref.watch(settingsControllerProvider).value;
    return themeModeFromName(settings?.themeModeOverrideName);
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref
        .read(settingsControllerProvider.notifier)
        .setThemeModeOverride(mode.name);
  }
}

ThemeMode themeModeFromName(String? name) {
  return ThemeMode.values.firstWhere(
    (mode) => mode.name == name,
    orElse: () => ThemeMode.system,
  );
}
