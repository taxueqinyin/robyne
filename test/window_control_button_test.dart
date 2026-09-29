import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/theme/application/theme_providers.dart';
import 'package:robyne/shared/widgets/window_control_button.dart';

import 'support/xuan_fixture.dart';

void main() {
  testWidgets('minimise and maximise expose a visible hover state', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Object>[
          baseThemePackageProvider.overrideWithValue(xuanFixture()),
        ].cast(),
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            theme: ref.watch(darkThemeDataProvider),
            home: Scaffold(
              body: Row(
                children: <Widget>[
                  WindowControlButton(
                    key: const Key('minimise'),
                    icon: Icons.horizontal_rule,
                    tooltip: '最小化',
                    onPressed: () {},
                  ),
                  WindowControlButton(
                    key: const Key('maximise'),
                    icon: Icons.crop_square,
                    tooltip: '最大化',
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    Color? backgroundFor(Key key) {
      final button = tester.widget<IconButton>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byType(IconButton),
        ),
      );
      return button.style?.backgroundColor?.resolve(<WidgetState>{});
    }

    final minimisedRest = backgroundFor(const Key('minimise'));
    final maximisedRest = backgroundFor(const Key('maximise'));
    expect(minimisedRest, Colors.transparent);
    expect(maximisedRest, Colors.transparent);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(find.byKey(const Key('minimise'))));
    await tester.pump();

    final minimisedHover = tester
        .widget<IconButton>(
          find.descendant(
            of: find.byKey(const Key('minimise')),
            matching: find.byType(IconButton),
          ),
        )
        .style
        ?.backgroundColor
        ?.resolve(<WidgetState>{WidgetState.hovered});
    expect(minimisedHover, isNot(Colors.transparent));
    expect(minimisedHover, isNot(minimisedRest));
    await mouse.removePointer();
  });
}
