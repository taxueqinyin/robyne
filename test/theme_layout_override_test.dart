import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:robyne/core/theme/application/theme_providers.dart';
import 'package:robyne/features/settings/application/settings_providers.dart';
import 'package:robyne/features/settings/domain/user_settings.dart';
import 'package:robyne/core/theme/domain/theme_layout.dart';
import 'package:robyne/core/theme/domain/theme_layout_override.dart';
import 'package:robyne/core/theme/domain/theme_package.dart';
import 'package:robyne/core/theme/domain/theme_regions.dart';
import 'package:robyne/core/theme/domain/theme_tokens.dart';
import 'package:robyne/features/downloads/domain/download_audio_format.dart';
import 'package:robyne/features/settings/domain/lyric_settings.dart';
import 'package:robyne/features/settings/domain/shortcut_settings.dart';

void main() {
  group('ThemeLayoutOverride', () {
    test('an absent form factor inherits instead of resetting', () {
      final override = ThemeLayoutOverride.fromJson(<String, Object?>{
        'mobile': <Object?>[
          <String, Object?>{'region': 'content', 'slot': 'center'},
          <String, Object?>{'region': 'navBar', 'slot': 'top', 'size': 0.20},
        ],
        'contentStyle': 'grid',
      });

      expect(override.desktopArrangement, isNull);
      expect(override.mobileArrangement, isNotNull);
      expect(override.contentStyle, ThemeListStyle.grid);

      final applied = override.apply(_package());
      expect(applied.layout.desktop.arrangement, RobyneArrangement.desktop);
      expect(
        applied.layout.mobile.arrangement
            .placementFor(RobyneRegion.navBar)!
            .slot,
        RobyneSlot.top,
      );
      expect(applied.layout.content.listStyle, ThemeListStyle.grid);
    });

    test('an explicit desktop list replaces only desktop', () {
      final override = ThemeLayoutOverride.fromJson(<String, Object?>{
        'desktop': <Object?>[
          <String, Object?>{'region': 'content', 'slot': 'center'},
          <String, Object?>{'region': 'navBar', 'slot': 'right', 'size': 0.18},
        ],
      });
      final applied = override.apply(_package());

      expect(
        applied.layout.desktop.arrangement
            .placementFor(RobyneRegion.navBar)!
            .slot,
        RobyneSlot.right,
      );
      expect(applied.layout.mobile.arrangement, RobyneArrangement.mobile);
    });

    test(
      'a malformed arrangement is repaired, never allowed to white-screen',
      () {
        final override = ThemeLayoutOverride.fromJson(<String, Object?>{
          'desktop': 'not-a-list',
          'mobile': <Object?>[
            <String, Object?>{'region': 'navBar', 'slot': 'left'},
          ],
        });

        expect(override.desktopArrangement, isNull);
        expect(
          override.mobileArrangement!.placementFor(RobyneRegion.content),
          isNotNull,
          reason: 'dropping content must fall back to the mobile baseline',
        );
      },
    );

    test('a ratio outside the corridor is clamped on parse', () {
      final override = ThemeLayoutOverride.fromJson(<String, Object?>{
        'desktop': <Object?>[
          <String, Object?>{'region': 'content', 'slot': 'center'},
          <String, Object?>{'region': 'navBar', 'slot': 'left', 'size': 9},
        ],
      });

      expect(
        override.desktopArrangement!.placementFor(RobyneRegion.navBar)!.size,
        RobyneArrangement.maxSize,
      );
    });

    test('JSON round-trips through the persisted shape', () {
      final original = ThemeLayoutOverride(
        desktopArrangement: RobyneArrangement.parse(<Object?>[
          <String, Object?>{'region': 'content', 'slot': 'center'},
          <String, Object?>{'region': 'queue', 'slot': 'left', 'size': 0.22},
        ], formFactor: RobyneFormFactor.desktop),
        contentStyle: ThemeListStyle.compact,
      );

      final decoded = ThemeLayoutOverride.fromJson(original.toJson());
      expect(decoded, original);
    });

    test('editing one form factor preserves the other override', () {
      // The settings editor writes one form factor at a time. It must merge
      // into the stored override rather than replacing the whole record.
      final original = ThemeLayoutOverride(
        desktopArrangement: RobyneArrangement.desktop,
        contentStyle: ThemeListStyle.list,
      );
      final editedMobile = original.copyWith(
        mobileArrangement: RobyneArrangement.mobile,
      );

      expect(editedMobile.desktopArrangement, RobyneArrangement.desktop);
      expect(editedMobile.mobileArrangement, RobyneArrangement.mobile);
      expect(editedMobile.contentStyle, ThemeListStyle.list);
    });
  });

  test(
    'the active package applies the user override over the base skin',
    () async {
      final base = _package();
      final override = ThemeLayoutOverride(
        desktopArrangement: RobyneArrangement.parse(<Object?>[
          <String, Object?>{'region': 'content', 'slot': 'center'},
          <String, Object?>{'region': 'queue', 'slot': 'left', 'size': 0.24},
        ], formFactor: RobyneFormFactor.desktop),
      );
      final container = ProviderContainer(
        overrides: [
          baseThemePackageProvider.overrideWithValue(base),
          settingsControllerProvider.overrideWith(
            () => _SeededSettingsController(
              _settings(<String, ThemeLayoutOverride>{base.id: override}),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(settingsControllerProvider.future);
      expect(
        container
            .read(activeThemePackageProvider)
            .layout
            .desktop
            .arrangement
            .placementFor(RobyneRegion.queue)!
            .slot,
        RobyneSlot.left,
      );
      expect(
        container
            .read(baseThemePackageProvider)
            .layout
            .desktop
            .arrangement
            .placementFor(RobyneRegion.queue)!
            .slot,
        RobyneSlot.right,
      );
    },
  );
}

class _SeededSettingsController extends SettingsController {
  _SeededSettingsController(this._settings);

  final UserSettings _settings;

  @override
  Future<UserSettings> build() async => _settings;
}

UserSettings _settings(Map<String, ThemeLayoutOverride> overrides) {
  return UserSettings(
    cacheSizeBytes: 1024,
    cacheDirectoryPath: '',
    downloadsDirectoryPath: '',
    downloadAudioFormat: DownloadAudioFormat.original,
    shortcuts: ShortcutSettings.defaults(),
    lyricSettings: const LyricSettings.defaults(),
    activeThemeId: 'official.dark',
    themeModeOverrideName: UserSettings.defaultThemeModeOverrideName,
    themeSettingValues: const <String, Object>{},
    themeLayoutOverrides: overrides,
  );
}

ThemePackage _package() {
  return const ThemePackage(
    id: 'official.dark',
    name: 'Dark',
    author: 'Robyne',
    authorUrl: null,
    version: '1.0.0',
    description: '',
    preview: null,
    tags: <String>[],
    mode: ThemeModePreference.dark,
    schemaVersion: 1,
    tokens: ThemeTokens.baseline(),
    layout: ThemeLayout.baseline(),
    settings: <ThemeSetting>[],
    assets: ThemeAssets.empty(),
    source: ThemeSource.builtIn,
  );
}
