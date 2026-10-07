import 'package:flutter/material.dart';

import '../../core/theme/domain/theme_strings.dart';
import '../../core/theme/infrastructure/token_resolver.dart';
import '../../features/plugin/domain/plugin_sort.dart';

/// The plugin list's ordering control: a bordered pill with a menu.
///
/// A bordered pill rather than a bare menu icon, because the current order is
/// worth reading at a glance — the list's arrangement is invisible otherwise,
/// and the arrangement is what discover and search inherit.
class PluginSortPicker extends StatelessWidget {
  const PluginSortPicker({
    super.key,
    required this.strings,
    required this.order,
    required this.onChanged,
  });

  final ThemeStrings strings;
  final PluginSortOrder order;
  final ValueChanged<PluginSortOrder> onChanged;

  /// The label for [order], or the slot's own default.
  static String label(ThemeStrings strings, PluginSortOrder order) {
    return strings.resolve(switch (order) {
      PluginSortOrder.manual => ThemeStringKey.pluginsSortManual,
      PluginSortOrder.added => ThemeStringKey.pluginsSortAdded,
      PluginSortOrder.name => ThemeStringKey.pluginsSortName,
      PluginSortOrder.enabled => ThemeStringKey.pluginsSortEnabled,
      PluginSortOrder.recentlyUpdated => ThemeStringKey.pluginsSortUpdated,
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: colors.surfaceBase,
        borderRadius: BorderRadius.all(Radius.circular(tokens.radius.md)),
        border: Border.all(color: colors.borderDefault),
      ),
      child: DropdownButton<PluginSortOrder>(
        value: order,
        underline: const SizedBox.shrink(),
        isDense: true,
        style: TextStyle(fontSize: 12.5, color: colors.textPrimary),
        dropdownColor: colors.backgroundElevated,
        // The entries are the same skin strings the pill shows, so the label
        // and the menu can never disagree about what an order is called.
        items: PluginSortOrder.values
            .map(
              (candidate) => DropdownMenuItem<PluginSortOrder>(
                value: candidate,
                child: Text(label(strings, candidate)),
              ),
            )
            .toList(growable: false),
        onChanged: (next) {
          if (next != null) {
            onChanged(next);
          }
        },
        selectedItemBuilder: (context) => PluginSortOrder.values
            .map(
              (candidate) => Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.sort, size: 15, color: colors.textSecondary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label(strings, candidate),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}
