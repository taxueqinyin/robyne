import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/domain/theme_package.dart';
import '../../../core/theme/infrastructure/token_resolver.dart';
import '../../../features/settings/application/settings_providers.dart';

/// Renders one skin-declared knob as a real control.
///
/// The skin supplies type, bounds and default; this widget only handles the
/// interaction and writes the result back through the settings repository.
class ThemeSettingControl extends ConsumerWidget {
  const ThemeSettingControl({
    super.key,
    required this.theme,
    required this.setting,
    required this.value,
  });

  final ThemePackage theme;
  final ThemeSetting setting;
  final Object value;

  Future<void> _update(WidgetRef ref, Object? next) {
    return ref
        .read(settingsControllerProvider.notifier)
        .setThemeSettingValue(theme.id, setting.key, next);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = RobyneTheme.maybeOf(context)?.tokens;
    final brand =
        tokens?.color.brandBase ?? Theme.of(context).colorScheme.primary;
    final muted = tokens?.color.textMuted ?? Colors.grey;

    return switch (setting.type) {
      ThemeSettingType.range => _RangeControl(
        label: setting.label,
        value: value,
        min: setting.min ?? 0,
        max: setting.max ?? 100,
        brand: brand,
        muted: muted,
        onChanged: (next) => _update(ref, next),
      ),
      ThemeSettingType.toggle => _ToggleControl(
        label: setting.label,
        value: value == true || value.toString() == 'true',
        brand: brand,
        onChanged: (next) => _update(ref, next),
      ),
      ThemeSettingType.color => _ColorControl(
        label: setting.label,
        value: value,
        muted: muted,
        onChanged: (next) => _update(ref, next),
      ),
      ThemeSettingType.select => _SelectControl(
        label: setting.label,
        value: value.toString(),
        options: setting.options ?? const <String>[],
        brand: brand,
        onChanged: (next) => _update(ref, next),
      ),
      ThemeSettingType.text => _TextControl(
        label: setting.label,
        value: value.toString(),
        onChanged: (next) => _update(ref, next),
      ),
    };
  }
}

class _RangeControl extends StatefulWidget {
  const _RangeControl({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.brand,
    required this.muted,
    required this.onChanged,
  });

  final String label;
  final Object value;
  final num min;
  final num max;
  final Color brand;
  final Color muted;
  final ValueChanged<double> onChanged;

  @override
  State<_RangeControl> createState() => _RangeControlState();
}

class _RangeControlState extends State<_RangeControl> {
  late double _current;

  @override
  void initState() {
    super.initState();
    _current = _toDouble(widget.value);
  }

  @override
  void didUpdateWidget(covariant _RangeControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _current = _toDouble(widget.value);
    }
  }

  static double _toDouble(Object value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final min = widget.min.toDouble();
    final max = widget.max.toDouble();
    final clamped = _current.clamp(min, max).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(widget.label)),
              Text(
                clamped.toStringAsFixed(
                  clamped.truncateToDouble() == clamped ? 0 : 2,
                ),
                style: TextStyle(fontSize: 12, color: widget.muted),
              ),
            ],
          ),
          Slider(
            value: clamped,
            min: min,
            max: max,
            // ignore: deprecated_member_use
            activeColor: widget.brand,
            onChanged: (next) {
              setState(() => _current = next);
              widget.onChanged(next);
            },
          ),
        ],
      ),
    );
  }
}

class _ToggleControl extends StatelessWidget {
  const _ToggleControl({
    required this.label,
    required this.value,
    required this.brand,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final Color brand;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(label),
      value: value,
      // ignore: deprecated_member_use
      activeColor: brand,
      contentPadding: EdgeInsets.zero,
      onChanged: onChanged,
    );
  }
}

class _ColorControl extends StatelessWidget {
  const _ColorControl({
    required this.label,
    required this.value,
    required this.muted,
    required this.onChanged,
  });

  final String label;
  final Object value;
  final Color muted;
  final ValueChanged<String> onChanged;

  static const List<Color> _palette = <Color>[
    Color(0xFF2F6FED),
    Color(0xFF6EA8FE),
    Color(0xFFF2B749),
    Color(0xFFD64545),
    Color(0xFF2E9E5B),
    Color(0xFF9A7CFF),
    Color(0xFF3DD6A3),
    Color(0xFFE767AF),
    Color(0xFF1B1D21),
    Color(0xFFE8EAED),
  ];

  Color _parse() {
    if (value is Color) {
      return value as Color;
    }
    if (value is int) {
      return Color(value as int);
    }
    final text = value.toString().trim();
    if (!text.startsWith('#')) {
      return Colors.transparent;
    }
    final hex = text.substring(1);
    final buffer = StringBuffer();
    if (hex.length == 3) {
      buffer.write('FF');
      for (final unit in hex.split('')) {
        buffer.write(unit * 2);
      }
    } else if (hex.length == 6) {
      buffer.write('FF$hex');
    } else if (hex.length == 8) {
      buffer.write(hex);
    } else {
      return Colors.transparent;
    }
    final parsed = int.tryParse(buffer.toString(), radix: 16);
    return parsed == null ? Colors.transparent : Color(parsed);
  }

  static String _toHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final current = _parse();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(label)),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: current,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: muted.withValues(alpha: 0.4)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final color in _palette)
                _PaletteSwatch(
                  color: color,
                  selected: color.toARGB32() == current.toARGB32(),
                  muted: muted,
                  onTap: () => onChanged(_toHex(color)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One colour in the palette.
///
/// The selected colour is scaled up so it reads as "current" at a glance. A
/// plain border is not enough here: the palette spans near-white and
/// near-black, and any fixed outline colour disappears against one of them.
class _PaletteSwatch extends StatelessWidget {
  const _PaletteSwatch({
    required this.color,
    required this.selected,
    required this.muted,
    required this.onTap,
  });

  static const double _size = 32;

  /// How much larger the selected swatch renders.
  static const double _selectedScale = 1.5;

  final Color color;
  final bool selected;
  final Color muted;
  final VoidCallback onTap;

  /// An outline that stays visible on both pale and dark swatches.
  Color get _outline =>
      color.computeLuminance() > 0.5 ? Colors.black : Colors.white;

  @override
  Widget build(BuildContext context) {
    final size = _size * (selected ? _selectedScale : 1);
    return SizedBox(
      // Reserve the scaled footprint so growing the swatch never reflows the
      // row of neighbours.
      width: _size * _selectedScale,
      height: _size * _selectedScale,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          width: size,
          height: size,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
                border: selected
                    ? Border.all(
                        color: _outline.withValues(alpha: 0.45),
                        width: 1,
                      )
                    : Border.all(
                        color: muted.withValues(alpha: 0.25),
                        width: 1,
                      ),
              ),
              child: selected
                  ? Icon(Icons.check, size: 16, color: _outline)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectControl extends StatelessWidget {
  const _SelectControl({
    required this.label,
    required this.value,
    required this.options,
    required this.brand,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final Color brand;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: <Widget>[
              for (final option in options)
                ChoiceChip(
                  label: Text(option),
                  selected: option == value,
                  selectedColor: brand.withValues(alpha: 0.25),
                  onSelected: (_) => onChanged(option),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TextControl extends StatefulWidget {
  const _TextControl({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_TextControl> createState() => _TextControlState();
}

class _TextControlState extends State<_TextControl> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _TextControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(labelText: widget.label, isDense: true),
        onSubmitted: widget.onChanged,
      ),
    );
  }
}
