import 'theme_regions.dart';

/// Declarative home-page composition for the flagship shell.
///
/// The design's discovery page is a *sequence of blocks* — hero banner,
/// recommendation rail, recently-added list. Hard-coding that order in the
/// widget would make every skin look identical again. Instead a skin declares
/// the blocks it wants, in the order it wants them, and the app renders the
/// ones it can supply data for. Unknown blocks are ignored, so an older app
/// degrades instead of failing.
///
/// The composition is **per form factor**, because the design's own two boards
/// differ: the desktop column is a hero plus a recommendation rail, while the
/// phone column is a hero plus a liked-songs list. `blocks` is the shared
/// default; `desktop` and `mobile` override it independently, so a skin can
/// write one composition and shape it later, or shape both from the start.
class ThemeHomeLayout {
  const ThemeHomeLayout({required this.blocks, this.desktop, this.mobile});

  const ThemeHomeLayout.baseline()
    : blocks = const <ThemeHomeBlock>[
        ThemeHomeBlock.quickActions,
        ThemeHomeBlock.hero,
        ThemeHomeBlock.recommendations,
        ThemeHomeBlock.recent,
      ],
      desktop = null,
      mobile = null;

  /// Blocks used when the form factor has no override.
  final List<ThemeHomeBlock> blocks;

  /// Desktop-only composition, or null to inherit [blocks].
  final List<ThemeHomeBlock>? desktop;

  /// Phone-only composition, or null to inherit [blocks].
  final List<ThemeHomeBlock>? mobile;

  /// The composition to render for [formFactor].
  List<ThemeHomeBlock> resolve(RobyneFormFactor formFactor) {
    final override = formFactor == RobyneFormFactor.desktop ? desktop : mobile;
    final resolved = override ?? blocks;
    return resolved.isEmpty ? blocks : resolved;
  }

  ThemeHomeLayout copyWith({
    List<ThemeHomeBlock>? blocks,
    List<ThemeHomeBlock>? desktop,
    List<ThemeHomeBlock>? mobile,
  }) {
    return ThemeHomeLayout(
      blocks: blocks ?? this.blocks,
      desktop: desktop ?? this.desktop,
      mobile: mobile ?? this.mobile,
    );
  }

  /// Parses `layout.home.blocks`.
  ///
  /// Missing or malformed input falls back to the flagship baseline. The set
  /// is intentionally closed: a skin can reorder or omit blocks, but cannot
  /// invent arbitrary widgets.
  static ThemeHomeLayout parse(Object? raw) {
    if (raw is List) {
      final blocks = _parseBlocks(raw);
      if (blocks.isEmpty) {
        return const ThemeHomeLayout.baseline();
      }
      return ThemeHomeLayout(blocks: blocks);
    }
    if (raw is! Map) {
      return const ThemeHomeLayout.baseline();
    }
    final shared = _parseBlocks(raw['blocks']);
    final desktop = _parseBlocks(raw['desktop']);
    final mobile = _parseBlocks(raw['mobile']);
    if (shared.isEmpty && desktop.isEmpty && mobile.isEmpty) {
      return const ThemeHomeLayout.baseline();
    }
    // A skin that shapes only one form factor must not leave the other with
    // nothing to render, so the shared list anchors whatever is missing and
    // the flagship baseline anchors the shared list itself.
    const fallback = ThemeHomeLayout.baseline();
    return ThemeHomeLayout(
      blocks: shared.isNotEmpty ? shared : fallback.blocks,
      desktop: desktop.isEmpty ? null : desktop,
      mobile: mobile.isEmpty ? null : mobile,
    );
  }

  Map<String, Object?> toJson() {
    final json = <String, Object?>{
      'blocks': blocks.map((block) => block.name).toList(growable: false),
    };
    final desktop = this.desktop;
    if (desktop != null) {
      json['desktop'] = <String, Object?>{
        'blocks': desktop.map((block) => block.name).toList(growable: false),
      };
    }
    final mobile = this.mobile;
    if (mobile != null) {
      json['mobile'] = <String, Object?>{
        'blocks': mobile.map((block) => block.name).toList(growable: false),
      };
    }
    return json;
  }

  @override
  bool operator ==(Object other) {
    return other is ThemeHomeLayout &&
        _sameList(other.blocks, blocks) &&
        _sameList(other.desktop, desktop) &&
        _sameList(other.mobile, mobile);
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(blocks),
    desktop == null ? null : Object.hashAll(desktop!),
    mobile == null ? null : Object.hashAll(mobile!),
  );

  /// Accepts either a bare array or the `{ "blocks": [...] }` wrapper, so the
  /// form-factor entries read like the `layout.<form>.arrangement` siblings.
  static List<ThemeHomeBlock> _parseBlocks(Object? raw) {
    final list = raw is Map ? raw['blocks'] : raw;
    if (list is! List) {
      return const <ThemeHomeBlock>[];
    }
    final blocks = <ThemeHomeBlock>[];
    for (final entry in list) {
      final name = entry?.toString().trim();
      if (name == null || name.isEmpty) {
        continue;
      }
      final block = ThemeHomeBlock.fromName(name);
      if (block != null && !blocks.contains(block)) {
        blocks.add(block);
      }
    }
    return List<ThemeHomeBlock>.unmodifiable(blocks);
  }

  static bool _sameList(List<ThemeHomeBlock>? a, List<ThemeHomeBlock>? b) {
    if (a == null || b == null) {
      return a == b;
    }
    if (a.length != b.length) {
      return false;
    }
    for (var index = 0; index < a.length; index += 1) {
      if (a[index] != b[index]) {
        return false;
      }
    }
    return true;
  }
}

/// The closed set of home-page blocks a skin may arrange.
enum ThemeHomeBlock {
  /// The phone design's four-tile entry grid (每日电台 / 排行榜 / 分类歌单 /
  /// 我喜欢). It renders as a compact row on a phone and stays out of the way
  /// on a desktop column, where the same destinations are already in the rail.
  quickActions,

  /// A horizontal row of filter chips (推荐 / 电台 / 歌单 / 排行 / 本地).
  /// It is the landscape phone's stand-in for [quickActions]: same "pick a
  /// shelf" intent in one 36dp row instead of two 42dp-tile rows.
  categoryChips,

  /// Large gradient banner with a primary call to action.
  hero,

  /// Horizontally scrolling recommendation cards.
  recommendations,

  /// The user's recently added / recently played tracks.
  recent,

  /// The user's liked songs, which the phone board leads with.
  favorites,

  /// A compact list of the current queue for home-page surfaces.
  queue;

  static ThemeHomeBlock? fromName(String name) {
    for (final block in values) {
      if (block.name == name) {
        return block;
      }
    }
    return null;
  }
}
