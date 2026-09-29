/// Which shell destinations a skin renders, in what order, and where the rest go.
///
/// A skin composes the chrome, so it decides both things:
///
/// - *which* entries show, because its rail may list `playlists` and also a
///   playlist group beneath it — two controls, one destination
/// - *in what order*, because a rail's sequence is part of its composition: a
///   skin built around listening leads with `discover`, one built around a
///   local collection leads with `library`
/// - *where the overflow goes*, because a phone's tab bar fits four or five
///   entries while the app has more destinations than that. Hiding the rest
///   outright is what left plugin import unreachable on a phone; the answer to
///   "二级菜单的入口在哪" belongs to the skin, since the skin is what decided
///   how many entries fit in the first place.
///
/// Both are deliberately narrow, for the same reason regions are:
///
/// - only navigation *entries* are affected, never [RobyneRegion]s — `content`
///   and `playerBar` must always render or the app stops being usable
/// - a hidden or overflowed entry stays reachable through the overflow surface,
///   so a skin cannot strand the user
/// - `settings` is never hidden: it is the only route back to the appearance
///   panel
/// - unknown names are ignored, so a skin written for a newer app cannot
///   accidentally hide something on an older one
library;

import 'theme_regions.dart' show RobyneFormFactor;

/// The navigation entries a skin may hide or move into an overflow.
///
/// Values are snake_case destination ids rather than enum names so a manifest
/// reads like the rest of the skin file.
enum ThemeNavEntry {
  search('search'),
  discover('discover'),
  library('library'),
  nowPlaying('nowPlaying'),
  playlists('playlists'),
  downloads('downloads'),
  plugins('plugins'),
  settings('settings');

  const ThemeNavEntry(this.jsonName);

  /// The name a skin writes in `theme.json`.
  final String jsonName;

  static ThemeNavEntry? fromJsonName(String? name) {
    if (name == null) {
      return null;
    }
    for (final value in values) {
      if (value.jsonName == name) {
        return value;
      }
    }
    return null;
  }
}

/// Where the destinations that do not fit the primary bar are collected.
enum ThemeOverflowSlot {
  /// No overflow surface: only the entries that fit are reachable.
  ///
  /// Legitimate for a skin that deliberately exposes a minimal surface, but a
  /// trap for a general-purpose one — which is why it is the desktop default
  /// (the rail has room for everything) and not the phone default.
  none('none'),

  /// A "more" entry in the primary bar that opens a sheet listing the rest.
  moreTab('moreTab'),

  /// An entry on the home page's own header, beside the search field.
  homeHeader('homeHeader');

  const ThemeOverflowSlot(this.jsonName);

  /// The name a skin writes in `theme.json`.
  final String jsonName;

  static ThemeOverflowSlot? fromJsonName(String? name) {
    if (name == null) {
      return null;
    }
    for (final value in values) {
      if (value.jsonName == name) {
        return value;
      }
    }
    return null;
  }
}

/// The navigation declarations in effect, per form factor.
///
/// `desktop` and `mobile` are separate for the same reason `layout.home` is:
/// the phone's four-slot tab bar cannot afford to lose an entry that the
/// desktop rail can, and neither can it absorb the rail's nine entries.
class ThemeNavigation {
  const ThemeNavigation({
    this.desktop = const <ThemeNavEntry>{},
    this.mobile = const <ThemeNavEntry>{},
    this.desktopOverflow = ThemeOverflowSlot.none,
    this.mobileOverflow = ThemeOverflowSlot.moreTab,
    this.desktopOrder = const <ThemeNavEntry>[],
    this.mobileOrder = const <ThemeNavEntry>[],
  });

  const ThemeNavigation.empty()
    : desktop = const <ThemeNavEntry>{},
      mobile = const <ThemeNavEntry>{},
      desktopOverflow = ThemeOverflowSlot.none,
      mobileOverflow = ThemeOverflowSlot.moreTab,
      desktopOrder = const <ThemeNavEntry>[],
      mobileOrder = const <ThemeNavEntry>[];

  final Set<ThemeNavEntry> desktop;
  final Set<ThemeNavEntry> mobile;

  /// The display order a skin requests, per form factor.
  ///
  /// This is a *prefix*, not a full permutation: entries the skin does not
  /// mention keep their built-in relative order and follow the ones it does.
  /// That keeps a skin honest about the small thing it wanted to change
  /// ("put 发现 first") instead of forcing it to restate a list it mostly
  /// agrees with, and it means an app that later gains a destination does not
  /// silently drop it from skins that were written before.
  ///
  /// A [ThemeNavEntry.hidden] name is skipped here too — hiding still wins.
  final List<ThemeNavEntry> desktopOrder;
  final List<ThemeNavEntry> mobileOrder;

  /// Where the desktop rail collects its overflow.
  ///
  /// Defaults to [ThemeOverflowSlot.none]: the rail already shows every entry.
  final ThemeOverflowSlot desktopOverflow;

  /// Where the phone bar collects its overflow.
  ///
  /// Defaults to [ThemeOverflowSlot.moreTab], not `none`. A phone cannot show
  /// every destination at once, and defaulting to `none` is exactly what left
  /// plugin import unreachable with no way in. A skin may still choose `none`
  /// explicitly when a deliberately minimal surface is its intent.
  final ThemeOverflowSlot mobileOverflow;

  ThemeOverflowSlot overflowFor(RobyneFormFactor formFactor) {
    return formFactor == RobyneFormFactor.desktop
        ? desktopOverflow
        : mobileOverflow;
  }

  bool get isEmpty =>
      desktop.isEmpty &&
      mobile.isEmpty &&
      desktopOverflow == ThemeOverflowSlot.none &&
      mobileOverflow == ThemeOverflowSlot.moreTab &&
      desktopOrder.isEmpty &&
      mobileOrder.isEmpty;

  /// Sorts [entries] into the order a skin asked for.
  ///
  /// [entries] is the surface's own selection, already filtered by
  /// [isHidden] — so a skin cannot use `order` to resurrect an entry it hid,
  /// and cannot use it to place a destination the surface does not offer.
  /// Unknown and duplicate names drop out, leaving the rest in their built-in
  /// sequence.
  List<T> applyOrder<T>(
    List<T> entries,
    RobyneFormFactor formFactor,
    ThemeNavEntry Function(T) keyOf,
  ) {
    final order = formFactor == RobyneFormFactor.desktop
        ? desktopOrder
        : mobileOrder;
    if (order.isEmpty) {
      return entries;
    }
    final rank = <ThemeNavEntry, int>{
      for (var index = 0; index < order.length; index += 1) order[index]: index,
    };
    final ranked = <T>[];
    final rest = <T>[];
    for (final entry in entries) {
      final rank_ = rank[keyOf(entry)];
      if (rank_ == null) {
        rest.add(entry);
      } else {
        ranked.add(entry);
      }
    }
    // Stable: equally ranked items (possible only with duplicates, which the
    // parser drops) keep their input order, and everything unranked keeps its
    // built-in relative order behind the ranked block.
    ranked.sort((a, b) => rank[keyOf(a)]!.compareTo(rank[keyOf(b)]!));
    return <T>[...ranked, ...rest];
  }

  /// Whether [entry] is hidden for [formFactor].
  ///
  /// `settings` is never hidden: it is the only way to reach the appearance
  /// panel, and a skin must not be able to strand the user there.
  bool isHidden(ThemeNavEntry entry, RobyneFormFactor formFactor) {
    if (entry == ThemeNavEntry.settings) {
      return false;
    }
    final set = formFactor == RobyneFormFactor.desktop ? desktop : mobile;
    return set.contains(entry);
  }

  /// Parses the manifest's `navigation` object.
  ///
  /// Accepts both `navigation.hidden` (entries to drop) and the sibling
  /// `desktopOverflow` / `mobileOverflow` keys.
  static ThemeNavigation parse(Object? raw) {
    if (raw is! Map) {
      return const ThemeNavigation.empty();
    }
    Set<ThemeNavEntry> read(Object? value) {
      final entries = <ThemeNavEntry>{};
      if (value is List) {
        for (final item in value) {
          final entry = ThemeNavEntry.fromJsonName(item?.toString().trim());
          if (entry != null) {
            entries.add(entry);
          }
        }
      }
      return entries;
    }

    ThemeOverflowSlot overflow(Object? value, ThemeOverflowSlot fallback) {
      return ThemeOverflowSlot.fromJsonName(value?.toString().trim()) ??
          fallback;
    }

    return ThemeNavigation(
      desktop: read(raw['desktop']),
      mobile: read(raw['mobile']),
      desktopOverflow: overflow(raw['desktopOverflow'], ThemeOverflowSlot.none),
      mobileOverflow: overflow(
        raw['mobileOverflow'],
        ThemeOverflowSlot.moreTab,
      ),
      desktopOrder: ThemeNavigation.readOrder(raw['desktopOrder']),
      mobileOrder: ThemeNavigation.readOrder(raw['mobileOrder']),
    );
  }

  /// Parses an order list, dropping unknown names and duplicates.
  ///
  /// A duplicate would give two entries the same rank, which makes the sort
  /// ambiguous for no benefit; the first mention wins.
  static List<ThemeNavEntry> readOrder(Object? raw) {
    if (raw is! List) {
      return const <ThemeNavEntry>[];
    }
    final order = <ThemeNavEntry>[];
    for (final item in raw) {
      final entry = ThemeNavEntry.fromJsonName(item?.toString().trim());
      if (entry != null && !order.contains(entry)) {
        order.add(entry);
      }
    }
    return order;
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      if (desktop.isNotEmpty)
        'desktop': <String>[for (final entry in desktop) entry.jsonName],
      if (mobile.isNotEmpty)
        'mobile': <String>[for (final entry in mobile) entry.jsonName],
      if (desktopOrder.isNotEmpty)
        'desktopOrder': <String>[
          for (final entry in desktopOrder) entry.jsonName,
        ],
      if (mobileOrder.isNotEmpty)
        'mobileOrder': <String>[
          for (final entry in mobileOrder) entry.jsonName,
        ],
      'desktopOverflow': desktopOverflow.jsonName,
      'mobileOverflow': mobileOverflow.jsonName,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is ThemeNavigation &&
        _same(other.desktop, desktop) &&
        _same(other.mobile, mobile) &&
        other.desktopOverflow == desktopOverflow &&
        other.mobileOverflow == mobileOverflow &&
        other.desktopOrder.length == desktopOrder.length &&
        other.mobileOrder.length == mobileOrder.length &&
        _orderedSame(other.desktopOrder, desktopOrder) &&
        _orderedSame(other.mobileOrder, mobileOrder);
  }

  static bool _same(Set<ThemeNavEntry> a, Set<ThemeNavEntry> b) {
    if (a.length != b.length) {
      return false;
    }
    return a.every(b.contains);
  }

  static bool _orderedSame(List<ThemeNavEntry> a, List<ThemeNavEntry> b) {
    for (var index = 0; index < a.length; index += 1) {
      if (a[index] != b[index]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(
      desktop.toList()..sort((x, y) => x.index.compareTo(y.index)),
    ),
    Object.hashAll(mobile.toList()..sort((x, y) => x.index.compareTo(y.index))),
    desktopOverflow,
    mobileOverflow,
    Object.hashAll(desktopOrder),
    Object.hashAll(mobileOrder),
  );
}
