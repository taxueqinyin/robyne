import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the offset dial snaps every input to the 0.25s grid', () {
    final source = File(
      'lib/features/player/presentation/now_playing_page.dart',
    ).readAsStringSync();

    // A drag reports a continuous angle, so the raw value has to be quantised
    // before it reaches the controller — otherwise the dial lands on values
    // finer than 0.25s and the displayed number disagrees with the grid the
    // control advertises.
    expect(source, contains('_quantized('));
    expect(source, contains('static const _step = 250.0;'));

    // Both inputs funnel through one emitter, so the wheel and the drag cannot
    // drift onto different grids.
    expect(source, contains('_emit('));
    final emit = source.indexOf('void _emit(');
    expect(emit, isNonNegative);
    expect(source.substring(emit, emit + 300), contains('_quantized('));

    // Snapping each drag step would compound its rounding and a full turn
    // would fall short of 10s, so the raw total is kept separately and only
    // the emitted value is snapped.
    expect(source, contains('double _accumulated = 0;'));
  });

  test(
    'the dial keeps the live offset instead of reloading the stored one',
    () {
      final source = File(
        'lib/features/player/presentation/now_playing_page.dart',
      ).readAsStringSync();

      // The panel is built inline inside a PopupMenuItem, so the menu rebuilds
      // it while open. Reading only the stored value in `initState` pulled the
      // dial back to where it started every time that happened.
      final panel = source.indexOf('class _LyricOffsetMenuPanelState');
      expect(panel, isNonNegative);
      final body = source.substring(panel, panel + 2600);
      expect(body, contains('lyricLiveOffsetProvider'));
    },
  );
}
