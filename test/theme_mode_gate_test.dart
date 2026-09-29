import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/theme/application/theme_controller.dart';
import 'package:robyne/core/theme/application/theme_providers.dart';
import 'package:robyne/core/theme/domain/theme_layout_override.dart';
import 'package:robyne/core/theme/domain/theme_package.dart';
import 'package:robyne/core/theme/infrastructure/theme_manifest_parser.dart';
import 'package:robyne/features/downloads/domain/download_audio_format.dart';
import 'package:robyne/features/settings/application/settings_providers.dart';
import 'package:robyne/features/settings/domain/lyric_settings.dart';
import 'package:robyne/features/settings/domain/shortcut_settings.dart';
import 'package:robyne/features/settings/domain/user_settings.dart';
import 'package:robyne/features/settings/presentation/theme_settings_tab.dart';

import 'support/xuan_fixture.dart';

void main() {
  testWidgets('a dark-only skin disables its unsupported light segment', (
    tester,
  ) async {
    final decoded =
        jsonDecode(File('assets/themes/xuan/theme.json').readAsStringSync())
            as Map<String, Object?>;
    final xuan = const ThemeManifestParser().tryParse(
      decoded,
      source: ThemeSource.builtIn,
    )!;
    expect(xuan.mode, ThemeModePreference.dark);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Object>[
          baseThemePackageProvider.overrideWithValue(xuanFixture()),
          themeControllerProvider.overrideWith(_SeededThemeController.new),
        ].cast(),
        child: const MaterialApp(home: Scaffold(body: ThemeSettingsTab())),
      ),
    );
    await tester.pump();

    final selector = tester.widget<SegmentedButton<ThemeMode>>(
      find.byType(SegmentedButton<ThemeMode>),
    );
    final lightSegment = selector.segments.firstWhere(
      (segment) => segment.value == ThemeMode.light,
    );
    final darkSegment = selector.segments.firstWhere(
      (segment) => segment.value == ThemeMode.dark,
    );
    expect(lightSegment.enabled, isFalse);
    expect(darkSegment.enabled, isTrue);
  });

  testWidgets('a light-only skin disables its unsupported dark segment', (
    tester,
  ) async {
    final lightOnly = xuanFixture().copyWith(
      id: 'test.light',
      name: 'Test Light',
      mode: ThemeModePreference.light,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Object>[
          baseThemePackageProvider.overrideWithValue(lightOnly),
          themeControllerProvider.overrideWith(_SeededThemeController.new),
        ].cast(),
        child: const MaterialApp(home: Scaffold(body: ThemeSettingsTab())),
      ),
    );
    await tester.pump();

    final selector = tester.widget<SegmentedButton<ThemeMode>>(
      find.byType(SegmentedButton<ThemeMode>),
    );
    final lightSegment = selector.segments.firstWhere(
      (segment) => segment.value == ThemeMode.light,
    );
    final darkSegment = selector.segments.firstWhere(
      (segment) => segment.value == ThemeMode.dark,
    );
    expect(lightSegment.enabled, isTrue);
    expect(darkSegment.enabled, isFalse);
  });

  testWidgets('an unsupported persisted mode resolves back to the skin', (
    tester,
  ) async {
    final lightOnly = xuanFixture().copyWith(
      id: 'test.light',
      mode: ThemeModePreference.light,
    );
    final container = ProviderContainer(
      overrides: <Object>[
        baseThemePackageProvider.overrideWithValue(lightOnly),
        settingsControllerProvider.overrideWith(_LightOnlySettings.new),
      ].cast(),
    );
    addTearDown(container.dispose);

    await container.read(settingsControllerProvider.future);
    expect(
      container.read(themeModeProvider),
      ThemeMode.light,
      reason: 'a light-only skin must ignore a persisted dark override',
    );
  });

  testWidgets('following a dark-only skin stays dark', (tester) async {
    final container = ProviderContainer(
      overrides: <Object>[
        baseThemePackageProvider.overrideWithValue(xuanFixture()),
        settingsControllerProvider.overrideWith(_SystemModeSettings.new),
      ].cast(),
    );
    addTearDown(container.dispose);

    await container.read(settingsControllerProvider.future);
    expect(
      container.read(themeModeProvider),
      ThemeMode.dark,
      reason: '“跟随皮肤” must resolve to the skin, not the OS brightness',
    );
  });
}

class _SystemModeSettings extends SettingsController {
  @override
  Future<UserSettings> build() async {
    return UserSettings(
      cacheSizeBytes: 1024,
      cacheDirectoryPath: 'cache',
      downloadsDirectoryPath: 'downloads',
      downloadAudioFormat: DownloadAudioFormat.original,
      shortcuts: ShortcutSettings.defaults(),
      lyricSettings: LyricSettings.defaults(),
      activeThemeId: UserSettings.defaultActiveThemeId,
      themeModeOverrideName: ThemeMode.system.name,
      themeSettingValues: const <String, Object>{},
      themeLayoutOverrides: const <String, ThemeLayoutOverride>{},
    );
  }
}

class _LightOnlySettings extends SettingsController {
  @override
  Future<UserSettings> build() async {
    return UserSettings(
      cacheSizeBytes: 1024,
      cacheDirectoryPath: 'cache',
      downloadsDirectoryPath: 'downloads',
      downloadAudioFormat: DownloadAudioFormat.original,
      shortcuts: ShortcutSettings.defaults(),
      lyricSettings: LyricSettings.defaults(),
      activeThemeId: UserSettings.defaultActiveThemeId,
      themeModeOverrideName: ThemeMode.dark.name,
      themeSettingValues: const <String, Object>{},
      themeLayoutOverrides: const <String, ThemeLayoutOverride>{},
    );
  }
}

class _SeededThemeController extends ThemeController {
  @override
  Future<ThemeState> build() async {
    final decoded =
        jsonDecode(File('assets/themes/xuan/theme.json').readAsStringSync())
            as Map<String, Object?>;
    final xuan = const ThemeManifestParser().tryParse(
      decoded,
      source: ThemeSource.builtIn,
    )!;
    return ThemeState(
      package: xuan,
      available: <ThemePackage>[xuan],
      lastError: null,
    );
  }
}
