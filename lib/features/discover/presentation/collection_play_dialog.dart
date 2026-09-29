import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/application/theme_providers.dart';
import '../../../core/theme/domain/theme_strings.dart';
import '../../../core/theme/infrastructure/token_resolver.dart';
import '../../settings/domain/user_settings.dart';

/// The outcome of the "how should this collection join the queue?" prompt.
class CollectionPlayChoice {
  const CollectionPlayChoice({required this.action, required this.remember});

  final PlaylistOpenAction action;
  final bool remember;
}

/// Asks once how an online collection should join the queue.
///
/// Appending and replacing are both reasonable and neither is recoverable if
/// guessed wrong, so the app asks the first time. The "don't ask again" switch
/// is what makes this a one-time cost: ticking it pins the answer and every
/// later play goes straight through.
///
/// Returns `null` when the user dismisses the dialog.
Future<CollectionPlayChoice?> showCollectionPlayDialog(
  BuildContext context, {
  required String collectionTitle,
  required int trackCount,
}) {
  return showDialog<CollectionPlayChoice>(
    context: context,
    builder: (context) => _CollectionPlayDialog(
      collectionTitle: collectionTitle,
      trackCount: trackCount,
    ),
  );
}

class _CollectionPlayDialog extends ConsumerStatefulWidget {
  const _CollectionPlayDialog({
    required this.collectionTitle,
    required this.trackCount,
  });

  final String collectionTitle;
  final int trackCount;

  @override
  ConsumerState<_CollectionPlayDialog> createState() =>
      _CollectionPlayDialogState();
}

class _CollectionPlayDialogState extends ConsumerState<_CollectionPlayDialog> {
  bool _remember = true;

  @override
  Widget build(BuildContext context) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    final strings = ref.watch(activeThemeStringsProvider);

    return AlertDialog(
      backgroundColor: colors.backgroundElevated,
      title: Text(
        strings.resolve(ThemeStringKey.collectionPlayTitle),
        style: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            strings
                .resolve(ThemeStringKey.collectionPlayPrompt)
                .replaceAll('{title}', widget.collectionTitle)
                .replaceAll('{count}', '${widget.trackCount}'),
            style: TextStyle(color: colors.textSecondary),
          ),
          const SizedBox(height: 16),
          _ChoiceRow(
            icon: Icons.playlist_add,
            title: strings.resolve(ThemeStringKey.collectionPlayAppend),
            subtitle: strings.resolve(ThemeStringKey.collectionPlayAppendHint),
            onTap: () => _submit(PlaylistOpenAction.append),
          ),
          const SizedBox(height: 8),
          _ChoiceRow(
            icon: Icons.playlist_play,
            title: strings.resolve(ThemeStringKey.collectionPlayReplace),
            subtitle: strings.resolve(ThemeStringKey.collectionPlayReplaceHint),
            onTap: () => _submit(PlaylistOpenAction.replace),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Checkbox(
                value: _remember,
                onChanged: (value) =>
                    setState(() => _remember = value ?? _remember),
              ),
              Expanded(
                child: Text(
                  strings.resolve(ThemeStringKey.collectionPlayRemember),
                  style: TextStyle(fontSize: 12, color: colors.textMuted),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            strings.resolve(ThemeStringKey.actionCancel),
            style: TextStyle(color: colors.textMuted),
          ),
        ),
      ],
    );
  }

  void _submit(PlaylistOpenAction action) {
    Navigator.of(
      context,
    ).pop(CollectionPlayChoice(action: action, remember: _remember));
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = RobyneTheme.of(context).tokens;
    final colors = tokens.color;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radius.md),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: colors.borderSubtle),
          borderRadius: BorderRadius.circular(tokens.radius.md),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 20, color: colors.brandBase),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: colors.textMuted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: colors.textMuted),
          ],
        ),
      ),
    );
  }
}
