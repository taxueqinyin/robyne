import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart'
    show PointerScrollEvent, PointerSignalEvent;

/// Lets an ordinary mouse wheel scroll a horizontal strip.
///
/// Flutter's horizontal `Scrollable` only consumes *horizontal* pointer
/// deltas, so a plain wheel — which reports `dy` — does nothing, and the
/// strip looks frozen unless the user knows the shift+wheel trick. This
/// translates the vertical delta onto the strip's own axis, so both gestures
/// work: shift+wheel (a true horizontal delta) still flows through the
/// framework untouched, and a bare wheel now moves the strip too.
///
/// A trackpad's two-finger horizontal swipe is already a horizontal delta, so
/// it is deliberately left to the framework rather than double-applied here.
class HorizontalWheelScroll extends StatefulWidget {
  const HorizontalWheelScroll({
    super.key,
    required this.builder,
    this.wheelScale = 1.2,
  });

  /// Builds the strip, and must hand [controller] to its scrollable child.
  ///
  /// A builder rather than a plain child because the scroll position can only
  /// be driven through the controller the strip actually uses; owning that
  /// controller here also keeps its disposal in one place.
  final Widget Function(BuildContext context, ScrollController controller)
  builder;

  /// Multiplier applied to wheel deltas.
  ///
  /// A wheel notch is worth about three lines of vertical text; a strip of
  /// pills is much shorter than that, so the raw delta is scaled down to keep
  /// one notch from jumping the whole row.
  final double wheelScale;

  @override
  State<HorizontalWheelScroll> createState() => _HorizontalWheelScrollState();
}

class _HorizontalWheelScrollState extends State<HorizontalWheelScroll> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) {
      return;
    }
    // A horizontal delta already reaches the strip on its own; handling it
    // here as well would scroll twice per gesture.
    final verticalDelta = event.scrollDelta.dy;
    if (verticalDelta == 0 || !_controller.hasClients) {
      return;
    }
    final position = _controller.position;
    final target = (position.pixels + verticalDelta * widget.wheelScale).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    // `jumpTo`, not `animateTo`: a wheel notch should feel like the strip
    // moved under the cursor, and animating each notch queues a simulation
    // per event that fights the next one.
    _controller.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _onPointerSignal,
      child: widget.builder(context, _controller),
    );
  }
}
