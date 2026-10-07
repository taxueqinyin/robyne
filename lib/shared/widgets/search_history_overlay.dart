import 'package:flutter/material.dart';

import '../../core/theme/domain/theme_strings.dart';
import '../../core/theme/domain/theme_tokens.dart';
import '../../core/theme/infrastructure/token_resolver.dart';
import '../../features/search/domain/search_history_entry.dart';

/// The remembered keywords, filtered by what the user has typed so far.
///
/// Google/Baidu-style: an empty field shows the whole history, and typing
/// narrows it to the entries containing the keyword. Case is ignored because a
/// search box is not case-sensitive to the person using it.
List<SearchHistoryEntry> matchSearchHistory(
  List<SearchHistoryEntry> entries,
  String query, {
  int limit = 8,
}) {
  final needle = query.trim().toLowerCase();
  final matches = needle.isEmpty
      ? entries
      : entries
            .where((entry) => entry.keyword.toLowerCase().contains(needle))
            .toList(growable: false);
  return matches.take(limit).toList(growable: false);
}

/// The dropdown panel of remembered searches under a search field.
///
/// Takes every value and callback by argument rather than reading providers:
/// the panel is inserted into the root overlay, which sits outside the field's
/// provider scope, so a `ConsumerWidget` there would resolve a *second* copy of
/// the history provider and render empty.
class SearchHistoryOverlay extends StatelessWidget {
  const SearchHistoryOverlay({
    super.key,
    this.width,
    this.panelKey,
    required this.entries,
    required this.query,
    required this.selectedIndex,
    required this.onHoverIndex,
    required this.onPick,
    required this.onRemove,
    required this.onClearAll,
  });

  /// Keyed on the panel's own box, so the field's outside-press route can
  /// measure it. The root of the overlay entry is a
  /// `CompositedTransformFollower`, which is a proxy: measuring *that* reports
  /// the theater's viewport-sized box and makes every press look like it was
  /// inside the panel.
  final Key? panelKey;

  /// The field's width; the panel is sized to it, since the follower supplies a
  /// position but no width and the root overlay's own constraints are the whole
  /// viewport.
  final double? width;

  final List<SearchHistoryEntry> entries;
  final String query;

  /// The row the keyboard is on, or -1 for none.
  final int selectedIndex;
  final ValueChanged<int> onHoverIndex;
  final ValueChanged<String> onPick;
  final ValueChanged<String> onRemove;
  final Future<void> Function(BuildContext context) onClearAll;

  @override
  Widget build(BuildContext context) {
    final strings = ThemeStrings.of(context);
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final matches = matchSearchHistory(entries, query);

    // The panel is inserted into the *root* overlay, above the `MaterialApp`:
    // without its own `Material` the rows' ink wells have no material ancestor
    // to draw on and the build asserts.
    //
    // The width is declared *here* rather than by the caller's `SizedBox`
    // because the root overlay lays its children out with
    // `BoxConstraints.tight(viewportSize)`: a width imposed from above is
    // ignored, and the panel stretched across the whole viewport.
    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        key: panelKey,
        decoration: BoxDecoration(
          color: colors.backgroundElevated,
          borderRadius: BorderRadius.all(Radius.circular(tokens.radius.md)),
          border: Border.all(color: colors.borderDefault),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: const Color(0x33000000),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(tokens.radius.md)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 6),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        strings.resolve(ThemeStringKey.searchHistoryTitle),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.textMuted,
                        ),
                      ),
                    ),
                    // Only offered when there is something to clear, so the
                    // panel never shows a destructive action that does nothing.
                    if (entries.isNotEmpty)
                      _ClearAllButton(
                        colors: colors,
                        tokens: tokens,
                        onClearAll: onClearAll,
                      ),
                  ],
                ),
              ),
              if (matches.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                  child: Text(
                    strings.resolve(ThemeStringKey.searchHistoryEmpty),
                    style: TextStyle(fontSize: 12, color: colors.textMuted),
                  ),
                )
              else
                for (var index = 0; index < matches.length; index += 1)
                  _HistoryRow(
                    entry: matches[index],
                    highlighted: index == selectedIndex,
                    removeLabel: strings.resolve(
                      ThemeStringKey.searchHistoryRemove,
                    ),
                    onHover: () => onHoverIndex(index),
                    onTap: () => onPick(matches[index].keyword),
                    onRemove: () => onRemove(matches[index].keyword),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.entry,
    required this.highlighted,
    required this.removeLabel,
    required this.onHover,
    required this.onTap,
    required this.onRemove,
  });

  final SearchHistoryEntry entry;
  final bool highlighted;
  final String removeLabel;
  final VoidCallback onHover;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    return MouseRegion(
      onEnter: (_) => onHover(),
      child: Material(
        // Tinted while the keyboard is on it, so arrowing through the list
        // shows which row Enter will run.
        color: highlighted
            ? colors.textPrimary.withValues(alpha: 0.07)
            : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
            child: Row(
              children: <Widget>[
                Icon(Icons.history, size: 14, color: colors.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.keyword,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: colors.textPrimary),
                  ),
                ),
                // The row's own remove affordance: deleting one remembered
                // keyword should not cost a trip to another surface.
                SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 14,
                    tooltip: removeLabel,
                    onPressed: onRemove,
                    icon: Icon(Icons.close, color: colors.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The "clear all" affordance in the panel's header.
///
/// The confirmation and the write both happen in the field's provider scope,
/// which is why [onClearAll] takes the context rather than doing the work here.
class _ClearAllButton extends StatelessWidget {
  const _ClearAllButton({
    required this.colors,
    required this.tokens,
    required this.onClearAll,
  });

  final ThemeColors colors;
  final ThemeTokens tokens;
  final Future<void> Function(BuildContext context) onClearAll;

  @override
  Widget build(BuildContext context) {
    final strings = ThemeStrings.of(context);
    return Tooltip(
      message: strings.resolve(ThemeStringKey.searchHistoryClearAll),
      child: InkWell(
        borderRadius: BorderRadius.all(Radius.circular(tokens.radius.sm)),
        onTap: () => onClearAll(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Text(
            strings.resolve(ThemeStringKey.searchHistoryClearAll),
            style: TextStyle(fontSize: 11, color: colors.textMuted),
          ),
        ),
      ),
    );
  }
}
