import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/features/search/application/search_history_controller.dart';
import 'package:robyne/features/search/domain/search_history_entry.dart';
import 'package:robyne/shared/widgets/search_field_with_history.dart';

/// The panel's box in the root overlay, and what that box means for the page
/// underneath it.
///
/// The root overlay lays its non-positioned children out with
/// `BoxConstraints.tight(viewportSize)`, so a follower that declares no width
/// inherits the whole viewport. The panel then covers the bottom-right of the
/// page, and — because the outside-dismiss route compares presses against that
/// box — every press on the page below reads as "inside the panel", which is
/// why tapping history (and everything else) did nothing.
void main() {
  testWidgets('the panel fills only the field width, not the viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900) * 3;
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer(
      overrides: [
        searchHistoryControllerProvider.overrideWith(_SeededHistory.new),
      ],
    );
    addTearDown(container.dispose);
    final focus = FocusNode();
    final controller = TextEditingController();
    addTearDown(focus.dispose);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Row(
              children: <Widget>[
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: SearchFieldWithHistory(
                      controller: controller,
                      focusNode: focus,
                      onSubmit: (_) {},
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    focus.requestFocus();
    await tester.pumpAndSettle();

    final panelBox = tester.renderObject<RenderBox>(
      find.byKey(const Key('search-history-panel')).first,
    );
    final panelRect = panelBox.localToGlobal(Offset.zero) & panelBox.size;

    // The bug: 1280x900, i.e. the whole viewport, anchored over the page.
    expect(panelRect.width, closeTo(360, 1));
    // And it hangs under the field, which is where a suggestion list belongs.
    final fieldRect =
        tester
            .renderObject<RenderBox>(find.byType(TextField).first)
            .localToGlobal(Offset.zero) &
        tester.renderObject<RenderBox>(find.byType(TextField).first).size;
    expect(panelRect.left, closeTo(fieldRect.left, 1));
    expect(panelRect.top, greaterThanOrEqualTo(fieldRect.bottom - 1));
  });

  testWidgets('the panel follows the field on a phone-width window', (
    tester,
  ) async {
    // 400dp: the compact inset applies, and the field is only 200dp wide
    // because it shares the row with a `Spacer`.
    tester.view.physicalSize = const Size(400, 800) * 3;
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer(
      overrides: [
        searchHistoryControllerProvider.overrideWith(_SeededHistory.new),
      ],
    );
    addTearDown(container.dispose);
    final focus = FocusNode();
    final controller = TextEditingController();
    addTearDown(focus.dispose);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Row(
              children: <Widget>[
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: SearchFieldWithHistory(
                      controller: controller,
                      focusNode: focus,
                      onSubmit: (_) {},
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    focus.requestFocus();
    await tester.pumpAndSettle();

    final panelBox = tester.renderObject<RenderBox>(
      find.byKey(const Key('search-history-panel')).first,
    );
    final fieldBox = tester.renderObject<RenderBox>(
      find.byType(TextField).first,
    );
    final panelRect = panelBox.localToGlobal(Offset.zero) & panelBox.size;
    final fieldRect = fieldBox.localToGlobal(Offset.zero) & fieldBox.size;

    // Sized to the field, inset by the compact gutter, and below it.
    expect(panelRect.width, closeTo(fieldRect.width, 1));
    expect(panelRect.right, lessThanOrEqualTo(400));
    expect(panelRect.top, greaterThanOrEqualTo(fieldRect.bottom - 1));
  });

  testWidgets('a press on the page below the panel is outside it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900) * 3;
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer(
      overrides: [
        searchHistoryControllerProvider.overrideWith(_SeededHistory.new),
      ],
    );
    addTearDown(container.dispose);
    final focus = FocusNode();
    final controller = TextEditingController();
    addTearDown(focus.dispose);
    addTearDown(controller.dispose);
    final pressed = <String>[];

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                SearchFieldWithHistory(
                  controller: controller,
                  focusNode: focus,
                  onSubmit: (_) {},
                ),
                // Stands in for the results list: a control the user must be
                // able to reach while the suggestion panel is open.
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: TextButton(
                      onPressed: () => pressed.add('below'),
                      child: const Text('Below the panel'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    focus.requestFocus();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Below the panel'));
    await tester.pumpAndSettle();

    // The old 1280x900 panel rect contained this point, so the press was read
    // as "inside the panel" and the button was never reached.
    expect(pressed, <String>['below']);
    // Reaching it takes focus away, which dismisses the panel.
    expect(find.text('Recent searches'), findsNothing);
  });

  testWidgets('a mouse press on a row still picks it', (tester) async {
    // Desktop is the app's main surface, and a mouse is not a finger: focus
    // moves on `PointerDownEvent`, so the field reported a blur *before* the
    // button came up. Closing on that blur removed the row mid-gesture, its
    // recognizer died with it, and picking a remembered keyword did nothing.
    // Every test here used to drive taps as touches, which is why it never
    // showed up in CI.
    tester.view.physicalSize = const Size(1280, 900) * 3;
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer(
      overrides: [
        searchHistoryControllerProvider.overrideWith(_SeededHistory.new),
      ],
    );
    addTearDown(container.dispose);
    final focus = FocusNode();
    final controller = TextEditingController();
    addTearDown(focus.dispose);
    addTearDown(controller.dispose);
    final submitted = <String>[];

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Row(
              children: <Widget>[
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: SearchFieldWithHistory(
                      controller: controller,
                      focusNode: focus,
                      onSubmit: submitted.add,
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    focus.requestFocus();
    await tester.pumpAndSettle();

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(find.text('moonhalo').first));
    await tester.pumpAndSettle();
    await mouse.down(tester.getCenter(find.text('moonhalo').first));
    // The row must survive the whole gesture, not just the first frame of it.
    await tester.pump();
    expect(find.text('moonhalo'), findsOneWidget);
    await mouse.up();
    await tester.pumpAndSettle();

    expect(submitted, <String>['moonhalo']);
    expect(controller.text, 'moonhalo');
  });
}

class _SeededHistory extends SearchHistoryController {
  @override
  Future<List<SearchHistoryEntry>> build() async => <SearchHistoryEntry>[
    SearchHistoryEntry(keyword: 'moonhalo', searchedAt: DateTime(2026, 1, 2)),
    SearchHistoryEntry(keyword: 'jay chou', searchedAt: DateTime(2026, 1, 1)),
  ];
}
