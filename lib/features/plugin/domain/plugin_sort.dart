import 'plugin_definition.dart';

/// How the plugin page arranges the installed plugins.
///
/// [manual] is the only order that is *stored*: dragging a row rewrites each
/// plugin's `sortIndex`, so the arrangement is plugin data rather than a view
/// preference, and it is the order the discover sources and the search result
/// tabs inherit. The other orders are pure views over the manual order — they
/// never rewrite rows, so a sort cannot corrupt the arrangement the user
/// dragged into place.
enum PluginSortOrder {
  /// The user's own arrangement: ascending `sortIndex`, then install order.
  manual,

  /// Alphabetical by platform name.
  name,

  /// Enabled plugins first, then alphabetical.
  enabled,

  /// Most recently updated first.
  recentlyUpdated,

  /// Install order, i.e. the repository's own ordering.
  added,
}

/// Sorts [plugins] for display, leaving the input untouched.
///
/// Ties fall back to platform name so the order is stable no matter what the
/// database returned: `List.sort` is not stable, so comparing equal-keys by
/// name keeps rows from swapping places on unrelated refreshes.
List<PluginDefinition> sortPlugins(
  List<PluginDefinition> plugins,
  PluginSortOrder order,
) {
  final sorted = List<PluginDefinition>.of(plugins);
  switch (order) {
    case PluginSortOrder.manual:
      sorted.sort(_byManual);
      return sorted;
    case PluginSortOrder.added:
      return sorted;
    case PluginSortOrder.name:
      sorted.sort(_byName);
      return sorted;
    case PluginSortOrder.enabled:
      sorted.sort((left, right) {
        final enabled = _byEnabled(left, right);
        return enabled != 0 ? enabled : _byName(left, right);
      });
      return sorted;
    case PluginSortOrder.recentlyUpdated:
      sorted.sort((left, right) {
        final recent = right.updatedAt.compareTo(left.updatedAt);
        return recent != 0 ? recent : _byName(left, right);
      });
      return sorted;
  }
}

/// The user's arrangement, with undragged rows kept in install order.
///
/// An undragged plugin carries `sortIndex == 0`. Sorting those by install time
/// (rather than letting them tie with a real rank of 0) is what makes a newly
/// imported plugin appear at the top instead of being compared against rows
/// the user has already placed.
int _byManual(PluginDefinition left, PluginDefinition right) {
  final leftPlaced = left.sortIndex > 0;
  final rightPlaced = right.sortIndex > 0;
  if (leftPlaced != rightPlaced) {
    return leftPlaced ? 1 : -1;
  }
  if (!leftPlaced) {
    // Both unplaced: install order, then name for namesakes installed in the
    // same batch.
    final installed = left.installedAt.compareTo(right.installedAt);
    return installed != 0 ? installed : _byName(left, right);
  }
  final rank = left.sortIndex.compareTo(right.sortIndex);
  return rank != 0 ? rank : _byName(left, right);
}

int _byName(PluginDefinition left, PluginDefinition right) {
  final comparison = _collated(left.platform).compareTo(
    _collated(right.platform),
  );
  return comparison != 0 ? comparison : left.id.compareTo(right.id);
}

int _byEnabled(PluginDefinition left, PluginDefinition right) {
  final leftRank = left.enabled ? 0 : 1;
  final rightRank = right.enabled ? 0 : 1;
  return leftRank.compareTo(rightRank);
}

/// Case-insensitive comparison key, so "bilibili" sorts next to "Bilibili"
/// instead of ending up in a separate block.
String _collated(String value) => value.trim().toLowerCase();

/// Rewrites `sortIndex` on [plugins] so their order matches [orderedIds], and
/// returns them in that order.
///
/// Ids the caller does not mention keep their existing rank, so a reorder of
/// one row cannot silently flatten an arrangement the user built earlier.
/// Ranks are 1-based and contiguous, which leaves room for an unplaced plugin
/// (rank 0) to sort ahead of everything placed.
///
/// The result is ordered as asked rather than left in the input's order so a
/// caller can paint it straight away without a second sort.
List<PluginDefinition> applyPluginOrder(
  List<PluginDefinition> plugins,
  List<String> orderedIds,
) {
  final byId = <String, PluginDefinition>{
    for (final plugin in plugins) plugin.id: plugin,
  };
  final placed = <PluginDefinition>[];
  var rank = 0;
  for (final id in orderedIds) {
    final plugin = byId[id];
    if (plugin == null) {
      // An id that is no longer installed cannot take a rank: numbering
      // around a ghost would leave a gap in the arrangement.
      continue;
    }
    rank += 1;
    placed.add(plugin.copyWith(sortIndex: rank));
  }
  final placedIds = <String>{for (final plugin in placed) plugin.id};
  final rest = plugins.where((plugin) => !placedIds.contains(plugin.id));
  return <PluginDefinition>[...placed, ...rest];
}
