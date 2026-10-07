import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/application/theme_providers.dart';
import '../../../core/theme/domain/theme_icons.dart';
import '../../../core/theme/domain/theme_strings.dart';
import '../../../core/theme/infrastructure/token_resolver.dart';
import '../../../core/theme/presentation/theme_icon.dart';
import '../../../core/theme/presentation/theme_material.dart';
import '../application/capsule_window.dart';
import '../application/player_providers.dart';
import '../domain/playback_item.dart';
import 'artwork_view.dart';

/// Height the header needs before it is worth drawing.
///
/// Used by the shrink guard below, so the number has one home.
const double _capsulePanelHeaderHeight = 36;

/// The playlist the capsule unfolds below its bar.
///
/// Deliberately not [QueuePage]: the capsule is a mini surface, so this is a
/// single dense list of the playback queue. The full queue/history surface is
/// still reachable from the shell by closing the capsule.
class CapsulePlaylistPanel extends ConsumerWidget {
  const CapsulePlaylistPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final strings = ref.watch(activeThemeStringsProvider);
    final state =
        ref.watch(playerControllerProvider).value ??
        const PlayerControllerState();
    final current = state.currentItem;

    // Height comes from the incoming constraints rather than a literal: the
    // OS resize lags the toggle by a frame or two, and a hardcoded height is
    // what overflowed the old small window during those frames.
    return SizedBox(
      width: CapsuleWindow.barWidth,
      child: MaterialSurface(
        material: resolveSurfaceMaterial(
          material: tokens.materials.queue,
          tokens: tokens,
          fallbackColor: colors.backgroundElevated,
        ),
        tokens: tokens,
        borderRadius: BorderRadius.all(Radius.circular(tokens.radius.lg)),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // The OS resize trails the toggle, so for a frame or two the
            // panel is laid out inside the *old*, much shorter window — a
            // few dp tall against a 36dp header. Drawing the header
            // unconditionally there is what flashed the striped overflow
            // warning on every open, so it collapses until there is room.
            final showHeader =
                constraints.maxHeight >= _capsulePanelHeaderHeight + 40;
            return ClipRect(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (showHeader) ...<Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              strings.resolve(
                                ThemeStringKey.playerCapsulePlaylist,
                              ),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            strings
                                .resolve(ThemeStringKey.queueCount)
                                .replaceAll(
                                  '{count}',
                                  '${state.queue.length}',
                                ),
                            style: TextStyle(
                              fontSize: 10.5,
                              color: colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: colors.borderSubtle),
                  ],
                  Expanded(
                    child: state.queue.isEmpty
                        ? Center(
                            child: Text(
                              strings.resolve(
                                ThemeStringKey.playerCapsulePlaylistEmpty,
                              ),
                              style: TextStyle(
                                fontSize: 11.5,
                                color: colors.textMuted,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            itemCount: state.queue.length,
                            itemBuilder: (context, index) {
                              final item = state.queue[index];
                              return _CapsulePlaylistRow(
                                key: ValueKey<String>(
                                  'capsule-playlist-row-${item.id}',
                                ),
                                index: index,
                                item: item,
                                active: item.id == current?.id,
                                removeLabel: strings.resolve(
                                  ThemeStringKey.actionRemove,
                                ),
                                onRemove: () => ref
                                    .read(playerControllerProvider.notifier)
                                    .removeFromQueue(item.id),
                                onTap: () => ref
                                    .read(playerControllerProvider.notifier)
                                    .playItem(item),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CapsulePlaylistRow extends StatelessWidget {
  const _CapsulePlaylistRow({
    super.key,
    required this.index,
    required this.item,
    required this.active,
    required this.onTap,
    this.onRemove,
    this.removeLabel,
  });

  final int index;
  final PlaybackItem item;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final String? removeLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    return InkWell(
      onTap: onTap,
      child: Container(
        color: active
            ? colors.surfaceSelected.withValues(alpha: 0.5)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 20,
              child: active
                  ? ThemeIconView(
                      slot: ThemeIconKey.nowPlaying,
                      fallback: Icons.graphic_eq,
                      size: 15,
                      color: colors.brandBase,
                    )
                  : Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textDisabled,
                      ),
                    ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(tokens.radius.sm),
              child: ArtworkView(artworkUrl: item.artworkUrl, size: 30),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      color: active ? colors.brandBase : colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.artist ?? item.platform ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: colors.textMuted),
                  ),
                ],
              ),
            ),
            if (onRemove != null)
              SizedBox(
                width: 24,
                height: 24,
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
    );
  }
}
