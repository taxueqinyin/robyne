import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/app/router.dart';
import 'package:robyne/core/theme/application/theme_providers.dart';
import 'package:robyne/core/theme/domain/theme_strings.dart';
import 'package:robyne/features/discover/presentation/discover_page.dart';
import 'package:robyne/features/player/application/player_providers.dart';
import 'package:robyne/features/player/presentation/queue_page.dart';

import 'support/xuan_fixture.dart';

/// Every destination must be reachable from a phone.
///
/// The phone tab bar fits four entries, so the rest live behind the overflow
/// "more" tab. Before that existed, plugin import — and settings, downloads,
/// now playing — were simply absent on a phone: the secondary entries were
/// rendered only by the desktop rail, and no phone surface reached them.
void main() {
  testWidgets('the phone bar offers an overflow entry', (tester) async {
    await _pumpPhoneShell(tester);

    expect(find.byKey(const Key('shell-nav-more')), findsOneWidget);
  });

  testWidgets('the overflow reaches plugin import', (tester) async {
    await _pumpPhoneShell(tester);

    await tester.tap(find.byKey(const Key('shell-nav-more')));
    // Explicit pumps, not `pumpAndSettle`: the shell owns a repeating
    // animation, so settling never converges here.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 《玄》 names the plugins destination 插件.
    expect(find.text('插件'), findsWidgets);
    await tester.tap(find.text('插件').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('shell-nav-more'))),
    );
    expect(container.read(selectedTabProvider), RobyneTab.plugins);
  });

  testWidgets('every destination appears in the overflow', (tester) async {
    await _pumpPhoneShell(tester);

    await tester.tap(find.byKey(const Key('shell-nav-more')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The sheet lists the destinations the bar does not. The bar shows four;
    // the catalog has eight, and every one of the remaining four must appear
    // as a row — a destination may move into the overflow, never vanish.
    final rows = find.byType(ListTile);
    expect(rows, findsNWidgets(4));
  });

  testWidgets('the desktop header offers the plugin browser', (tester) async {
    tester.view.physicalSize =
        const Size(1280, 900) * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Object>[
          baseThemePackageProvider.overrideWithValue(xuanFixture()),
        ].cast(),
        child: const MaterialApp(home: RobyneShell()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The entry is the explore icon in the home header. Tapping it swaps the
    // home page for the plugin browser without leaving the Discover tab.
    final strings = ProviderScope.containerOf(
      tester.element(find.byType(RobyneShell)),
    ).read(activeThemeStringsProvider);
    final entry = find.byTooltip(strings.resolve(ThemeStringKey.discoverMore));
    expect(entry, findsOneWidget);
    await tester.tap(entry);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(DiscoverPage), findsOneWidget);
  });

  testWidgets('the queue toggle opens the queue drawer on a phone', (
    tester,
  ) async {
    await _pumpPhoneShell(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('shell-nav-more'))),
    );

    await tester.tap(find.byKey(const Key('player-queue-toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The phone has no docked queue column, so the toggle must still open
    // the real queue page as a drawer rather than writing unreachable state.
    expect(find.byType(QueuePage), findsOneWidget);
    expect(container.read(queuePanelVisibleProvider), isTrue);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpPhoneShell(WidgetTester tester) async {
  tester.view.physicalSize =
      const Size(400, 800) * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Object>[
        baseThemePackageProvider.overrideWithValue(xuanFixture()),
      ].cast(),
      child: const MaterialApp(home: RobyneShell()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}
