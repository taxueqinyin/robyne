import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/app/app_version.dart';
import 'package:robyne/app/router.dart';
import 'package:robyne/core/theme/application/theme_providers.dart';

import 'support/xuan_fixture.dart';

void main() {
  testWidgets(
    'the desktop rail opens About with the app version and project URL',
    (tester) async {
      tester.view.physicalSize =
          const Size(1280, 900) * tester.view.devicePixelRatio;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Object>[
            baseThemePackageProvider.overrideWithValue(xuanFixture()),
          ].cast(),
          child: Consumer(
            builder: (context, ref, _) => MaterialApp(
              theme: ref.watch(darkThemeDataProvider),
              home: const RobyneShell(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Robyne MVP'), findsNothing);
      expect(find.byKey(const Key('about-button')), findsOneWidget);
      expect(find.text(shortAppVersion), findsOneWidget);

      await tester.tap(find.byKey(const Key('about-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('about-dialog')), findsOneWidget);
      expect(find.text('当前版本 v$appVersion'), findsOneWidget);
      expect(find.byKey(const Key('about-repository-url')), findsOneWidget);
      expect(find.text(robyneRepositoryUrl), findsOneWidget);

      await tester.tap(find.byKey(const Key('about-close')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('about-dialog')), findsNothing);
    },
  );
}
