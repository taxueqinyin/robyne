import 'package:flutter/material.dart';

/// A progress line whose drag handle only appears while the pointer is over it.
///
/// The design shows a flat scrub line at rest; a permanent round thumb reads as
/// a separate control and covers the track it belongs to. Hover (or an active
/// drag) reveals the thumb, so the affordance is there exactly when the user is
/// about to use it.
///
/// The slider owns the in-progress drag value. Feeding the widget straight from
/// playback snapshots made the thumb fight the finger — every snapshot tick
/// yanked it back to the last reported position — so the drag now runs on local
/// state and only [onChangeEnd] talks to the player.
class ProgressSlider extends StatefulWidget {
  const ProgressSlider({
    super.key,
    required this.value,
    required this.max,
    required this.activeColor,
    required this.inactiveColor,
    this.onChanged,
    this.onChangeEnd,
    this.trackHeight = 3,
    this.thumbRadius = 6,
    this.overlayRadius = 12,
  });

  final double value;
  final double max;
  final Color activeColor;
  final Color inactiveColor;

  /// Called on every pointer move with the previewed position.
  ///
  /// Keep this cheap: it exists for live labels, not for seeking.
  final ValueChanged<double>? onChanged;

  /// Called once with the final position when the drag ends.
  ///
  /// This is where the seek belongs. Seeking on every pointer move meant an
  /// audio seek plus a persisted write per pixel, which is what made scrubbing
  /// feel like it was crawling.
  final ValueChanged<double>? onChangeEnd;

  final double trackHeight;
  final double thumbRadius;
  final double overlayRadius;

  @override
  State<ProgressSlider> createState() => _ProgressSliderState();
}

class _ProgressSliderState extends State<ProgressSlider> {
  bool _hovering = false;
  bool _dragging = false;
  double? _dragValue;

  bool get _enabled => widget.onChanged != null || widget.onChangeEnd != null;

  @override
  Widget build(BuildContext context) {
    final showThumb = _hovering || _dragging;
    final value = (_dragValue ?? widget.value).clamp(0, widget.max).toDouble();
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: widget.trackHeight,
          thumbShape: showThumb
              ? RoundSliderThumbShape(enabledThumbRadius: widget.thumbRadius)
              : SliderComponentShape.noThumb,
          overlayShape: RoundSliderOverlayShape(
            overlayRadius: widget.overlayRadius,
          ),
        ),
        child: Slider(
          value: value,
          min: 0,
          max: widget.max,
          activeColor: widget.activeColor,
          inactiveColor: widget.inactiveColor,
          onChanged: !_enabled
              ? null
              : (value) {
                  setState(() => _dragValue = value);
                  widget.onChanged?.call(value);
                },
          onChangeStart: (value) => setState(() {
            _dragging = true;
            _dragValue = value;
          }),
          onChangeEnd: (value) {
            setState(() {
              _dragging = false;
              _dragValue = null;
            });
            widget.onChangeEnd?.call(value);
          },
        ),
      ),
    );
  }
}
