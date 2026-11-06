import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/errors/app_error.dart';
import 'package:robyne/features/discover/application/discover_controller.dart';
import 'package:robyne/features/discover/domain/online_collection.dart';
import 'package:robyne/features/discover/presentation/discover_page.dart';
import 'package:robyne/features/plugin/application/plugin_controller.dart';
import 'package:robyne/features/plugin/domain/plugin_definition.dart';
import 'package:robyne/features/search/domain/music_item.dart';

void main() {
  testWidgets(
    'renders rankings and hot playlists together on the first-level page',
    (tester) async {
      final plugin = _plugin('plugin-a', 'Source A', '/plugins/discover.js');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pluginControllerProvider.overrideWith(
              () => _FakePluginController(<PluginDefinition>[plugin]),
            ),
            discoverControllerProvider.overrideWith(
              () => _FakeDiscoverController(plugin),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: DiscoverPage())),
        ),
      );
      await _pumpUi(tester);

      // Both sections belong to the page itself: no surface switch, no
      // second-level browser to open first. The bare ProviderScope has no
      // skin loaded, so the headings read as the base theme's English
      // declarations; the Chinese copy is asserted against the real skin in
      // `shell_responsive_test.dart`.
      expect(find.text('Rankings'), findsWidgets);
      expect(find.text('Hot playlists'), findsWidgets);
      expect(find.text('Top 50'), findsOneWidget);
      expect(find.text('Mood Page 1'), findsOneWidget);

      await tester.tap(find.text('Top 50'));
      await _pumpUi(tester);
      expect(find.text('Rank Song'), findsOneWidget);

      // The drill-down owns no back button of its own: the shell's top-bar
      // arrow and re-tapping the destination are the way out.
      expect(find.byIcon(Icons.arrow_back), findsNothing);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DiscoverPage)),
      );
      container.read(discoverControllerProvider.notifier).closeDetail();
      await _pumpUi(tester);
      await tester.tap(find.text('Mood Page 1'));
      await _pumpUi(tester);
      expect(find.text('Sheet Song 1'), findsOneWidget);
    },
  );

  testWidgets('a two-line card title fits at a larger text scale', (
    tester,
  ) async {
    // The card caption used to be a fixed 55dp, which a CJK line box at the
    // default size already beat by ~3dp and a scaled one beats by far more.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pluginControllerProvider.overrideWith(
            () => _FakePluginController(<PluginDefinition>[
              _plugin('plugin-a', 'Source A', '/plugins/discover.js'),
            ]),
          ),
          discoverControllerProvider.overrideWith(
            () => _FakeDiscoverController(
              _plugin('plugin-a', 'Source A', '/plugins/discover.js'),
            ),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.35)),
              child: const Scaffold(body: DiscoverPage()),
            ),
          ),
        ),
      ),
    );
    await _pumpUi(tester);

    expect(find.text('在音乐与自由之境尽情燃烧 | 回听 2011 年的那场雨'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // Whatever the source does, the panel header (cover, title, refresh) has to
  // be on screen from the first frame. Building it only once the track list
  // arrived is what made a slow or failing ranking an empty-looking dead end.
  testWidgets('a drill-down that never answers still paints its header', (
    tester,
  ) async {
    final controller = _StuckDiscoverController();
    await _pumpStuck(tester, controller);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Top 50'), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);

    controller.closeDetail();
    await _pumpUi(tester);

    expect(controller.state.selectedCollection, isNull);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a drill-down that failed still paints its header', (
    tester,
  ) async {
    final controller = _StuckDiscoverController(error: true);
    await _pumpStuck(tester, controller);

    expect(find.text('Top 50'), findsOneWidget);
    // One from the header, one from the error's retry.
    expect(find.byIcon(Icons.refresh), findsWidgets);

    controller.closeDetail();
    await _pumpUi(tester);

    expect(controller.state.selectedCollection, isNull);
  });
}

Future<void> _pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 200));
}

PluginDefinition _plugin(String id, String platform, String sourcePath) {
  return PluginDefinition(
    id: id,
    platform: platform,
    sourcePath: sourcePath,
    enabled: true,
    installedAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

class _FakePluginController extends PluginController {
  _FakePluginController(this._plugins);

  final List<PluginDefinition> _plugins;

  @override
  Future<List<PluginDefinition>> build() async => _plugins;
}

class _FakeDiscoverController extends DiscoverController {
  _FakeDiscoverController(this.plugin)
    : _topList = OnlineCollectionItem(
        id: 'top-1',
        pluginId: plugin.id,
        platform: plugin.platform,
        kind: OnlineCollectionKind.topList,
        title: 'Top 50',
        raw: const <String, Object?>{'id': 'top-1', 'title': 'Top 50'},
      ),
      _sheet = OnlineCollectionItem(
        id: 'sheet-1',
        pluginId: plugin.id,
        platform: plugin.platform,
        kind: OnlineCollectionKind.musicSheet,
        title: 'Mood Page 1',
        description: 'Editor',
        raw: const <String, Object?>{'id': 'sheet-1', 'title': 'Mood Page 1'},
      ),
      // Long enough to wrap to two lines in a 190dp card: the caption block
      // has to have room for them at any text scale.
      _longSheet = OnlineCollectionItem(
        id: 'sheet-2',
        pluginId: plugin.id,
        platform: plugin.platform,
        kind: OnlineCollectionKind.musicSheet,
        title: '在音乐与自由之境尽情燃烧 | 回听 2011 年的那场雨',
        description: '在音乐与自由之境',
        raw: const <String, Object?>{'id': 'sheet-2'},
      );

  final PluginDefinition plugin;
  final OnlineCollectionItem _topList;
  final OnlineCollectionItem _sheet;
  final OnlineCollectionItem _longSheet;

  @override
  DiscoverState build() {
    return DiscoverState(
      pluginSignature: discoverPluginSignature(<PluginDefinition>[plugin]),
      selectedPluginId: plugin.id,
      topListGroups: <OnlineCollectionGroup>[
        OnlineCollectionGroup(
          title: 'Official',
          items: <OnlineCollectionItem>[_topList],
        ),
      ],
      hotPlaylistItems: <OnlineCollectionItem>[_sheet, _longSheet],
      selectedSheetTag: const OnlineSheetTag(
        id: 'mood',
        title: 'Mood',
        raw: <String, Object?>{'id': 'mood', 'title': 'Mood'},
      ),
      sheetTagGroups: const <OnlineSheetTagGroup>[
        OnlineSheetTagGroup(
          title: 'Scenes',
          tags: <OnlineSheetTag>[
            OnlineSheetTag(
              id: 'mood',
              title: 'Mood',
              raw: <String, Object?>{'id': 'mood', 'title': 'Mood'},
            ),
          ],
        ),
      ],
      pinnedSheetTags: const <OnlineSheetTag>[
        OnlineSheetTag(
          id: 'mood',
          title: 'Mood',
          raw: <String, Object?>{'id': 'mood', 'title': 'Mood'},
        ),
      ],
    );
  }

  @override
  Future<void> syncPlugins(List<PluginDefinition> plugins) async {
    state = state.copyWith(
      pluginSignature: discoverPluginSignature(plugins),
      selectedPluginId: plugin.id,
    );
  }

  @override
  Future<void> selectPlugin(String pluginId) async {
    state = state.copyWith(selectedPluginId: pluginId);
  }

  @override
  Future<void> selectHotPlaylistTag(OnlineSheetTag tag) async {
    state = state.copyWith(selectedSheetTag: tag);
  }

  @override
  Future<void> openCollection(OnlineCollectionItem collection) async {
    final title = collection.kind == OnlineCollectionKind.topList
        ? 'Rank Song'
        : 'Sheet Song 1';
    state = state.copyWith(
      selectedCollection: collection,
      detail: OnlineCollectionDetail(
        collection: collection,
        items: <MusicItem>[
          MusicItem(
            id: title.toLowerCase().replaceAll(' ', '-'),
            pluginId: plugin.id,
            platform: plugin.platform,
            title: title,
            raw: <String, Object?>{'id': title.toLowerCase()},
          ),
        ],
        page: 1,
        isEnd: true,
      ),
    );
  }

  @override
  void closeDetail() {
    state = state.copyWith(
      selectedCollection: null,
      detail: null,
      detailError: null,
    );
  }
}

Future<void> _pumpStuck(
  WidgetTester tester,
  DiscoverController controller,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // No sources: the page stays on the drill-down the controller was
        // seeded with, so nothing else can explain the assertions below.
        pluginControllerProvider.overrideWith(
          () => _FakePluginController(const <PluginDefinition>[]),
        ),
        discoverControllerProvider.overrideWith(() => controller),
      ],
      child: const MaterialApp(home: Scaffold(body: DiscoverPage())),
    ),
  );
  await _pumpUi(tester);
}

/// A drill-down parked in one of the two states that have no track list:
/// the request is still in flight, or it failed.
class _StuckDiscoverController extends DiscoverController {
  _StuckDiscoverController({this.error = false});

  final bool error;

  static const OnlineCollectionItem _collection = OnlineCollectionItem(
    id: 'top-1',
    pluginId: 'plugin-a',
    platform: 'Source A',
    kind: OnlineCollectionKind.topList,
    title: 'Top 50',
    raw: <String, Object?>{'id': 'top-1'},
  );

  @override
  DiscoverState build() => DiscoverState(
    selectedCollection: _collection,
    isLoadingDetail: !error,
    detailError: error
        ? const AppError(code: 'plugin', message: 'source is down')
        : null,
  );
}
