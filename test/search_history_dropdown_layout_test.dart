import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/features/search/application/search_history_controller.dart';
import 'package:robyne/features/search/domain/search_history_entry.dart';
import 'package:robyne/shared/widgets/search_history_overlay.dart';
import 'package:robyne/shared/widgets/search_field_with_history.dart';

/// The dropdown's geometry and its pointer behaviour.
///
/// Both bugs here are properties of the widget, not of the shell: the panel
/// stretched to the whole overlay because the follower supplies a position but
/// no width, and a hover destroyed the row under the cursor because every
/// update tore the overlay down and rebuilt it.
void main() {
  testWidgets('the dropdown carries the field width it is given', (tester) async {
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
            body: Center(
              // 360dp mirrors the top bar's capped pill.
              child: SizedBox(
                width: 360,
                child: SearchFieldWithHistory(
                  controller: controller,
                  focusNode: focus,
                  onSubmit: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final field = find.byType(TextField).first;
    focus.requestFocus();
    await tester.pumpAndSettle();
    final fieldWidth = tester.getSize(field).width;
    // The panel is handed the field's measured width, which is what capped the
    // 1278dp panel to the field's own 360dp. Asserted on the value rather than
    // on a rendered box: the overlay keeps a second copy mid-rebuild, so any
    // single finder is ambiguous.
    final overlay = tester.widget<SearchHistoryOverlay>(
      find.byType(SearchHistoryOverlay).first,
    );
    expect(fieldWidth, closeTo(360, 1));
    expect(overlay.width, closeTo(360, 1));

    // One remove affordance per remembered keyword, plus a clear-all in the
    // panel's own header.
    expect(find.byIcon(Icons.close), findsNWidgets(2));
    expect(find.text('Recent searches'), findsOneWidget);
    expect(find.text('Clear all'), findsOneWidget);
    expect(find.byIcon(Icons.history), findsNWidgets(2));
  });

  testWidgets('hovering a row then clicking it still picks it', (tester) async {
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
            body: Center(
              child: SizedBox(
                width: 360,
                child: SearchFieldWithHistory(
                  controller: controller,
                  focusNode: focus,
                  onSubmit: submitted.add,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    focus.requestFocus();
    await tester.pumpAndSettle();
    expect(find.text('moonhalo'), findsOneWidget);

    // A real mouse hovers before pressing. Hovering used to tear the overlay
    // down and rebuild it, destroying the row under the cursor and re-entering
    // its own hover handler forever: the click never landed and the frame hung.
    final hover = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await hover.addPointer();
    await hover.moveTo(tester.getCenter(find.text('moonhalo').first));
    await tester.pumpAndSettle();

    await tester.tap(find.text('moonhalo').first);
    await tester.pumpAndSettle();

    expect(submitted, <String>['moonhalo']);
    expect(controller.text, 'moonhalo');
  });

  testWidgets('tapping the field again leaves the dropdown open', (tester) async {
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
            body: Center(
              child: SizedBox(
                width: 360,
                child: SearchFieldWithHistory(
                  controller: controller,
                  focusNode: focus,
                  onSubmit: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final field = find.byType(TextField).first;
    await tester.tap(field);
    await tester.pumpAndSettle();
    expect(find.text('Recent searches'), findsOneWidget);

    // Second tap on an already-focused field must not close it. It used to:
    // the panel's full-screen dismiss catcher sits in the root overlay, so it
    // covered the field too and swallowed the tap as an "outside" one.
    await tester.tap(field);
    await tester.pumpAndSettle();
    expect(find.text('Recent searches'), findsOneWidget);
  });

  testWidgets('losing focus dismisses the dropdown', (tester) async {
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
            body: Column(
              children: <Widget>[
                // Constrained width, and a row so the field does not stretch to
                // the column's width — otherwise the "outside" target below sits
                // inside the field's own box.
                Row(
                  children: <Widget>[
                    SizedBox(
                      width: 360,
                      child: SearchFieldWithHistory(
                        controller: controller,
                        focusNode: focus,
                        onSubmit: (_) {},
                      ),
                    ),
                  ],
                ),
                // Far from the panel, which hangs directly under the field: a
                // target just below it would land inside the panel's own box.
                // A button, so tapping it takes focus the way a real control on
                // a real page does — that blur is what dismisses the panel.
                const SizedBox(height: 600),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: const Text('Elsewhere'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();
    expect(find.text('Recent searches'), findsOneWidget);

    // A suggestion list is tied to the act of typing, so it goes away when the
    // field stops being the focus — which is what tapping any real control on a
    // real page does.
    focus.unfocus();
    await tester.pumpAndSettle();
    expect(find.text('Recent searches'), findsNothing);
  });
}
class _SeededHistory extends SearchHistoryController {
  @override
  Future<List<SearchHistoryEntry>> build() async => <SearchHistoryEntry>[
    SearchHistoryEntry(keyword: 'moonhalo', searchedAt: DateTime(2026, 1, 2)),
    SearchHistoryEntry(keyword: 'jay chou', searchedAt: DateTime(2026, 1, 1)),
  ];
}
