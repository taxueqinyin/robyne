import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/theme/application/theme_providers.dart';
import 'package:robyne/features/downloads/presentation/downloads_page.dart';
import 'package:robyne/features/discover/presentation/discover_page.dart';
import 'package:robyne/features/player/presentation/queue_page.dart';
import 'package:robyne/features/plugin/application/plugin_controller.dart';
import 'package:robyne/features/plugin/domain/plugin_definition.dart';
import 'package:robyne/features/plugin/presentation/plugin_page.dart';
import 'package:robyne/features/search/presentation/search_page.dart';
import 'package:robyne/features/player/domain/playback_item.dart';
import 'package:robyne/features/player/application/player_providers.dart';

import 'support/xuan_fixture.dart';

/// The redesigns moved pages off `ListTile` and Material defaults onto
/// hand-built rows. Those rows are the ones that can overflow at 400dp, so
/// each page is pumped at phone size with data in it and checked for overflow.
void main() {
  for (final size in <Size>[const Size(400, 800), const Size(800, 360)]) {
    testWidgets('queue page fits $size', (tester) async {
      await _pumpSurface(tester, size, const QueuePage());
      expect(tester.takeException(), isNull);
    });

    testWidgets('downloads page fits $size', (tester) async {
      await _pumpSurface(tester, size, const DownloadsPage());
      expect(tester.takeException(), isNull);
    });

    testWidgets('search page fits $size', (tester) async {
      await _pumpSurface(tester, size, const SearchPage());
      expect(tester.takeException(), isNull);
    });

    testWidgets('plugin page fits $size', (tester) async {
      await _pumpSurface(tester, size, const PluginPage());
      expect(tester.takeException(), isNull);
    });

    // The source chip row sat inside a horizontal scroll view, so the `Wrap`
    // was handed unbounded width and every chip landed on one line. At 800x360
    // a long platform name pushed the row 48px past the pane. The row is a
    // `Row` on the scroll axis now; this pins that down.
    testWidgets('discover browser fits $size', (tester) async {
      await _pumpSurface(
        tester,
        size,
        const DiscoverPage(),
        plugins: <PluginDefinition>[
          for (final name in <String>['bilibili', '很长很长很长很长的插件平台名称', '网易音乐'])
            PluginDefinition(
              id: 'plugin-$name',
              platform: name,
              sourcePath: '$name.js',
              enabled: true,
              installedAt: DateTime(2026),
              updatedAt: DateTime(2026),
            ),
        ],
      );
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _pumpSurface(
  WidgetTester tester,
  Size size,
  Widget child, {
  List<PluginDefinition>? plugins,
}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        baseThemePackageProvider.overrideWithValue(xuanFixture()),
        pluginControllerProvider.overrideWith(
          () => _FakePluginController(
            plugins ??
                <PluginDefinition>[
                  PluginDefinition(
                    id: 'plugin-a',
                    platform: '很长很长很长很长的插件平台名称',
                    sourcePath: 'a.js',
                    enabled: true,
                    installedAt: DateTime(2026),
                    updatedAt: DateTime(2026),
                  ),
                ],
          ),
        ),
        playerControllerProvider.overrideWith(() => _SeededPlayerController()),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

class _FakePluginController extends PluginController {
  _FakePluginController(this._plugins);

  final List<PluginDefinition> _plugins;

  @override
  Future<List<PluginDefinition>> build() async => _plugins;
}

/// A queue with one very long title, which is the case that overflowed before
/// the rows were rebuilt from tokens.
class _SeededPlayerController extends PlayerController {
  @override
  PlayerControllerState build() {
    final item = PlaybackItem.plugin(
      platform: '平台',
      musicId: 'long',
      title: '一个非常非常非常长的歌曲标题用来验证窄窗口下不会溢出',
      raw: const <String, Object?>{'id': 'long'},
    );
    return PlayerControllerState(
      queue: <PlaybackItem>[item],
      currentItem: item,
      history: <PlaybackHistoryEntry>[
        PlaybackHistoryEntry(item: item, playedAt: DateTime(2026)),
      ],
    );
  }
}
