import 'package:flutter/material.dart';

import '../domain/theme_materials.dart';
import '../domain/theme_tokens.dart';
import 'theme_path_guard.dart';

/// Applies dotted-path overrides onto a token tree.
///
/// Skin authors declare knobs like `{"key": "blur", "target": "effects.blur"}`;
/// this maps those targets onto the actual token fields. Unknown targets are
/// ignored so a skin typo degrades to "knob does nothing", never to a crash.
class TokenPatcher {
  const TokenPatcher();

  /// Applies every entry of [values] to [base].
  ThemeTokens apply(ThemeTokens base, Map<String, Object> values) {
    var tokens = base;
    for (final entry in values.entries) {
      tokens = _applyOne(tokens, entry.key, entry.value);
    }
    return tokens;
  }

  ThemeTokens _applyOne(ThemeTokens tokens, String target, Object value) {
    final parts = target.split('.');
    if (parts.isEmpty) {
      return tokens;
    }
    switch (parts.first) {
      case 'color':
        return _color(tokens, parts, value);
      case 'radius':
        return _radius(tokens, parts, value);
      case 'spacing':
        return _spacing(tokens, parts, value);
      case 'typography':
        return _typography(tokens, parts, value);
      case 'elevation':
        return _elevation(tokens, parts, value);
      case 'effects':
        return _effects(tokens, parts, value);
      case 'background':
        return _background(tokens, parts, value);
      case 'components':
        return _components(tokens, parts, value);
      case 'materials':
        return _materials(tokens, parts, value);
      default:
        return tokens;
    }
  }

  /// Knob targets for material scalars, e.g. `materials.card.blur`.
  ///
  /// Only numbers are patchable here. Colour and gradient already have homes
  /// in `components`, and exposing structured paint recipes on a slider would
  /// let a knob smuggle arbitrary data into the renderer.
  ThemeTokens _materials(ThemeTokens tokens, List<String> parts, Object value) {
    if (parts.length < 3) {
      return tokens;
    }
    final number = _asDouble(value);
    if (number == null) {
      return tokens;
    }
    final surface = parts[1];
    final name = parts[2];
    final current = tokens.materials[surface];
    if (current == null) {
      return tokens;
    }
    final updated = switch (name) {
      'opacity' => current.copyWith(opacity: number.clamp(0, 1).toDouble()),
      'blur' => current.copyWith(blur: number.clamp(0, 200).toDouble()),
      'saturation' => current.copyWith(
        saturation: number.clamp(0, 4).toDouble(),
      ),
      'brightness' => current.copyWith(
        brightness: number.clamp(0, 4).toDouble(),
      ),
      'contrast' => current.copyWith(contrast: number.clamp(0, 4).toDouble()),
      'grayscale' => current.copyWith(grayscale: number.clamp(0, 1).toDouble()),
      'radius' => current.copyWith(radius: number.clamp(0, 4096).toDouble()),
      _ => current,
    };
    return tokens.copyWith(
      materials: _replaceSurface(tokens.materials, surface, updated),
    );
  }

  static ThemeMaterials _replaceSurface(
    ThemeMaterials materials,
    String surface,
    ThemeMaterial material,
  ) {
    return switch (surface) {
      'navBar' => materials.copyWith(navBar: material),
      'topBar' => materials.copyWith(topBar: material),
      'playerBar' => materials.copyWith(playerBar: material),
      'queue' => materials.copyWith(queue: material),
      'card' => materials.copyWith(card: material),
      'content' => materials.copyWith(content: material),
      'hero' => materials.copyWith(hero: material),
      _ => materials,
    };
  }

  /// Knob targets for component tokens, e.g. `components.lyric.activeLine`.
  ///
  /// Only plain colours are patchable: a gradient is a structured value that a
  /// slider or colour picker cannot produce, and letting a knob write one
  /// would let a skin smuggle arbitrary data through the patcher.
  ThemeTokens _components(
    ThemeTokens tokens,
    List<String> parts,
    Object value,
  ) {
    if (parts.length < 3) {
      return tokens;
    }
    final color = _asColor(value);
    if (color == null) {
      return tokens;
    }
    final group = parts[1];
    final name = parts[2];
    final c = tokens.components;
    final updated = switch (group) {
      'navBar' => switch (name) {
        'background' => c.copyWith(
          navBar: c.navBar.copyWith(background: color),
        ),
        'selectedItem' => c.copyWith(
          navBar: c.navBar.copyWith(selectedItem: color),
        ),
        'selectedIndicator' => c.copyWith(
          navBar: c.navBar.copyWith(selectedIndicator: color),
        ),
        'selectedIndicatorFill' => c.copyWith(
          navBar: c.navBar.copyWith(selectedIndicatorFill: color),
        ),
        _ => c,
      },
      'playerBar' => switch (name) {
        'background' => c.copyWith(
          playerBar: c.playerBar.copyWith(background: color),
        ),
        'progressTrack' => c.copyWith(
          playerBar: c.playerBar.copyWith(progressTrack: color),
        ),
        'progressActive' => c.copyWith(
          playerBar: c.playerBar.copyWith(progressActive: color),
        ),
        _ => c,
      },
      'lyric' => switch (name) {
        'activeLine' => c.copyWith(lyric: c.lyric.copyWith(activeLine: color)),
        'inactiveLine' => c.copyWith(
          lyric: c.lyric.copyWith(inactiveLine: color),
        ),
        'activeBackground' => c.copyWith(
          lyric: c.lyric.copyWith(activeBackground: color),
        ),
        _ => c,
      },
      'card' => switch (name) {
        'surface' => c.copyWith(card: c.card.copyWith(surface: color)),
        'hover' => c.copyWith(card: c.card.copyWith(hover: color)),
        'selected' => c.copyWith(card: c.card.copyWith(selected: color)),
        _ => c,
      },
      'list' => switch (name) {
        'itemSelected' => c.copyWith(
          list: c.list.copyWith(itemSelected: color),
        ),
        'itemHover' => c.copyWith(list: c.list.copyWith(itemHover: color)),
        _ => c,
      },
      _ => c,
    };
    return tokens.copyWith(components: updated);
  }

  ThemeTokens _color(ThemeTokens tokens, List<String> parts, Object value) {
    if (parts.length < 3) {
      return tokens;
    }
    final group = parts[1];
    final name = parts[2];
    final color = _asColor(value);
    if (color == null) {
      return tokens;
    }
    final c = tokens.color;
    ThemeColors updated = c;
    switch (group) {
      case 'background':
        updated = switch (name) {
          'base' => c.copyWith(backgroundBase: color),
          'elevated' => c.copyWith(backgroundElevated: color),
          'sunken' => c.copyWith(backgroundSunken: color),
          'overlay' => c.copyWith(backgroundOverlay: color),
          _ => c,
        };
      case 'surface':
        updated = switch (name) {
          'base' => c.copyWith(surfaceBase: color),
          'hover' => c.copyWith(surfaceHover: color),
          'active' => c.copyWith(surfaceActive: color),
          'selected' => c.copyWith(surfaceSelected: color),
          _ => c,
        };
      case 'brand':
        updated = switch (name) {
          'base' => c.copyWith(brandBase: color),
          'hover' => c.copyWith(brandHover: color),
          'muted' => c.copyWith(brandMuted: color),
          'onBrand' => c.copyWith(onBrand: color),
          _ => c,
        };
      case 'text':
        updated = switch (name) {
          'primary' => c.copyWith(textPrimary: color),
          'secondary' => c.copyWith(textSecondary: color),
          'muted' => c.copyWith(textMuted: color),
          'disabled' => c.copyWith(textDisabled: color),
          _ => c,
        };
      case 'border':
        updated = switch (name) {
          'subtle' => c.copyWith(borderSubtle: color),
          'default' => c.copyWith(borderDefault: color),
          'strong' => c.copyWith(borderStrong: color),
          'focus' => c.copyWith(borderFocus: color),
          _ => c,
        };
      case 'status':
        updated = switch (name) {
          'danger' => c.copyWith(danger: color),
          'warning' => c.copyWith(warning: color),
          'success' => c.copyWith(success: color),
          _ => c,
        };
      default:
        updated = c;
    }
    return tokens.copyWith(color: updated);
  }

  ThemeTokens _radius(ThemeTokens tokens, List<String> parts, Object value) {
    if (parts.length < 2) {
      return tokens;
    }
    final number = _asDouble(value);
    if (number == null) {
      return tokens;
    }
    final r = tokens.radius;
    final updated = switch (parts[1]) {
      'sm' => r.copyWith(sm: number),
      'md' => r.copyWith(md: number),
      'lg' => r.copyWith(lg: number),
      'full' => r.copyWith(full: number),
      _ => r,
    };
    return tokens.copyWith(radius: updated);
  }

  ThemeTokens _spacing(ThemeTokens tokens, List<String> parts, Object value) {
    if (parts.length < 2) {
      return tokens;
    }
    final number = _asDouble(value);
    if (number == null) {
      return tokens;
    }
    final s = tokens.spacing;
    final updated = switch (parts[1]) {
      'xs' => s.copyWith(xs: number),
      'sm' => s.copyWith(sm: number),
      'md' => s.copyWith(md: number),
      'lg' => s.copyWith(lg: number),
      'xl' => s.copyWith(xl: number),
      _ => s,
    };
    return tokens.copyWith(spacing: updated);
  }

  ThemeTokens _typography(
    ThemeTokens tokens,
    List<String> parts,
    Object value,
  ) {
    if (parts.length < 2) {
      return tokens;
    }
    final t = tokens.typography;
    ThemeTypography updated;
    switch (parts[1]) {
      case 'scale':
        final number = _asDouble(value);
        if (number == null) {
          return tokens;
        }
        updated = t.copyWith(scale: number.clamp(0.75, 1.5).toDouble());
      case 'family':
        final text = value.toString().trim();
        updated = t.copyWith(
          fontFamily: RegExp(r'^[A-Za-z0-9 _-]{1,64}$').hasMatch(text)
              ? text
              : null,
        );
      case 'bodyWeight':
      case 'titleWeight':
        final weight = _asDouble(value);
        if (weight == null) {
          return tokens;
        }
        final clamped = weight.round().clamp(100, 900);
        updated = parts[1] == 'bodyWeight'
            ? t.copyWith(bodyWeight: clamped)
            : t.copyWith(titleWeight: clamped);
      default:
        return tokens;
    }
    return tokens.copyWith(typography: updated);
  }

  ThemeTokens _elevation(ThemeTokens tokens, List<String> parts, Object value) {
    if (parts.length < 2) {
      return tokens;
    }
    final number = _asDouble(value);
    if (number == null) {
      return tokens;
    }
    final e = tokens.elevation;
    final updated = switch (parts[1]) {
      'sm' => e.copyWith(sm: number),
      'md' => e.copyWith(md: number),
      'lg' => e.copyWith(lg: number),
      _ => e,
    };
    return tokens.copyWith(elevation: updated);
  }

  ThemeTokens _effects(ThemeTokens tokens, List<String> parts, Object value) {
    if (parts.length < 2) {
      return tokens;
    }
    final number = _asDouble(value);
    if (number == null) {
      return tokens;
    }
    final e = tokens.effects;
    final updated = switch (parts[1]) {
      'blur' => e.copyWith(blur: number.clamp(0, 40).toDouble()),
      'glassOpacity' => e.copyWith(glassOpacity: number.clamp(0, 1).toDouble()),
      _ => e,
    };
    return tokens.copyWith(effects: updated);
  }

  ThemeTokens _background(
    ThemeTokens tokens,
    List<String> parts,
    Object value,
  ) {
    if (parts.length < 2) {
      return tokens;
    }
    final b = tokens.background;
    ThemeBackground updated;
    switch (parts[1]) {
      case 'image':
        final text = value.toString().trim();
        // A knob must not be able to point the background at an arbitrary
        // path; the same budget as static manifests applies.
        updated = b.copyWith(image: ThemePathGuard.sanitizeAsset(text));
      case 'fillMode':
        updated = b.copyWith(
          fillMode: ThemeBackgroundFillMode.fromName(value.toString()),
        );
      case 'overlay':
        final color = _asColor(value);
        if (color == null) {
          return tokens;
        }
        updated = b.copyWith(overlay: color);
      case 'overlayOpacity':
        final number = _asDouble(value);
        if (number == null) {
          return tokens;
        }
        updated = b.copyWith(overlayOpacity: number.clamp(0, 1).toDouble());
      default:
        return tokens;
    }
    return tokens.copyWith(background: updated);
  }

  static Color? _asColor(Object value) {
    if (value is Color) {
      return value;
    }
    if (value is int) {
      return Color(value);
    }
    final text = value.toString().trim();
    if (!text.startsWith('#')) {
      return null;
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
      return null;
    }
    final parsed = int.tryParse(buffer.toString(), radix: 16);
    return parsed == null ? null : Color(parsed);
  }

  static double? _asDouble(Object value) {
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value.toString());
    // `double.tryParse('1e999')` yields Infinity, which would reach the
    // renderer as a non-finite radius or height.
    if (parsed == null || !parsed.isFinite) {
      return null;
    }
    return parsed;
  }
}
