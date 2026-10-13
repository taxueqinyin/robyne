import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('both progress bars read the same resolved progress', () {
    final player = File(
      'lib/features/player/presentation/player_bar.dart',
    ).readAsStringSync();
    final immersive = File(
      'lib/features/player/presentation/now_playing_page.dart',
    ).readAsStringSync();

    // The immersive player used to derive position and duration itself, which
    // is how it showed a full bar over a 00:00 total: it trusted a snapshot
    // the player had not seeked yet. Both surfaces now read one provider.
    expect(player, contains('playbackProgressProvider'));
    expect(immersive, contains('playbackProgressProvider'));
  });

  test('the shared progress prefers remembered state while restoring', () {
    final source = File(
      'lib/features/player/application/player_providers.dart',
    ).readAsStringSync();
    final start = source.indexOf('final playbackProgressProvider');
    expect(start, isNonNegative);
    final body = source.substring(start, start + 1400);

    // A pending restore means the snapshot is not yet describing the song the
    // user is about to hear, so the remembered position is what gets shown.
    expect(body, contains('restorePending'));
    expect(body, contains('restoreTargetPosition'));
    expect(body, contains('state?.lastPosition'));
  });
}
