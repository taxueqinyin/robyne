import 'theme_layout.dart';
import 'theme_package.dart';
import 'theme_regions.dart';

/// A user-owned Level 2 layout override.
///
/// The roadmap D2/D4 boundary is intentional: an override may move the five
/// known regions, change their main-axis ratio, or pick a `content.style`.
/// It cannot add a region, introduce a widget, or name an absolute pixel.
/// `null` means "inherit the skin's declaration"; an explicit arrangement
/// list means "replace that form factor's arrangement".
class ThemeLayoutOverride {
  const ThemeLayoutOverride({
    this.desktopArrangement,
    this.mobileArrangement,
    this.contentStyle,
  });

  static const ThemeLayoutOverride empty = ThemeLayoutOverride();

  final RobyneArrangement? desktopArrangement;
  final RobyneArrangement? mobileArrangement;
  final ThemeListStyle? contentStyle;

  bool get isEmpty =>
      desktopArrangement == null &&
      mobileArrangement == null &&
      contentStyle == null;

  ThemeLayoutOverride copyWith({
    Object? desktopArrangement = _sentinel,
    Object? mobileArrangement = _sentinel,
    Object? contentStyle = _sentinel,
  }) {
    return ThemeLayoutOverride(
      desktopArrangement: identical(desktopArrangement, _sentinel)
          ? this.desktopArrangement
          : desktopArrangement as RobyneArrangement?,
      mobileArrangement: identical(mobileArrangement, _sentinel)
          ? this.mobileArrangement
          : mobileArrangement as RobyneArrangement?,
      contentStyle: identical(contentStyle, _sentinel)
          ? this.contentStyle
          : contentStyle as ThemeListStyle?,
    );
  }

  /// Applies this override to [package] without touching the package source.
  ///
  /// This is deliberately a pure transformation: the active package provider
  /// can therefore keep using `overrideWithValue` in tests while production
  /// stacks the user's overrides on top of the skin's own declaration.
  ThemePackage apply(ThemePackage package) {
    if (isEmpty) {
      return package;
    }
    final layout = package.layout;
    return package.copyWith(
      layout: layout.copyWith(
        desktop: desktopArrangement == null
            ? layout.desktop
            : layout.desktop.copyWith(arrangement: desktopArrangement),
        mobile: mobileArrangement == null
            ? layout.mobile
            : layout.mobile.copyWith(arrangement: mobileArrangement),
        content: contentStyle == null
            ? layout.content
            : layout.content.copyWith(listStyle: contentStyle),
      ),
    );
  }

  /// Parses the persisted form.
  ///
  /// Missing lists are inheritance, not a request to reset to baseline. A
  /// present-but-malformed list is repaired by [RobyneArrangement.parse] so a
  /// hand-edited settings row cannot white-screen the shell.
  factory ThemeLayoutOverride.fromJson(Object? raw) {
    if (raw is! Map) {
      return empty;
    }
    final desktopRaw = raw['desktop'] ?? raw['desktopArrangement'];
    final mobileRaw = raw['mobile'] ?? raw['mobileArrangement'];
    final contentRaw = raw['content'];
    final contentStyleRaw =
        raw['contentStyle'] ?? (contentRaw is Map ? contentRaw['style'] : null);

    return ThemeLayoutOverride(
      desktopArrangement: desktopRaw is List
          ? RobyneArrangement.parse(
              desktopRaw,
              formFactor: RobyneFormFactor.desktop,
            )
          : null,
      mobileArrangement: mobileRaw is List
          ? RobyneArrangement.parse(
              mobileRaw,
              formFactor: RobyneFormFactor.mobile,
            )
          : null,
      contentStyle: _contentStyle(contentStyleRaw),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      if (desktopArrangement != null)
        'desktop': desktopArrangement!.placements
            .map(_placementToJson)
            .toList(growable: false),
      if (mobileArrangement != null)
        'mobile': mobileArrangement!.placements
            .map(_placementToJson)
            .toList(growable: false),
      if (contentStyle != null) 'contentStyle': contentStyle!.name,
    };
  }

  static ThemeListStyle? _contentStyle(Object? raw) {
    final name = raw?.toString().trim();
    if (name == null || name.isEmpty) {
      return null;
    }
    for (final style in ThemeListStyle.values) {
      if (style.name == name) {
        return style;
      }
    }
    return null;
  }

  static Map<String, Object?> _placementToJson(
    RobyneRegionPlacement placement,
  ) {
    return <String, Object?>{
      'region': placement.region.name,
      'slot': placement.slot.name,
      if (placement.size != null) 'size': placement.size,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is ThemeLayoutOverride &&
        other.desktopArrangement == desktopArrangement &&
        other.mobileArrangement == mobileArrangement &&
        other.contentStyle == contentStyle;
  }

  @override
  int get hashCode =>
      Object.hash(desktopArrangement, mobileArrangement, contentStyle);
}

const Object _sentinel = Object();
