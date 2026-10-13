import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/theme/application/theme_providers.dart';
import 'package:robyne/core/theme/domain/theme_strings.dart';
import 'package:robyne/features/player/domain/playback_item.dart';
import 'package:robyne/shared/widgets/song_actions_menu.dart';

import 'support/xuan_fixture.dart';

const PlaybackItem _item = PlaybackItem(
  id: 'plugin:x:A',
  type: PlaybackItemType.plugin,
  title: '测试歌曲',
  platform: 'Test',
  artist: '测试歌手',
);

void main() {
  // `showSongActionsMenu` guards against two menus opening at once with a
  // process-wide flag that only clears in the `finally` after `showMenu`
  // returns. A test that leaves the menu on screen never gets there, and the
  // flag would then silently block the next test's menu — which is exactly
  // how this file failed with "found 0 widgets" while each test passed alone.
  tearDown(endSongMenu);

  testWidgets('the shared menu offers the full action set', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pump();

    await tester.tap(find.byKey(const Key('open-menu')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // These are the actions every song surface is supposed to share. Only
    // actions that actually do something appear: an entry that opens "not
    // available yet" is worse than no entry.
    for (final label in <String>[
      '播放',
      '下一首播放',
      '添加到我喜欢',
      '添加到歌单',
      '下载',
      '分享',
      '复制歌曲信息',
    ]) {
      expect(find.text(label), findsOneWidget, reason: 'missing "$label"');
    }
    for (final label in <String>['播放相似歌曲', '查看评论', '智能曲谱']) {
      expect(
        find.text(label),
        findsNothing,
        reason: '"$label" has no implementation behind it yet',
      );
    }
    // A plugin search hit has no backing file to delete, so the row is hidden
    // rather than shown dead.
    expect(find.text('删除'), findsNothing);
  });

  testWidgets('the menu can name itself and expose a per-surface delete', (
    tester,
  ) async {
    var deleted = 0;
    await tester.pumpWidget(
      _harness(
        headerKey: ThemeStringKey.nowPlayingSongMenu,
        onDelete: () async => deleted += 1,
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('open-menu')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('歌曲相关功能'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
    await tester.tap(find.text('删除'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(deleted, 1);
  });
}

Widget _harness({
  ThemeStringKey? headerKey,
  Future<void> Function()? onDelete,
}) {
  return ProviderScope(
    overrides: [baseThemePackageProvider.overrideWithValue(xuanFixture())],
    child: MaterialApp(
      home: Scaffold(
        body: Consumer(
          builder: (context, ref, _) => Center(
            child: SongActionsMenuButton(
              key: const Key('open-menu'),
              item: _item,
              headerKey: headerKey,
              onDelete: onDelete,
            ),
          ),
        ),
      ),
    ),
  );
}
