import 'package:flutter/material.dart';

import '../../core/theme/infrastructure/token_resolver.dart';

/// The grab affordance for a reorderable row.
///
/// A drag is only discoverable if something looks draggable, and the row
/// itself is already covered by hit targets (switch, configure, delete) — so
/// the handle is a dedicated leading slot rather than a long-press on the
/// whole tile. Built with [ReorderableDragStartListener], which is the widget
/// the framework's own reorderable list uses to begin a drag, so the gesture
/// matches the platform's expectations instead of a hand-rolled one.
class ReorderableHandle extends StatelessWidget {
  const ReorderableHandle({super.key, required this.index, this.tooltip});

  final int index;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = RobyneTheme.of(context).tokens.color;
    return ReorderableDragStartListener(
      index: index,
      child: MouseRegion(
        // A grab cursor on desktop: the pointer is the only hint that a
        // hover-capable platform gives before the drag starts.
        cursor: SystemMouseCursors.grab,
        child: Padding(
          // Wide enough to hit comfortably, inset so the tile's own padding is
          // not doubled on the leading edge.
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Tooltip(
            message: tooltip ?? '',
            child: Icon(
              Icons.drag_indicator,
              size: 18,
              color: colors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
