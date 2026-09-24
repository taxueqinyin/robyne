import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/theme/domain/theme_layout.dart';
import 'package:robyne/core/theme/domain/theme_package.dart';
import 'package:robyne/core/theme/domain/theme_tokens.dart';
import 'package:robyne/core/theme/presentation/theme_setting_control.dart';

void main() {
  const brandSetting = ThemeSetting(
    key: 'brandColor',
    type: ThemeSettingType.color,
    label: '强调色',
    defaultValue: '#2F6FED',
    target: 'color.brand.base',
  );

  ThemePackage testPackage() {
    return ThemePackage(
      id: 'test',
      name: 'Test',
      author: 'Test',
      authorUrl: null,
      version: '1.0.0',
      description: '',
      preview: null,
      tags: const <String>[],
      mode: ThemeModePreference.light,
      schemaVersion: 1,
      tokens: const ThemeTokens.baseline(),
      layout: const ThemeLayout.baseline(),
      settings: const <ThemeSetting>[brandSetting],
      assets: const ThemeAssets.empty(),
      source: ThemeSource.builtIn,
    );
  }

  Widget buildControl(Object value) {
    return MaterialApp(
      home: Scaffold(
        body: ThemeSettingControl(
          theme: testPackage(),
          setting: brandSetting,
          value: value,
        ),
      ),
    );
  }

  /// Rendered sizes of every palette tile, found through the ink wells that
  /// make them tappable.
  List<double> swatchSizes(WidgetTester tester) {
    return tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .map((container) => container.constraints!.maxWidth)
        .toList();
  }

  testWidgets('exactly one swatch is enlarged when a colour is selected', (
    tester,
  ) async {
    await tester.pumpWidget(buildControl('#2F6FED'));
    await tester.pumpAndSettle();

    final sizes = swatchSizes(tester);
    // One tile per palette entry, plus the sum swatch owned by the label row.
    expect(sizes.length, 10);
    expect(sizes.where((size) => size == 48).length, 1);
    expect(sizes.where((size) => size == 32).length, 9);
  });

  testWidgets('a selected pale colour still reads as selected', (tester) async {
    // Regression: selection used to be signalled by a white outline, which
    // vanished on near-white palette entries.
    await tester.pumpWidget(buildControl('#E8EAED'));
    await tester.pumpAndSettle();

    final sizes = swatchSizes(tester);
    expect(sizes.where((size) => size == 48).length, 1);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('no swatch is enlarged when nothing matches the palette', (
    tester,
  ) async {
    await tester.pumpWidget(buildControl('#123456'));
    await tester.pumpAndSettle();

    final sizes = swatchSizes(tester);
    expect(sizes.where((size) => size == 48), isEmpty);
    expect(find.byIcon(Icons.check), findsNothing);
  });

  testWidgets('a range knob reports its current value', (tester) async {
    const radiusSetting = ThemeSetting(
      key: 'cornerRadius',
      type: ThemeSettingType.range,
      label: '圆角',
      defaultValue: 10,
      min: 0,
      max: 28,
      target: 'radius.md',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ThemeSettingControl(
            theme: testPackage(),
            setting: radiusSetting,
            value: 24,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('24'), findsOneWidget);
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, 24);
    expect(slider.min, 0);
    expect(slider.max, 28);
  });
}
