import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/shared/widgets/search_action_button.dart';

void main() {
  testWidgets('idle search button starts a search', (tester) async {
    var searched = false;
    var cancelled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchActionButton(
            isSearching: false,
            onSearch: () => searched = true,
            onCancel: () => cancelled = true,
          ),
        ),
      ),
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

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchActionButton(
            isSearching: true,
            onSearch: () => searched = true,
            onCancel: () => cancelled = true,
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Stop'), findsNothing);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.byType(SearchActionButton)));
    await tester.pump();

    expect(find.text('Stop'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.text('Stop'));
    expect(cancelled, isTrue);
    expect(searched, isFalse);
  });

  testWidgets('clicking the spinning search button cancels without hover', (
    tester,
  ) async {
    var searched = false;
    var cancelled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchActionButton(
            isSearching: true,
            onSearch: () => searched = true,
            onCancel: () => cancelled = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(SearchActionButton));
    expect(cancelled, isTrue);
    expect(searched, isFalse);
  });
}
