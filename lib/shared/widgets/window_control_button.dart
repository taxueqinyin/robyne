import 'package:flutter/material.dart';

import '../../core/theme/infrastructure/token_resolver.dart';

/// A frameless-window title-bar action.
///
/// Minimise, maximise and close share one hover treatment: a semantic surface
/// hover for the neutral actions and the danger fill for close. Keeping this
/// in one widget prevents the two title-bar implementations (the shell and the
/// immersive player) from drifting apart again.
class WindowControlButton extends StatelessWidget {
  const WindowControlButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = RobyneTheme.of(context).tokens.color;
    final normalForeground = colors.textSecondary;
    final accentBackground = destructive ? colors.danger : colors.surfaceHover;
    final accentForeground = destructive ? colors.onBrand : colors.textPrimary;

    return SizedBox(
      width: 38,
      height: 32,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 38, height: 32),
        style: ButtonStyle(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          shape: const WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(),
          ),
          backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.pressed) ||
                states.contains(WidgetState.focused)) {
              return accentBackground;
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.pressed) ||
                states.contains(WidgetState.focused)) {
              return accentForeground;
            }
            return normalForeground;
          }),
        ),
        icon: Icon(icon, size: 16),
      ),
    );
  }
}
