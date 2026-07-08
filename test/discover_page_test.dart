import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/features/discover/application/discover_controller.dart';
import 'package:robyne/features/discover/domain/online_collection.dart';
import 'package:robyne/features/discover/presentation/discover_page.dart';
import 'package:robyne/features/plugin/application/plugin_controller.dart';
import 'package:robyne/features/plugin/domain/plugin_definition.dart';
import 'package:robyne/features/search/domain/music_item.dart';

void main() {
  testWidgets(
    'renders rankings and hot playlists from the discover page',
    (tester) async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'robyne_discover_page_',
      );
      addTearDown(() async {
        await tempDirectory.delete(recursive: true);
      });
      final pluginPath = await _writePluginFile(tempDirectory, 'discover.js');
      final plugin = _plugin('plugin-a', 'Source A', pluginPath);
      late _FakeDiscoverController discoverController;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pluginControllerProvider.overrideWith(
              () => _FakePluginController(<PluginDefinition>[plugin]),
            ),
            discoverControllerProvider.overrideWith(() {
              discoverController = _FakeDiscoverController(plugin);
              return discoverController;
            }),
          ],
          child: const MaterialApp(home: Scaffold(body: DiscoverPage())),
        ),
      );
      await _pumpUi(tester);

      expect(find.text('Top 50'), findsOneWidget);

      await tester.tap(find.text('Top 50'));
      await _pumpUi(tester);
      expect(find.text('Rank Song'), findsOneWidget);

      await tester.tap(find.text('Hot playlists'));
      await _pumpUi(tester);
      expect(find.text('Mood Page 1'), findsOneWidget);
      expect(
        discoverController.selectedSurfaces,
        contains(DiscoverSurface.hotPlaylists),
      );

      await tester.tap(find.text('Mood Page 1'));
      await _pumpUi(tester);
      expect(find.text('Sheet Song 1'), findsOneWidget);
    },
    // TODO: Re-enable after the Windows Flutter widget harness hang is resolved.
    skip: true,
  );
}

Future<void> _pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 200));
}

Future<String> _writePluginFile(Directory directory, String name) async {
  final file = File('${directory.path}/$name');
  await file.writeAsString('// $name');
  return file.path;
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
      );

  final PluginDefinition plugin;
  final OnlineCollectionItem _topList;
  final OnlineCollectionItem _sheet;
  final List<DiscoverSurface> selectedSurfaces = <DiscoverSurface>[];

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
  Future<void> selectSurface(DiscoverSurface surface) async {
    selectedSurfaces.add(surface);
    state = state.copyWith(
      surface: surface,
      hotPlaylistItems: surface == DiscoverSurface.hotPlaylists
          ? <OnlineCollectionItem>[_sheet]
          : const <OnlineCollectionItem>[],
    );
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
}
