import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/features/player/presentation/progress_slider.dart';

void main() {
  Future<void> pumpSlider(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: ProgressSlider(
                value: 30,
                max: 180,
                activeColor: Colors.red,
                inactiveColor: Colors.grey,
                onChanged: (value) {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('progress line has no thumb until the pointer enters', (
    tester,
  ) async {
    await pumpSlider(tester);

    final theme = tester.widget<SliderTheme>(find.byType(SliderTheme).first);
    expect(theme.data.thumbShape, same(SliderComponentShape.noThumb));

    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await pointer.addPointer(
      location: tester.getCenter(find.byType(ProgressSlider)),
    );
    await tester.pump();

    final hovered = tester.widget<SliderTheme>(find.byType(SliderTheme).first);
    expect(hovered.data.thumbShape, isA<RoundSliderThumbShape>());
  });

  testWidgets('dragging without a visible thumb still seeks', (tester) async {
    final positions = <Duration>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: ProgressSlider(
                value: 30,
                max: 180,
                activeColor: Colors.red,
                inactiveColor: Colors.grey,
                onChangeEnd: (value) =>
                    positions.add(Duration(milliseconds: value.round())),
              ),
            ),
          ),
        ),
      ),
    );

    final slider = find.byType(Slider).first;
    await tester.drag(slider, const Offset(100, 0));
    await tester.pump();

    expect(positions, isNotEmpty);
  });

  testWidgets('seeking is deferred to drag end, not every pointer move', (
    tester,
  ) async {
    final commits = <double>[];
    final previews = <double>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: ProgressSlider(
                value: 30,
                max: 180,
                activeColor: Colors.red,
                inactiveColor: Colors.grey,
                onChanged: previews.add,
                onChangeEnd: commits.add,
              ),
            ),
          ),
        ),
      ),
    );

    // A slow drag produces many move events; only the release may reach the
    // player, because each commit is an audio seek plus a persisted write.
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Slider)),
    );
    for (var step = 0; step < 6; step += 1) {
      await gesture.moveBy(const Offset(12, 0));
      await tester.pump();
    }
    expect(commits, isEmpty);
    expect(previews, isNotEmpty);

    await gesture.up();
    await tester.pump();
    expect(commits, hasLength(1));
  });

  testWidgets('the track stays flat at rest and shows a thumb on hover', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: ProgressSlider(
                value: 30,
                max: 180,
                activeColor: Colors.red,
                inactiveColor: Colors.grey,
                onChangeEnd: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    SliderThemeData theme() =>
        tester.widget<SliderTheme>(find.byType(SliderTheme).first).data;

    expect(theme().thumbShape, same(SliderComponentShape.noThumb));

    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await pointer.addPointer(
      location: tester.getCenter(find.byType(ProgressSlider)),
    );
    await tester.pump();
    expect(theme().thumbShape, isA<RoundSliderThumbShape>());

    await pointer.removePointer();
    await tester.pump();
    expect(theme().thumbShape, same(SliderComponentShape.noThumb));
  });
}
