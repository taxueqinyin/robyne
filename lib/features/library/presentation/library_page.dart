import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/application/theme_providers.dart';
import '../../../core/theme/domain/theme_layout.dart';
import '../../../core/theme/domain/theme_strings.dart';
import '../../../core/theme/infrastructure/token_resolver.dart';
import '../../player/application/player_providers.dart';
import '../../player/domain/playback_item.dart';
import '../application/library_providers.dart';

/// Matches the shell breakpoint in [RobyneShell].
const double _compactWidthBreakpoint = 700;

class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(localMusicLibraryProvider);
    final strings = ref.watch(activeThemeStringsProvider);
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final actions = <Widget>[
      OutlinedButton.icon(
        onPressed: () async {
          final result = await FilePicker.pickFiles(
            type: FileType.custom,
            allowedExtensions: const <String>[
              'mp3',
              'flac',
              'wav',
              'm4a',
              'aac',
              'ogg',
              'opus',
              'wma',
            ],
            allowMultiple: true,
          );
          final paths = result?.files
              .map((file) => file.path)
              .whereType<String>()
              .toList(growable: false);
          if (paths == null || paths.isEmpty || !context.mounted) {
            return;
          }
          final error = await ref
              .read(localMusicLibraryProvider.notifier)
              .importFiles(paths);
          if (error != null && context.mounted) {
            _showError(context, error);
          }
        },
        icon: const Icon(Icons.file_open),
        label: Text(strings.resolve(ThemeStringKey.libraryImportFiles)),
      ),
      const SizedBox(width: 8, height: 8),
      FilledButton.icon(
        onPressed: () async {
          final path = await FilePicker.getDirectoryPath();
          if (path == null || !context.mounted) {
            return;
          }
          final error = await ref
              .read(localMusicLibraryProvider.notifier)
              .importFolder(path);
          if (error != null && context.mounted) {
            _showError(context, error);
          }
        },
        icon: const Icon(Icons.folder_open),
        label: Text(strings.resolve(ThemeStringKey.libraryImportFolder)),
      ),
    ];

    // Geometry comes from the skin (`components.content`) rather than from
    // literals: the desktop/phone gutter, the section rhythm and the card
    // sizing are all part of a skin's voice, and hardcoding them is what made
    // "make the rows a bit tighter" a code change instead of a manifest edit.
    final metrics = ref.watch(activeThemeContentMetricsProvider);
    final compactWidth =
        MediaQuery.sizeOf(context).width < _compactWidthBreakpoint;
    final gutter = metrics.gutterFor(compact: compactWidth);

    // On phone widths the title and both buttons do not fit on one line,
    // so stack them vertically instead of overflowing.
    final header = compactWidth
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[...actions],
          )
        : Row(children: <Widget>[...actions]);

    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, 22, gutter, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            // The page title is shell chrome: the rail links here under a
            // skin-declared name, so the header must use the same slot rather
            // than a literal that could disagree with it.
            ref
                .watch(activeThemeStringsProvider)
                .resolve(ThemeStringKey.libraryTitle),
            style: TextStyle(
              fontSize: tokens.typography.resolvedPageTitleSize,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            strings.resolve(ThemeStringKey.librarySubtitle),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 18),
          header,
          const SizedBox(height: 16),
          Expanded(
            child: library.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) =>
                  Center(child: Text(error.toString())),
              data: (tracks) {
                if (tracks.isEmpty) {
                  return Center(
                    child: Text(strings.resolve(ThemeStringKey.libraryEmpty)),
                  );
                }
                // The skin decides how the content region presents itself
                // (design spec §2.5). A skin that asks for a grid gets a
                // grid; `compact` tightens the rows for a landscape phone.
                final style = ref.watch(
                  contentStyleForProvider(ThemeContentSurface.library),
                );
                // `banner` is the horizontal cover flow (design spec §2.5
                // "推荐横幅"): a short, wide row of covers you flick through
                // instead of a wall you scan. Declaring it and silently
                // getting rows is the bug this branch closes.
                if (style == ThemeListStyle.banner) {
                  // A horizontal list hands its children unbounded height, so
                  // the shelf must declare its own: without this the covers
                  // stretch to the full window and the row stops reading as a
                  // shelf at all. Three rows' worth keeps it glanceable.
                  final bannerHeight = metrics.rowHeight * 3;
                  return Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      height: bannerHeight,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: tracks.length,
                        separatorBuilder: (context, index) =>
                            SizedBox(width: metrics.cardGap),
                        itemBuilder: (context, index) {
                          final item = tracks[index];
                          return _BannerCard(
                            item: item,
                            width: metrics.cardMinWidth,
                            onTap: () => ref
                                .read(playerControllerProvider.notifier)
                                .playItem(item),
                          );
                        },
                      ),
                    ),
                  );
                }
                if (style == ThemeListStyle.grid ||
                    style == ThemeListStyle.card) {
                  return GridView.builder(
                    // Tile width and gaps come from the skin (§3.2: 180dp
                    // minimum, 16dp gap) instead of being fixed literals.
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: metrics.cardMinWidthFor(
                        compact: compactWidth,
                      ),
                      mainAxisSpacing: metrics.cardGapFor(
                        compact: compactWidth,
                      ),
                      crossAxisSpacing: metrics.cardGapFor(
                        compact: compactWidth,
                      ),
                    ),
                    itemCount: tracks.length,
                    itemBuilder: (context, index) {
                      final item = tracks[index];
                      return Card(
                        child: InkWell(
                          onTap: () => ref
                              .read(playerControllerProvider.notifier)
                              .playItem(item),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const Icon(Icons.music_note),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: Text(
                                    item.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }
                // `compact` is the landscape-phone row (design spec §4.5): the
                // same columns, a 28dp row instead of 40dp, and no divider
                // chatter — the design compresses rhythm, not content.
                final compactRows = style == ThemeListStyle.compact;
                // The artwork follows the row height the skin declared, so
                // changing `rowHeight` moves the whole row's proportions
                // rather than leaving the cover stranded at one size.
                // Density is a factor on the declared row height, so the two
                // compose: the skin sets the base, density says tighter or
                // airier than that base.
                final rowHeight =
                    metrics.rowHeightFor(compact: compactRows) *
                    ref
                        .watch(activeThemePackageProvider)
                        .layout
                        .content
                        .density
                        .rowScale;
                final artworkSize = (rowHeight * 0.7).clamp(24.0, 56.0);
                return ListView.separated(
                  itemCount: tracks.length,
                  separatorBuilder: (context, index) => Divider(
                    // The compact row already carries its own vertical padding;
                    // a visible divider there would double the rhythm.
                    height: compactRows ? 0 : 1,
                    thickness: compactRows ? 0 : 1,
                    color: RobyneTheme.of(context).tokens.color.borderSubtle,
                  ),
                  itemBuilder: (context, index) {
                    final item = tracks[index];
                    final tokens = RobyneTheme.of(context).tokens;
                    return InkWell(
                      onTap: () => ref
                          .read(playerControllerProvider.notifier)
                          .playItem(item),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: compactRows ? 2 : 8,
                        ),
                        child: Row(
                          children: <Widget>[
                            Container(
                              width: artworkSize,
                              height: artworkSize,
                              decoration: BoxDecoration(
                                color: tokens.components.card.surface,
                                borderRadius: BorderRadius.circular(
                                  tokens.radius.sm,
                                ),
                              ),
                              child: Icon(
                                Icons.music_note,
                                size: artworkSize * 0.45,
                                color: tokens.color.textMuted,
                              ),
                            ),
                            SizedBox(width: compactRows ? 10 : 12),
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    item.artist ?? item.localPath ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: tokens.color.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                item.album ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: tokens.color.textMuted,
                                ),
                              ),
                            ),
                            if (item.duration != null)
                              Text(
                                _formatDuration(item.duration!),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: tokens.color.textMuted,
                                ),
                              ),
                            IconButton(
                              tooltip: 'Remove',
                              iconSize: 16,
                              icon: Icon(
                                Icons.close,
                                color: tokens.color.textMuted,
                              ),
                              onPressed: () => ref
                                  .read(localMusicLibraryProvider.notifier)
                                  .remove(item.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showError(BuildContext context, Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.toString())));
  }

  static String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

/// One cover in the `banner` flow (design spec §2.5 "推荐横幅").
///
/// Wider than a grid tile and showing the title under the artwork, which is
/// what makes the flow readable while flicking: a horizontal list of
/// square tiles with no caption is a gallery, not a recommendation shelf.
class _BannerCard extends StatelessWidget {
  const _BannerCard({
    required this.item,
    required this.width,
    required this.onTap,
  });

  final PlaybackItem item;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radius.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: tokens.components.card.surface,
                  borderRadius: BorderRadius.circular(tokens.radius.md),
                ),
                child: Center(
                  child: Icon(
                    Icons.music_note,
                    color: colors.textMuted,
                    size: 28,
                  ),
                ),
              ),
            ),
            SizedBox(height: tokens.spacing.sm),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13 * tokens.typography.scale,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.artist ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11 * tokens.typography.scale,
                color: colors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
