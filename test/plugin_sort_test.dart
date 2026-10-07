import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/features/plugin/domain/plugin_definition.dart';
import 'package:robyne/features/plugin/domain/plugin_sort.dart';

void main() {
  // Distinct install times: the manual order falls back to install order for
  // rows the user never dragged, so a fixture where every row was installed
  // at the same instant exercises the name tiebreak instead of the real path.
  final plugins = <PluginDefinition>[
    _plugin(
      id: 'a',
      platform: 'Zeta',
      enabled: false,
      updatedAt: 300,
      installedAt: 100,
    ),
    _plugin(
      id: 'b',
      platform: 'alpha',
      enabled: true,
      updatedAt: 100,
      installedAt: 200,
    ),
    _plugin(
      id: 'c',
      platform: 'Mu',
      enabled: true,
      updatedAt: 500,
      installedAt: 300,
    ),
  ];

  test('added order leaves the repository order untouched', () {
    expect(
      sortPlugins(plugins, PluginSortOrder.added).map((e) => e.id).toList(),
      <String>['a', 'b', 'c'],
    );
  });

  test('manual order keeps undragged plugins in install order', () {
    // Nobody has been dragged yet, so the manual order is the install order.
    expect(
      sortPlugins(plugins, PluginSortOrder.manual).map((e) => e.id).toList(),
      <String>['a', 'b', 'c'],
    );
  });

  test('manual order honours ranks and puts new plugins first', () {
    // 'c' was dragged below 'a'; 'b' arrived later and has not been placed.
    final arranged = <PluginDefinition>[
      _plugin(
        id: 'a',
        platform: 'Zeta',
        enabled: true,
        updatedAt: 300,
        sortIndex: 1,
        installedAt: 100,
      ),
      _plugin(
        id: 'c',
        platform: 'Mu',
        enabled: true,
        updatedAt: 500,
        sortIndex: 2,
        installedAt: 300,
      ),
      _plugin(
        id: 'b',
        platform: 'alpha',
        enabled: true,
        updatedAt: 900,
        installedAt: 900,
      ),
    ];
    expect(
      sortPlugins(arranged, PluginSortOrder.manual).map((e) => e.id).toList(),
      <String>['b', 'a', 'c'],
    );
  });

  test('name order is case-insensitive', () {
    // Case-insensitive, so "alpha" precedes "Mu" rather than sorting after
    // every capitalised name the way raw `compareTo` would.
    expect(
      sortPlugins(plugins, PluginSortOrder.name).map((e) => e.id).toList(),
      <String>['b', 'c', 'a'],
    );
  });

  test('enabled order lifts enabled plugins and keeps name order inside', () {
    expect(
      sortPlugins(plugins, PluginSortOrder.enabled).map((e) => e.id).toList(),
      <String>['b', 'c', 'a'],
    );
  });

  test('recently updated order is newest first', () {
    expect(
      sortPlugins(
        plugins,
        PluginSortOrder.recentlyUpdated,
      ).map((e) => e.id).toList(),
      <String>['c', 'a', 'b'],
    );
  });

  test('sorting does not mutate the source list', () {
    final source = List<PluginDefinition>.of(plugins);
    sortPlugins(source, PluginSortOrder.name);
    expect(source.map((e) => e.id).toList(), <String>['a', 'b', 'c']);
  });

  test(
    'applyPluginOrder ranks the given ids 1..n and returns them in order',
    () {
      final reordered = applyPluginOrder(plugins, <String>['c', 'b', 'a']);
      expect(reordered.map((e) => e.id).toList(), <String>['c', 'b', 'a']);
      expect(
        <String, int>{
          for (final plugin in reordered) plugin.id: plugin.sortIndex,
        },
        <String, int>{'c': 1, 'b': 2, 'a': 3},
      );
    },
  );

  test('applyPluginOrder drops ids that are not installed', () {
    // A stale id (deleted plugin, or a reorder racing a delete) cannot invent
    // a rank, or the remaining rows would be renumbered around a ghost.
    final reordered = applyPluginOrder(plugins, <String>[
      'c',
      'gone',
      'a',
      'b',
    ]);
    expect(reordered.map((e) => e.id).toList(), <String>['c', 'a', 'b']);
    expect(
      <String, int>{
        for (final plugin in reordered) plugin.id: plugin.sortIndex,
      },
      <String, int>{'c': 1, 'a': 2, 'b': 3},
    );
  });

  test('applyPluginOrder leaves unmentioned plugins alone', () {
    final arranged = applyPluginOrder(plugins, <String>['c', 'a', 'b']);
    // Only 'b' is named, so it takes rank 1 and the rest keep theirs — an
    // arrangement built over several drags is not flattened by the next one.
    final moved = applyPluginOrder(arranged, <String>['b']);
    expect(moved.firstWhere((e) => e.id == 'b').sortIndex, 1);
    expect(
      moved.firstWhere((e) => e.id == 'a').sortIndex,
      arranged.firstWhere((e) => e.id == 'a').sortIndex,
    );
    expect(
      moved.firstWhere((e) => e.id == 'c').sortIndex,
      arranged.firstWhere((e) => e.id == 'c').sortIndex,
    );
    // Unmentioned rows stay where they were rather than being appended.
    expect(moved.map((e) => e.id).toList(), <String>['b', 'c', 'a']);
  });
}

PluginDefinition _plugin({
  required String id,
  required String platform,
  required bool enabled,
  required int updatedAt,
  int installedAt = 0,
  int sortIndex = 0,
}) {
  return PluginDefinition(
    id: id,
    platform: platform,
    sourcePath: '$id.js',
    enabled: enabled,
    installedAt: DateTime.fromMillisecondsSinceEpoch(installedAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt),
    sortIndex: sortIndex,
  );
}
