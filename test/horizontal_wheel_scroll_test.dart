import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/shared/widgets/horizontal_wheel_scroll.dart';

void main() {
  testWidgets('a plain vertical wheel scrolls a horizontal strip', (
    tester,
  ) async {
    ScrollController? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 40,
            child: HorizontalWheelScroll(
              builder: (context, controller) {
                captured = controller;
                return ListView.separated(
                  controller: controller,
                  scrollDirection: Axis.horizontal,
                  itemCount: 30,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, index) =>
                      SizedBox(width: 120, child: Text('pill-$index')),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final strip = captured!;
    expect(strip.offset, 0);

    await _wheel(tester, const Offset(200, 20), const Offset(0, 120));
    await tester.pumpAndSettle();

    expect(strip.offset, greaterThan(0));
  });

  testWidgets('the strip cannot be scrolled past its end', (tester) async {
    ScrollController? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 40,
            child: HorizontalWheelScroll(
              builder: (context, controller) {
                captured = controller;
                return ListView.builder(
                  controller: controller,
                  scrollDirection: Axis.horizontal,
                  itemCount: 5,
                  itemBuilder: (context, index) =>
                      SizedBox(width: 40, child: Text('pill-$index')),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final strip = captured!;
    // 5 x 40dp does not overflow an 800dp tester viewport, so there is
    // nowhere to scroll — the clamp must keep pixels at 0 rather than
    // throwing when maxScrollExtent is 0.
    await _wheel(tester, const Offset(200, 20), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(strip.offset, 0);
  });
}

Future<void> _wheel(
  WidgetTester tester,
  Offset location,
  Offset scrollDelta,
) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: location);
  await tester.pump();
  await gesture.moveTo(location);
  await tester.sendEventToBinding(
    PointerScrollEvent(position: location, scrollDelta: scrollDelta),
  );
  await gesture.removePointer();
}
