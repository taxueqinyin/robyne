import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/window_size_class.dart';
import '../../../core/theme/application/theme_providers.dart';
import '../../../core/theme/domain/theme_strings.dart';
import '../../../core/theme/infrastructure/token_resolver.dart';
import '../application/player_providers.dart';
import '../domain/playback_item.dart';
import 'artwork_view.dart';

class QueuePage extends ConsumerWidget {
  const QueuePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(activeThemeStringsProvider);
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final metrics = ref.watch(activeThemeContentMetricsProvider);
    final state =
        ref.watch(playerControllerProvider).value ??
        const PlayerControllerState();
    final sizeClass = WindowSizeClass.of(context);
    // Queue and history side by side need real horizontal room; below the
    // expanded breakpoint they become tabs rather than 50/50 slits.
    final splitPanes =
        sizeClass.width == WindowWidthClass.expanded &&
        !sizeClass.isCompactHeight;
    final compactWidth = sizeClass.isCompactWidth;
    // The gutters are the skin's (`components.content`), not literals, so a
    // skin that wants a tighter page can say so once.
    final padding = metrics.gutterFor(compact: compactWidth);

    final queueList = _QueueList(state: state);
    final historyList = _HistoryList(state: state);

    final pane = splitPanes
        ? Row(
            children: <Widget>[
              Expanded(child: queueList),
              const VerticalDivider(width: 32),
              Expanded(child: historyList),
            ],
          )
        : DefaultTabController(
            length: 2,
            child: Column(
              children: <Widget>[
                TabBar(
                  tabs: <Tab>[
                    Tab(text: strings.resolve(ThemeStringKey.queueTitle)),
                    Tab(text: strings.resolve(ThemeStringKey.queueTabHistory)),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TabBarView(children: <Widget>[queueList, historyList]),
                ),
              ],
            ),
          );

    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Title + mode dropdown + clear button do not fit one line on a
          // phone, so the controls wrap onto their own row instead of
          // overflowing.
          compactWidth
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      strings.resolve(ThemeStringKey.queuePageTitle),
                      style: TextStyle(
                        fontSize: tokens.typography.resolvedPageTitleSize,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _QueueControls(state: state),
                  ],
                )
              : Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        strings.resolve(ThemeStringKey.queuePageTitle),
                        style: TextStyle(
                          fontSize: tokens.typography.resolvedPageTitleSize,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    // Flexible, not bare: a Row gives its non-flex children
                    // unbounded width, which the controls' own Expanded child
                    // cannot resolve.
                    const SizedBox(width: 16),
                    Flexible(child: _QueueControls(state: state)),
                  ],
                ),
          const SizedBox(height: 14),
          Expanded(child: pane),
        ],
      ),
    );
  }
}

/// Playback-mode picker and the clear action, shared by both header layouts.
class _QueueControls extends ConsumerWidget {
  const _QueueControls({required this.state});

  final PlayerControllerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(activeThemeStringsProvider);
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    return Row(
      children: <Widget>[
        Expanded(
          // The design's mode control is a bordered pill with the mode name,
          // not a Material dropdown: the dropdown's underline and its 8dp
          // larger hit target were the only non-skin chrome left on this page.
          child: _ModePill(
            strings: strings,
            value: state.playbackMode,
            onChanged: (mode) {
              if (mode != null) {
                ref
                    .read(playerControllerProvider.notifier)
                    .setPlaybackMode(mode);
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: state.queue.isEmpty
              ? null
              : () => ref.read(playerControllerProvider.notifier).clearQueue(),
          icon: const Icon(Icons.clear_all),
          label: Text(strings.resolve(ThemeStringKey.actionClear)),
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.textSecondary,
            side: BorderSide(color: colors.borderDefault),
          ),
        ),
      ],
    );
  }

  /// Reads the mode name from the skin, so a skin renames the mode once and
  /// the queue page and player bar agree.
  static String _modeLabel(ThemeStrings strings, PlaybackMode mode) {
    return strings.resolve(switch (mode) {
      PlaybackMode.sequence => ThemeStringKey.modeSequence,
      PlaybackMode.random => ThemeStringKey.modeRandom,
      PlaybackMode.allLoop => ThemeStringKey.modeAllLoop,
      PlaybackMode.singleLoop => ThemeStringKey.modeSingleLoop,
    });
  }
}

/// The playback-mode picker, drawn as the design's bordered pill.
class _ModePill extends StatelessWidget {
  const _ModePill({
    required this.strings,
    required this.value,
    required this.onChanged,
  });

  final ThemeStrings strings;
  final PlaybackMode value;
  final ValueChanged<PlaybackMode?> onChanged;

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
      child: DropdownButton<PlaybackMode>(
        value: value,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        // The menu itself is chrome: the entries are the same skin strings the
        // pill shows.
        onChanged: onChanged,
        dropdownColor: colors.backgroundElevated,
        style: TextStyle(fontSize: 12.5, color: colors.textPrimary),
        items: PlaybackMode.values
            .map(
              (mode) => DropdownMenuItem<PlaybackMode>(
                value: mode,
                child: Text(_QueueControls._modeLabel(strings, mode)),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _QueueList extends ConsumerWidget {
  const _QueueList({required this.state});

  final PlayerControllerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(activeThemeStringsProvider);
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    if (state.queue.isEmpty) {
      return Center(
        child: Text(
          strings.resolve(ThemeStringKey.queueEmpty),
          style: TextStyle(color: colors.textMuted),
        ),
      );
    }
    return ListView.separated(
      itemCount: state.queue.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = state.queue[index];
        final selected = item.id == state.currentItem?.id;
        return _QueueItemRow(
          item: item,
          active: selected,
          removeLabel: strings.resolve(ThemeStringKey.actionRemove),
          onTap: () =>
              ref.read(playerControllerProvider.notifier).playItem(item),
          onRemove: () => ref
              .read(playerControllerProvider.notifier)
              .removeFromQueue(item.id),
        );
      },
    );
  }
}

/// One queue entry, in the design's row shape.
///
/// The mockup's queue row is artwork + title/artist + duration, with the
/// remove action on the trailing edge; `ListTile`'s fixed 56dp height made the
/// queue read as a settings list rather than as playback.
class _QueueItemRow extends StatelessWidget {
  const _QueueItemRow({
    required this.item,
    required this.active,
    required this.removeLabel,
    required this.onTap,
    required this.onRemove,
  });

  final PlaybackItem item;
  final bool active;
  final String removeLabel;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final comp = tokens.components;
    return InkWell(
      onTap: onTap,
      child: Container(
        // The active row is the design's selected-list colour, not Material's
        // selected tile: this is playback state, not navigation state.
        color: active ? comp.list.itemSelected : null,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          children: <Widget>[
            if (active)
              SizedBox(
                width: 32,
                child: Icon(Icons.equalizer, size: 16, color: colors.brandBase),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(tokens.radius.sm),
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: ArtworkView(artworkUrl: item.artworkUrl),
                ),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: tokens.typography.resolvedListPrimarySize,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      color: active ? colors.textPrimary : colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.artist ?? item.platform ?? item.localPath ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: colors.textMuted),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 28,
              height: 28,
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 16,
                tooltip: removeLabel,
                onPressed: onRemove,
                icon: Icon(Icons.close, color: colors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryList extends ConsumerWidget {
  const _HistoryList({required this.state});

  final PlayerControllerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(activeThemeStringsProvider);
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    if (state.history.isEmpty) {
      return Center(
        child: Text(
          strings.resolve(ThemeStringKey.queueHistoryEmpty),
          style: TextStyle(color: colors.textMuted),
        ),
      );
    }
    return Column(
      children: <Widget>[
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            key: const Key('clear-history-button'),
            onPressed: () =>
                ref.read(playerControllerProvider.notifier).clearHistory(),
            icon: const Icon(Icons.delete_sweep_outlined),
            label: Text(strings.resolve(ThemeStringKey.queueClearHistory)),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.textSecondary,
              side: BorderSide(color: colors.borderDefault),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            itemCount: state.history.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final entry = state.history[state.history.length - index - 1];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(tokens.radius.sm),
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: ArtworkView(artworkUrl: entry.item.artworkUrl),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        entry.item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: tokens.typography.resolvedListPrimarySize,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      _formatPlayedAt(entry.playedAt.toLocal()),
                      style: TextStyle(fontSize: 11, color: colors.textMuted),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// `MM-DD HH:mm` rather than `DateTime.toString()`: the full form carries
  /// microseconds, which is not chrome a skin can be asked to lay out.
  static String _formatPlayedAt(DateTime time) {
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }
}
