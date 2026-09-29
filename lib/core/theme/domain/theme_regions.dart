/// The two-layer region model from `THEME_ROADMAP.md` D6.
///
/// A **region** is an identity ("I am the navigation bar") that stays stable
/// across form factors, so "move the nav bar to the right" means the same
/// thing on a desktop and on a phone. A **slot** is a placement ("I sit on
/// the left"), and the legal slots depend on the form factor: a 400dp phone
/// has no room for a side rail, so `left`/`right` do not exist there.
///
/// Skins declare slots and main-axis ratios; they never declare pixels and
/// they never invent regions. The application decides what the viewport is
/// and how a ratio becomes dp (D7).
library;

import 'dart:math' as math;

/// The five regions of the shell. This set is closed by design (D2): a skin
/// can rearrange them, but it cannot add one or hide one.
enum RobyneRegion {
  /// Search field and window controls. Desktop-leaning; a phone shell may
  /// simply omit it.
  topBar,

  /// Primary navigation: a side rail on desktop, a tab strip on mobile.
  navBar,

  /// The content column. **Every** arrangement must contain it or the shell
  /// falls back to the baseline: an app with no content region cannot be
  /// used at all.
  content,

  /// Playback transport.
  playerBar,

  /// The play queue. Docks beside the content on a wide window and becomes an
  /// overlay when the content column would be starved.
  queue,
}

/// Where a region sits. Values are constrained per form factor.
enum RobyneSlot {
  top,
  left,
  center,
  right,
  bottom;

  static RobyneSlot? fromName(String? name) {
    if (name == null) {
      return null;
    }
    for (final value in values) {
      if (value.name == name) {
        return value;
      }
    }
    return null;
  }
}

/// Which form factor an arrangement describes.
///
/// This is a *shell shape*, not a platform: a phone in landscape can resolve
/// to either, which is exactly what ADR-001 was written to fix.
enum RobyneFormFactor {
  desktop,
  mobile;

  /// Slots a skin may target in this form factor.
  ///
  /// The phone shell has no side slots: a side rail on a 400dp-wide screen
  /// is the MusicFree failure mode described in `THEME_LAYER_DESIGN.md:17`.
  Set<RobyneSlot> get allowedSlots => switch (this) {
    RobyneFormFactor.desktop => const <RobyneSlot>{
      RobyneSlot.top,
      RobyneSlot.left,
      RobyneSlot.center,
      RobyneSlot.right,
      RobyneSlot.bottom,
    },
    RobyneFormFactor.mobile => const <RobyneSlot>{
      RobyneSlot.top,
      RobyneSlot.center,
      RobyneSlot.bottom,
    },
  };
}

/// One region placed in one slot, at one main-axis ratio.
class RobyneRegionPlacement {
  const RobyneRegionPlacement({
    required this.region,
    required this.slot,
    this.size,
  });

  final RobyneRegion region;
  final RobyneSlot slot;

  /// Main-axis share of the viewport, 0..1. Ignored for [RobyneRegion.content],
  /// which always takes the remaining space.
  final double? size;

  RobyneRegionPlacement copyWith({RobyneSlot? slot, double? size}) {
    return RobyneRegionPlacement(
      region: region,
      slot: slot ?? this.slot,
      size: size ?? this.size,
    );
  }

  String toJson() {
    final size = this.size;
    return '{"region":"${region.name}","slot":"${slot.name}"'
        '${size == null ? '' : ',"size":$size'}}';
  }

  @override
  bool operator ==(Object other) {
    return other is RobyneRegionPlacement &&
        other.region == region &&
        other.slot == slot &&
        other.size == size;
  }

  @override
  int get hashCode => Object.hash(region, slot, size);

  @override
  String toString() => toJson();
}

/// A validated arrangement for one form factor.
///
/// Construction is total: anything illegal in the input is repaired into a
/// usable arrangement rather than thrown. A skin that deletes `content` or
/// invents a slot must degrade to the official baseline, never to a white
/// screen.
class RobyneArrangement {
  const RobyneArrangement({required this.formFactor, required this.placements});

  /// Ratios are clamped into this range (D4). Below the floor a bar is
  /// invisible; above the ceiling it eats the content column.
  static const double minSize = 0.05;
  static const double maxSize = 0.40;

  /// The official desktop arrangement: top bar, side rail, content, a docked
  /// queue and the player bar. Matches `docs/design/UI_DESIGN_SPEC.md` §2.1.
  static const RobyneArrangement desktop = RobyneArrangement(
    formFactor: RobyneFormFactor.desktop,
    placements: <RobyneRegionPlacement>[
      RobyneRegionPlacement(
        region: RobyneRegion.topBar,
        slot: RobyneSlot.top,
        size: 0.06,
      ),
      RobyneRegionPlacement(
        region: RobyneRegion.navBar,
        slot: RobyneSlot.left,
        size: 0.14,
      ),
      RobyneRegionPlacement(
        region: RobyneRegion.content,
        slot: RobyneSlot.center,
      ),
      RobyneRegionPlacement(
        region: RobyneRegion.queue,
        slot: RobyneSlot.right,
        size: 0.24,
      ),
      RobyneRegionPlacement(
        region: RobyneRegion.playerBar,
        slot: RobyneSlot.bottom,
        size: 0.09,
      ),
    ],
  );

  /// The official mobile arrangement: content, player bar above the tab
  /// strip. No top bar, no side slots. Matches design spec §2.2.
  static const RobyneArrangement mobile = RobyneArrangement(
    formFactor: RobyneFormFactor.mobile,
    placements: <RobyneRegionPlacement>[
      RobyneRegionPlacement(
        region: RobyneRegion.content,
        slot: RobyneSlot.center,
      ),
      RobyneRegionPlacement(
        region: RobyneRegion.playerBar,
        slot: RobyneSlot.bottom,
        size: 0.12,
      ),
      RobyneRegionPlacement(
        region: RobyneRegion.navBar,
        slot: RobyneSlot.bottom,
        size: 0.09,
      ),
    ],
  );

  /// The official arrangement for [formFactor].
  static RobyneArrangement official(RobyneFormFactor formFactor) {
    return switch (formFactor) {
      RobyneFormFactor.desktop => desktop,
      RobyneFormFactor.mobile => mobile,
    };
  }

  final RobyneFormFactor formFactor;

  /// Placements in declaration order. Order within a slot is the layout
  /// order, so mobile `bottom` listing `playerBar` then `navBar` means the
  /// player bar sits above the tab strip.
  final List<RobyneRegionPlacement> placements;

  /// Parses `layout.<formFactor>.arrangement`.
  ///
  /// Returns the official baseline when [raw] is absent, and repairs
  /// individual entries when it is partly malformed:
  ///
  /// - an unknown region name or slot drops that entry
  /// - a slot the form factor does not allow drops that entry
  /// - a size outside [minSize]..[maxSize] is clamped, non-numbers become
  ///   the official value for that region
  /// - a missing `content` region falls back to the whole official baseline
  static RobyneArrangement parse(
    Object? raw, {
    required RobyneFormFactor formFactor,
  }) {
    final RobyneArrangement official;
    if (formFactor == RobyneFormFactor.desktop) {
      official = desktop;
    } else {
      official = mobile;
    }
    if (raw is! List) {
      return official;
    }
    final officialSize = <RobyneRegion, double?>{
      for (final placement in official.placements)
        placement.region: placement.size,
    };

    final placements = <RobyneRegionPlacement>[];
    final seen = <RobyneRegion>{};
    for (final entry in raw) {
      if (entry is! Map) {
        continue;
      }
      final region = _regionFromName(entry['region']?.toString());
      final slot = RobyneSlot.fromName(entry['slot']?.toString());
      if (region == null || slot == null) {
        continue;
      }
      if (!formFactor.allowedSlots.contains(slot)) {
        continue;
      }
      if (!seen.add(region)) {
        continue;
      }
      placements.add(
        RobyneRegionPlacement(
          region: region,
          slot: slot,
          size: _size(
            entry['size'],
            fallback: officialSize[region],
            required: region != RobyneRegion.content,
          ),
        ),
      );
    }

    if (!seen.contains(RobyneRegion.content)) {
      // The one rule with no partial credit.
      return official;
    }

    // Any region the skin did not mention keeps its official placement, so a
    // skin that only reorders the nav bar does not accidentally delete the
    // player bar.
    for (final placement in official.placements) {
      if (!seen.contains(placement.region)) {
        placements.add(placement);
      }
    }
    return RobyneArrangement(formFactor: formFactor, placements: placements);
  }

  /// The placement for [region], or null when it is not laid out.
  RobyneRegionPlacement? placementFor(RobyneRegion region) {
    for (final placement in placements) {
      if (placement.region == region) {
        return placement;
      }
    }
    return null;
  }

  Iterable<RobyneRegionPlacement> inSlot(RobyneSlot slot) {
    return placements.where((placement) => placement.slot == slot);
  }

  /// Value equality, because two arrangements parsed from equivalent JSON are
  /// the same arrangement.
  ///
  /// The plan, the settings UI and the D5 identity test all compare these;
  /// without this they would fall back to identity and report a difference
  /// between a skin and its own copy.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is RobyneArrangement &&
        other.formFactor == formFactor &&
        other.placements.length == placements.length &&
        _samePlacements(other.placements);
  }

  bool _samePlacements(List<RobyneRegionPlacement> other) {
    for (var index = 0; index < other.length; index += 1) {
      if (other[index] != placements[index]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(formFactor, Object.hashAll(placements));

  @override
  String toString() =>
      'RobyneArrangement(${formFactor.name}, ${placements.join(', ')})';

  bool get hasNavBarSide {
    final placement = placementFor(RobyneRegion.navBar);
    return placement?.slot == RobyneSlot.left ||
        placement?.slot == RobyneSlot.right;
  }

  static RobyneRegion? _regionFromName(String? name) {
    if (name == null) {
      return null;
    }
    for (final region in RobyneRegion.values) {
      if (region.name == name) {
        return region;
      }
    }
    return null;
  }

  static double? _size(
    Object? value, {
    required double? fallback,
    required bool required,
  }) {
    if (!required) {
      return null;
    }
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    if (parsed == null || !parsed.isFinite) {
      return fallback;
    }
    return parsed.clamp(minSize, maxSize);
  }
}

/// The concrete geometry a shell builds from an arrangement.
///
/// This is where D7 lives: the skin said "nav bar on the left at 15%", and
/// the application decides that the ratio is 15% of *this* window, clamps it
/// to something a human can hit, and drops chrome in a defined order when the
/// budget runs out. Keeping it a pure function makes the degradation rules
/// testable without pumping a widget.
class RobyneShellPlan {
  const RobyneShellPlan._({
    required this.arrangement,
    required this.topExtent,
    required this.bottomExtent,
    required this.leftExtent,
    required this.rightExtent,
    required this.queueSlot,
    required this.queueSideExtent,
    required this.queueOverlaySlot,
    required this.queueOverlay,
    required this.navSlot,
    required this.navIconOnly,
    required this.playerMini,
    required this.topBarVisible,
    required this.playerBarHeight,
    required this.navBarBottomHeight,
    required this.queueOverlayWidth,
    required this.contentWidth,
    required this.contentHeight,
  });

  /// Narrowest content column worth showing. Below it the side regions are
  /// dropped rather than squeezed, because a 120dp content column is not a
  /// usable content column.
  ///
  /// A 400dp phone can never satisfy 320dp plus *any* side rail, which is
  /// correct: the mobile arrangement has no side slots. The floor exists to
  /// protect the desktop shell from a hostile side-rail ratio.
  static const double minContentWidth = 320;

  /// The content floor on every form factor. A 360dp-high landscape phone
  /// still leaves 260dp after its two bottom bars, so the guard does not
  /// fight the mobile arrangement.
  static const double minContentHeight = 200;

  static const double _topBarMin = 40;
  static const double _topBarMax = 64;

  /// The transport row needs a progress slider and a 42dp button row; below
  /// roughly this the bar cannot render its own controls, and a skin asking
  /// for less must be clamped to it rather than given an overflowing bar.
  ///
  /// The number is the bar's own content, not a tasteful guess: the centre
  /// column stacks a 42dp button row over a 20dp progress row (62dp), and the
  /// full transport card is inset from the shell by a 12dp bottom margin
  /// (`fullMargin`), which is the only vertical inset the card loses. A 72dp
  /// floor handed the card 60dp and asked it to draw 62dp, so the bar
  /// overflowed itself by 2dp at a 360dp-tall window.
  static const double _playerBarMin = 74;

  /// The mini bar is a *card plus its margin*, because the design floats the
  /// transport inset from the shell edges. `mobile-portrait.png` is a 56dp
  /// card with an 8dp bottom gap; the landscape board tightens the card to
  /// 48dp, which is the same 8dp gap plus a smaller card.
  static const double _playerBarMini = 56;
  static const double _playerBarMiniShort = 48;
  static const double _playerBarMax = 132;
  static const double _navSideMin = 64;
  static const double _navSideMax = 260;
  static const double _queueMin = 240;
  static const double _queueMax = 420;

  final RobyneArrangement arrangement;

  /// Resolved dp extents. Zero means "this slot is not in use".
  final double topExtent;
  final double bottomExtent;
  final double leftExtent;
  final double rightExtent;

  final RobyneSlot? queueSlot;

  /// The dp width reserved by a docked queue, or zero when it floats.
  final double queueSideExtent;

  /// The side the queue asked for, retained when it degrades to an overlay.
  ///
  /// The panel must open on the same side as its trigger even when it no
  /// longer owns a column; dropping this field made a left-hand queue jump to
  /// the right edge the moment space ran out.
  final RobyneSlot? queueOverlaySlot;

  /// True when the queue must float over the content instead of taking a
  /// column: the desktop degradation step 1 from the design spec.
  final bool queueOverlay;

  final RobyneSlot? navSlot;

  /// True when the nav bar has been reduced to icons (labelMode=none).
  final bool navIconOnly;

  /// True when the player bar has been reduced to a single mini row.
  final bool playerMini;

  final bool topBarVisible;

  /// The dp height of just the [RobyneRegion.playerBar] region.
  ///
  /// [bottomExtent] is the two bottom regions combined; the shell needs them
  /// apart so each can be sized from the plan rather than from a literal.
  final double playerBarHeight;

  /// The dp height of the bottom tab strip, or 0 when the nav sits elsewhere.
  final double navBarBottomHeight;

  /// The dp width of the floating queue panel.
  ///
  /// Only meaningful when [queueOverlay] is true. It is a clamped share of the
  /// viewport, never the full window, so the panel can never hide the page it
  /// floats above.
  final double queueOverlayWidth;

  final double contentWidth;
  final double contentHeight;

  /// Resolves [arrangement] against a concrete viewport.
  ///
  /// Degradation order is fixed (D7): queue -> topBar -> playerBar -> navBar.
  /// `content` is never sacrificed.
  static RobyneShellPlan resolve({
    required RobyneArrangement arrangement,
    required double width,
    required double height,
  }) {
    final safeWidth = math.max(width, 0.0);
    final safeHeight = math.max(height, 0.0);
    final compactHeight = safeHeight < 480;

    final navPlacement = arrangement.placementFor(RobyneRegion.navBar);
    final navSlot = navPlacement?.slot;
    final queuePlacement = arrangement.placementFor(RobyneRegion.queue);
    final topPlacement = arrangement.placementFor(RobyneRegion.topBar);
    final playerPlacement = arrangement.placementFor(RobyneRegion.playerBar);

    final queueSlot = queuePlacement?.slot;
    var queueOverlay = false;

    // Side extents are derived from ratios of the *width*, bars from ratios
    // of the *height*: the main axis of each slot.
    //
    // Each side is measured as "what does this side cost", so a rail and a
    // queue sharing the right edge add up instead of overwriting each other.
    double sideCost(RobyneSlot side) {
      var extent = 0.0;
      if (navSlot == side) {
        extent += _sideExtent(
          navPlacement?.size,
          safeWidth,
          _navSideMin,
          _navSideMax,
        );
      }
      if (!queueOverlay && queueSlot == side) {
        extent += _sideExtent(
          queuePlacement?.size,
          safeWidth,
          _queueMin,
          _queueMax,
        );
      }
      return extent;
    }

    var leftExtent = sideCost(RobyneSlot.left);
    var rightExtent = sideCost(RobyneSlot.right);

    // Step 1: the queue yields first. It is the only region whose content is
    // duplicated by a page, so it is the safest thing to move to an overlay.
    //
    // The test is against the *content column*, not the raw window: a 700dp
    // window carrying a 0.14 rail and a 0.24 queue leaves under 320dp for the
    // page, which is exactly the case this step exists for.
    // Two regions cannot both own the same side without one being squeezed
    // into uselessness. D6 allows the arrangement, so the application makes
    // it survivable: the queue yields to an overlay, because its content is
    // duplicated by the queue page and the nav rail is the only way out.
    final queueSharesNavSide =
        queueSlot != null &&
        (queueSlot == RobyneSlot.left || queueSlot == RobyneSlot.right) &&
        queueSlot == navSlot;
    if (queueSharesNavSide ||
        (queueSlot != null &&
            (queueSlot == RobyneSlot.left || queueSlot == RobyneSlot.right) &&
            safeWidth - leftExtent - rightExtent < minContentWidth)) {
      queueOverlay = true;
      leftExtent = sideCost(RobyneSlot.left);
      rightExtent = sideCost(RobyneSlot.right);
    }

    // A top/bottom queue has no docked representation in the flagship shell.
    // It becomes an overlay rather than silently deleting the region.
    if (queueSlot != null &&
        (queueSlot == RobyneSlot.top || queueSlot == RobyneSlot.bottom)) {
      queueOverlay = true;
      leftExtent = sideCost(RobyneSlot.left);
      rightExtent = sideCost(RobyneSlot.right);
    }

    if (!queueOverlay &&
        queueSlot != null &&
        safeWidth - leftExtent - rightExtent < minContentWidth) {
      queueOverlay = true;
      leftExtent = sideCost(RobyneSlot.left);
      rightExtent = sideCost(RobyneSlot.right);
    }

    // Step 2: the top bar compresses, then disappears entirely. D7 puts
    // topBar second, before the player bar and the nav rail, because losing
    // a search field is less harmful than losing transport or navigation.
    var topExtent = _barExtent(
      topPlacement?.size,
      safeHeight,
      _topBarMin,
      _topBarMax,
    );
    var topBarVisible = topExtent > 0;
    if (compactHeight) {
      topExtent = math.min(topExtent, _topBarMin);
    }

    // Step 3: the player bar degrades to a mini row.
    // The tier is decided first, because a mini bar drops the progress row
    // and so can honour a smaller floor than the full transport row needs.
    // The phone design's transport is a card *without* a progress row
    // (`mobile-portrait.png`: art / title / like / more / play / queue), so a
    // mobile arrangement always gets the mini bar — not only when the height
    // is cramped. Height still tightens it further for a landscape phone.
    var playerMini =
        compactHeight || arrangement.formFactor == RobyneFormFactor.mobile;
    var playerExtent = _barExtent(
      playerPlacement?.size,
      safeHeight,
      _playerBarMin,
      _playerBarMax,
    );
    if (playerMini) {
      playerExtent = math.min(
        playerExtent,
        compactHeight ? _playerBarMiniShort : _playerBarMini,
      );
    }
    final navBottomExtent = navSlot == RobyneSlot.bottom
        ? _barExtent(
            navPlacement?.size,
            safeHeight,
            compactHeight ? 48 : 56,
            compactHeight ? 56 : 80,
          )
        : 0.0;
    var bottomExtent = playerExtent + navBottomExtent;
    final heightFloor = minContentHeight;

    if (safeHeight - topExtent - bottomExtent < heightFloor) {
      playerMini = true;
      playerExtent = math.min(playerExtent, _playerBarMini);
      bottomExtent = playerExtent + navBottomExtent;
    }

    // A genuinely short window gives up the top bar rather than giving up
    // content: this is the second half of D7 step 2.
    if (safeHeight - topExtent - bottomExtent < heightFloor) {
      topBarVisible = false;
      topExtent = 0;
    }

    // Step 4: the nav rail yields last of all, collapsing to icons. It only
    // gives up its labels — the rail itself never disappears, because it is
    // the only way back to every page.
    var navIconOnly = compactHeight;
    if (!navIconOnly &&
        ((leftExtent > 0 &&
                safeWidth - leftExtent - rightExtent < minContentWidth) ||
            (rightExtent > 0 &&
                safeWidth - leftExtent - rightExtent < minContentWidth))) {
      navIconOnly = true;
      if (leftExtent > 0) {
        leftExtent = math.min(leftExtent, _navSideMin + 8);
      }
      if (rightExtent > 0) {
        rightExtent = math.min(rightExtent, _navSideMin + 8);
      }
    }

    // An overlay floats, so it is sized from the queue ratio but capped so a
    // phone screen still shows the page underneath it.
    final overlayCeiling = math.max(
      _queueMin,
      math.min(_queueMax, safeWidth * 0.6),
    );
    final queueOverlayWidth = _sideExtent(
      queuePlacement?.size,
      safeWidth,
      _queueMin,
      _queueMax,
    ).clamp(_queueMin, overlayCeiling).toDouble();
    final queueSideExtent = queueOverlay
        ? 0.0
        : _sideExtent(queuePlacement?.size, safeWidth, _queueMin, _queueMax);

    final contentWidth = math.max(0.0, safeWidth - leftExtent - rightExtent);
    final contentHeight = math.max(0.0, safeHeight - topExtent - bottomExtent);

    return RobyneShellPlan._(
      arrangement: arrangement,
      topExtent: topExtent,
      bottomExtent: bottomExtent,
      leftExtent: leftExtent,
      rightExtent: rightExtent,
      queueSlot: queueSlot,
      queueSideExtent: queueSideExtent,
      queueOverlaySlot: queuePlacement?.slot,
      queueOverlay: queueOverlay,
      navSlot: navSlot,
      navIconOnly: navIconOnly,
      playerMini: playerMini,
      topBarVisible: topBarVisible,
      playerBarHeight: playerExtent,
      navBarBottomHeight: navBottomExtent,
      queueOverlayWidth: queueOverlayWidth,
      contentWidth: contentWidth,
      contentHeight: contentHeight,
    );
  }

  /// Ratio -> dp for a vertical slot (top/bottom bars).
  static double _barExtent(double? ratio, double axis, double min, double max) {
    if (ratio == null) {
      return 0;
    }
    return (ratio * axis).clamp(min, max);
  }

  /// Ratio -> dp for a horizontal slot (side rails and the queue).
  static double _sideExtent(
    double? ratio,
    double axis,
    double min,
    double max,
  ) {
    if (ratio == null) {
      return 0;
    }
    return (ratio * axis).clamp(min, max);
  }
}
