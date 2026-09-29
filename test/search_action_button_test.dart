import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/theme/application/theme_providers.dart';
import 'package:robyne/core/theme/domain/theme_strings.dart';
import 'package:robyne/shared/widgets/search_action_button.dart';

/// The button renders shell chrome, so its wording comes from the active
/// skin's `strings`. These tests run against the neutral defaults, which is
/// what a skin that declares nothing gets.
void main() {
  testWidgets('idle search button starts a search', (tester) async {
    var searched = false;
    var cancelled = false;

    await _pump(
      tester,
      isSearching: false,
      onSearch: () => searched = true,
      onCancel: () => cancelled = true,
    );

    await tester.tap(find.text('Search'));
    expect(searched, isTrue);
    expect(cancelled, isFalse);
  });

  testWidgets('searching button shows stop on hover and cancels on tap', (
    tester,
  ) async {
    var searched = false;
    var cancelled = false;

    await _pump(
      tester,
      isSearching: true,
      onSearch: () => searched = true,
      onCancel: () => cancelled = true,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Stop'), findsNothing);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.byType(SearchActionButton)));
    await tester.pump();

    // The tooltip repeats the label once it is showing, so scope the count to
    // the button itself rather than to the text.
    expect(find.text('Stop'), findsWidgets);
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.byType(SearchActionButton));
    expect(cancelled, isTrue);
    expect(searched, isFalse);
  });

  testWidgets('clicking the spinning search button cancels without hover', (
    tester,
  ) async {
    var searched = false;
    var cancelled = false;

    await _pump(
      tester,
      isSearching: true,
      onSearch: () => searched = true,
      onCancel: () => cancelled = true,
    );

    await tester.tap(find.byType(SearchActionButton));
    expect(cancelled, isTrue);
    expect(searched, isFalse);
  });

  testWidgets('a skin can rename the search action', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeThemeStringsProvider.overrideWithValue(
            ThemeStrings.parse(<String, Object?>{
              'search.action': '搜索',
              'search.stop': '停止',
            }),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SearchActionButton(
              isSearching: false,
              onSearch: () {},
              onCancel: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('搜索'), findsOneWidget);
    expect(find.text('Search'), findsNothing);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required bool isSearching,
  required VoidCallback onSearch,
  required VoidCallback onCancel,
}) {
  return tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SearchActionButton(
            isSearching: isSearching,
            onSearch: onSearch,
            onCancel: onCancel,
          ),
        ),
      ),
    ),
  );
}
