import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/features/downloads/domain/download_audio_format.dart';
import 'package:robyne/features/settings/application/settings_providers.dart';
import 'package:robyne/features/settings/domain/lyric_settings.dart';
import 'package:robyne/features/settings/domain/shortcut_action.dart';
import 'package:robyne/features/settings/domain/shortcut_binding.dart';
import 'package:robyne/features/settings/domain/shortcut_settings.dart';
import 'package:robyne/features/settings/domain/user_settings.dart';
import 'package:robyne/features/settings/presentation/settings_page.dart';

void main() {
  testWidgets('settings page exposes shortcut tab and records a shortcut', (
    tester,
  ) async {
    late _FakeSettingsController controller;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsControllerProvider.overrideWith(() {
            controller = _FakeSettingsController();
            return controller;
          }),
        ],
        child: const MaterialApp(home: Scaffold(body: SettingsPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('常规'), findsOneWidget);
    expect(find.text('快捷键'), findsOneWidget);
    expect(find.text('歌词'), findsOneWidget);

    await tester.tap(find.text('快捷键'));
    await tester.pumpAndSettle();

    expect(find.text('播放 / 暂停'), findsOneWidget);
    expect(find.text('Space'), findsOneWidget);

    await tester.tap(find.text('下一首'));
    await tester.pumpAndSettle();
    expect(find.text('设置 下一首'), findsOneWidget);

    await tester.tap(find.text('双击'));
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyK);
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(controller.savedActions, <ShortcutAction>[ShortcutAction.nextTrack]);
    expect(
      controller.state.value!.shortcuts[ShortcutAction.nextTrack]?.displayLabel,
      '双击 K',
    );
  });

  testWidgets('lyrics tab exposes desktop lyric controls', (tester) async {
    late _FakeSettingsController controller;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsControllerProvider.overrideWith(() {
            controller = _FakeSettingsController();
            return controller;
          }),
        ],
        child: const MaterialApp(home: Scaffold(body: SettingsPage())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('歌词'));
    await tester.pumpAndSettle();

    expect(find.text('显示桌面歌词'), findsOneWidget);
    expect(find.text('双排模式'), findsOneWidget);
    expect(find.text('歌词字体大小'), findsOneWidget);
    expect(find.byType(Card), findsNothing);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(controller.state.value!.lyricSettings.desktopLyricsEnabled, isTrue);

    await tester.ensureVisible(find.byTooltip('增大字号'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('增大字号'));
    await tester.pumpAndSettle();
    expect(controller.state.value!.lyricSettings.desktopLyricFontSize, 30);

    await tester.scrollUntilVisible(
      find.text('歌词描边颜色'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('不描边'), findsOneWidget);
    await tester.pumpAndSettle();
    await tester.tap(find.text('不描边'));
    await tester.pumpAndSettle();
    expect(
      controller.state.value!.lyricSettings.desktopLyricStrokeColorValue,
      LyricSettings.noStrokeColorValue,
    );
  });
}

class _FakeSettingsController extends SettingsController {
  _FakeSettingsController()
    : _settings = UserSettings(
        cacheSizeBytes: 1024 * 1024 * 1024,
        cacheDirectoryPath: 'C:/cache',
        downloadsDirectoryPath: 'C:/downloads',
        downloadAudioFormat: DownloadAudioFormat.original,
        shortcuts: ShortcutSettings.defaults(),
        lyricSettings: const LyricSettings.defaults(),
        activeThemeId: UserSettings.defaultActiveThemeId,
        themeModeOverrideName: UserSettings.defaultThemeModeOverrideName,
        themeSettingValues: const <String, Object>{},
      );

  UserSettings _settings;
  final savedActions = <ShortcutAction>[];

  @override
  Future<UserSettings> build() async => _settings;

  @override
  Future<void> setShortcutBinding(
    ShortcutAction action,
    ShortcutBinding? binding,
  ) async {
    savedActions.add(action);
    _settings = _settings.copyWith(
      shortcuts: _settings.shortcuts.copyWithBinding(action, binding),
    );
    state = AsyncData(_settings);
  }

  @override
  Future<void> setDesktopLyricsEnabled(bool enabled) async {
    _settings = _settings.copyWith(
      lyricSettings: _settings.lyricSettings.copyWith(
        desktopLyricsEnabled: enabled,
      ),
    );
    state = AsyncData(_settings);
  }

  @override
  Future<void> adjustDesktopLyricFontSize(int delta) async {
    _settings = _settings.copyWith(
      lyricSettings: _settings.lyricSettings.copyWith(
        desktopLyricFontSize:
            _settings.lyricSettings.desktopLyricFontSize + delta,
      ),
    );
    state = AsyncData(_settings);
  }

  @override
  Future<void> setDesktopLyricStrokeColorValue(int colorValue) async {
    _settings = _settings.copyWith(
      lyricSettings: _settings.lyricSettings.copyWith(
        desktopLyricStrokeColorValue: colorValue,
      ),
    );
    state = AsyncData(_settings);
  }
}
