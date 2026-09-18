import 'package:flutter/material.dart';

class SearchActionButton extends StatefulWidget {
  const SearchActionButton({
    super.key,
    required this.isSearching,
    required this.onSearch,
    required this.onCancel,
  });

  final bool isSearching;
  final VoidCallback onSearch;
  final VoidCallback onCancel;

  @override
  State<SearchActionButton> createState() => _SearchActionButtonState();
}

class _SearchActionButtonState extends State<SearchActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final showStop = widget.isSearching && _hovered;
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.isSearching ? 'Stop search' : 'Search',
        child: FilledButton.icon(
          onPressed: widget.isSearching ? widget.onCancel : widget.onSearch,
          style: showStop
              ? FilledButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
                )
              : null,
          icon: showStop
              ? const Icon(Icons.close)
              : widget.isSearching
              ? const _SearchBusyIcon()
              : const Icon(Icons.search),
          label: Text(showStop ? 'Stop' : 'Search'),
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
