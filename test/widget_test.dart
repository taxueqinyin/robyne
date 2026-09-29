import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/app/app.dart';
import 'package:robyne/core/theme/application/theme_providers.dart';

import 'support/xuan_fixture.dart';

void main() {
  testWidgets('renders app shell', (tester) async {
    tester.view.physicalSize =
        const Size(1280, 900) * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Object>[
          baseThemePackageProvider.overrideWithValue(xuanFixture()),
        ].cast(),
        child: const RobyneApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Flagship《玄》first viewport: branded rail, content column, and the
    // player bar. Search is a chrome action rather than a nav destination.
    expect(find.byKey(const Key('shell-content')), findsOneWidget);
    expect(find.byKey(const Key('shell-nav-left')), findsOneWidget);
    // Navigation labels come from the skin; 《玄》names them in Chinese.
    expect(find.text('插件'), findsOneWidget);
  });
}
