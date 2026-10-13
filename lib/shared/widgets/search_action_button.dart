import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/application/theme_providers.dart';
import '../../core/theme/domain/theme_strings.dart';
import '../../core/theme/infrastructure/token_resolver.dart';

class SearchActionButton extends ConsumerStatefulWidget {
  const SearchActionButton({
    super.key,
    required this.isSearching,
    required this.onSearch,
    required this.onCancel,
    this.searchLabelKey = ThemeStringKey.searchAction,
    this.stopLabelKey = ThemeStringKey.searchStop,
    this.accentColor,
    this.accentInkColor,
  });

  final bool isSearching;
  final VoidCallback onSearch;
  final VoidCallback onCancel;
  final ThemeStringKey searchLabelKey;
  final ThemeStringKey stopLabelKey;

  /// Fill for the idle button. Null uses the skin's own brand colour.
  ///
  /// Surfaces that are already coloured by the song — the lyrics search dialog
  /// sits over the cover-derived player — pass the cover's primary here so the
  /// button belongs to the same palette instead of reintroducing a swatch.
  final Color? accentColor;

  /// Ink for [accentColor]. Null uses the skin's `onBrand`.
  final Color? accentInkColor;

  @override
  ConsumerState<SearchActionButton> createState() => _SearchActionButtonState();
}

class _SearchActionButtonState extends ConsumerState<SearchActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final showStop = widget.isSearching && _hovered;
    final colors = RobyneTheme.of(context).tokens.color;
    // The button is shell chrome, so its wording belongs to the skin like the
    // search field's hint does.
    final strings = ref.watch(activeThemeStringsProvider);
    final searchLabel = strings.resolve(widget.searchLabelKey);
    final stopLabel = strings.resolve(widget.stopLabelKey);
    final themeStyle = widget.accentColor == null
        ? null
        : FilledButton.styleFrom(
            backgroundColor: widget.accentColor,
            foregroundColor: widget.accentInkColor ?? colors.onBrand,
          );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.isSearching ? stopLabel : searchLabel,
        child: FilledButton.icon(
          onPressed: widget.isSearching ? widget.onCancel : widget.onSearch,
          style: showStop
              ? FilledButton.styleFrom(
                  backgroundColor: colors.danger,
                  foregroundColor: colors.onBrand,
                )
              : themeStyle,
          icon: showStop
              ? const Icon(Icons.close)
              : widget.isSearching
              ? const _SearchBusyIcon()
              : const Icon(Icons.search),
          label: Text(showStop ? stopLabel : searchLabel),
        ),
      ),
    );
  }
}

class _SearchBusyIcon extends StatelessWidget {
  const _SearchBusyIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: IconTheme.of(context).color,
      ),
    );
  }
}
