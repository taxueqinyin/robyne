import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/theme/domain/theme_regions.dart';

void main() {
  group('RobyneArrangement.parse', () {
    test('a missing arrangement yields the official baseline', () {
      final desktop = RobyneArrangement.parse(
        null,
        formFactor: RobyneFormFactor.desktop,
      );
      expect(desktop, RobyneArrangement.desktop);

      final mobile = RobyneArrangement.parse(
        null,
        formFactor: RobyneFormFactor.mobile,
      );
      expect(mobile, RobyneArrangement.mobile);
    });

    test('every official arrangement contains content', () {
      for (final formFactor in RobyneFormFactor.values) {
        final arrangement = RobyneArrangement.official(formFactor);
        expect(
          arrangement.placementFor(RobyneRegion.content),
          isNotNull,
          reason: '$formFactor must lay out content',
        );
      }
    });

    test('a non-list arrangement yields the official baseline', () {
      final arrangement = RobyneArrangement.parse(
        'nonsense',
        formFactor: RobyneFormFactor.desktop,
      );
      expect(arrangement, RobyneArrangement.desktop);
    });

    test('dropping content falls back to the whole official baseline', () {
      // This is the one rule with no partial credit: an arrangement without a
      // content region cannot be repaired piecemeal, because the app would
      // have nowhere to put a page.
      final arrangement = RobyneArrangement.parse(<Object?>[
        <String, Object?>{'region': 'navBar', 'slot': 'left', 'size': 0.2},
        <String, Object?>{'region': 'playerBar', 'slot': 'bottom', 'size': 0.1},
      ], formFactor: RobyneFormFactor.desktop);

      expect(arrangement, RobyneArrangement.desktop);
    });

    test('unknown region and slot names drop only their own entry', () {
      final arrangement = RobyneArrangement.parse(<Object?>[
        <String, Object?>{'region': 'content', 'slot': 'center'},
        <String, Object?>{'region': 'banner', 'slot': 'top', 'size': 0.1},
        <String, Object?>{'region': 'navBar', 'slot': 'diagonal', 'size': 0.2},
        <String, Object?>{'region': 'playerBar', 'slot': 'bottom', 'size': 0.1},
      ], formFactor: RobyneFormFactor.desktop);

      // The region set is closed (D2): a skin cannot invent one, and the
      // recommendation banner is a `content.style`, not a region.
      // Four declared-and-valid regions (content, playerBar) plus the two the
      // skin omitted (topBar, queue) and the repaired navBar: five total.
      expect(arrangement.placements, hasLength(5));
      expect(
        arrangement.placements.map((placement) => placement.region.name),
        isNot(contains('banner')),
      );
      // The malformed navBar entry is dropped, so it inherits the official
      // left placement rather than vanishing.
      final nav = arrangement.placementFor(RobyneRegion.navBar);
      expect(nav, isNotNull);
      expect(nav!.slot, RobyneSlot.left);
      expect(arrangement.placementFor(RobyneRegion.content), isNotNull);
    });

    test('a phone cannot be given a side rail', () {
      // The MusicFree failure mode: a skin written for a desktop is dropped
      // onto a phone, where a side rail would eat the whole screen.
      final arrangement = RobyneArrangement.parse(<Object?>[
        <String, Object?>{'region': 'content', 'slot': 'center'},
        <String, Object?>{'region': 'navBar', 'slot': 'left', 'size': 0.2},
      ], formFactor: RobyneFormFactor.mobile);

      final nav = arrangement.placementFor(RobyneRegion.navBar);
      expect(nav!.slot, isNot(RobyneSlot.left));
      expect(RobyneFormFactor.mobile.allowedSlots.contains(nav.slot), isTrue);
    });

    test('sizes are clamped into the 0.05..0.40 corridor', () {
      final arrangement = RobyneArrangement.parse(<Object?>[
        <String, Object?>{'region': 'topBar', 'slot': 'top', 'size': 0.9},
        <String, Object?>{'region': 'content', 'slot': 'center'},
        <String, Object?>{'region': 'navBar', 'slot': 'left', 'size': 0.001},
      ], formFactor: RobyneFormFactor.desktop);

      expect(
        arrangement.placementFor(RobyneRegion.topBar)!.size,
        RobyneArrangement.maxSize,
      );
      expect(
        arrangement.placementFor(RobyneRegion.navBar)!.size,
        RobyneArrangement.minSize,
      );
    });

    test('a non-numeric size falls back to the official value', () {
      final arrangement = RobyneArrangement.parse(<Object?>[
        <String, Object?>{'region': 'content', 'slot': 'center'},
        <String, Object?>{'region': 'navBar', 'slot': 'left', 'size': 'wide'},
      ], formFactor: RobyneFormFactor.desktop);

      expect(
        arrangement.placementFor(RobyneRegion.navBar)!.size,
        RobyneArrangement.desktop.placementFor(RobyneRegion.navBar)!.size,
      );
    });

    test('a skin that reorders one region keeps the rest', () {
      // "Only write the form factor you want to change" is a promise in
      // THEME_AUTHORING.md; this is the other half of it: writing one region
      // must not silently delete the others.
      final arrangement = RobyneArrangement.parse(<Object?>[
        <String, Object?>{'region': 'content', 'slot': 'center'},
        <String, Object?>{'region': 'navBar', 'slot': 'right', 'size': 0.2},
      ], formFactor: RobyneFormFactor.desktop);

      expect(
        arrangement.placementFor(RobyneRegion.navBar)!.slot,
        RobyneSlot.right,
      );
      expect(arrangement.placementFor(RobyneRegion.playerBar), isNotNull);
      expect(arrangement.placementFor(RobyneRegion.topBar), isNotNull);
      expect(arrangement.placementFor(RobyneRegion.queue), isNotNull);
    });

    test('duplicate regions keep the first declaration', () {
      final arrangement = RobyneArrangement.parse(<Object?>[
        <String, Object?>{'region': 'content', 'slot': 'center'},
        <String, Object?>{'region': 'navBar', 'slot': 'left', 'size': 0.2},
        <String, Object?>{'region': 'navBar', 'slot': 'right', 'size': 0.3},
      ], formFactor: RobyneFormFactor.desktop);

      expect(
        arrangement.placementFor(RobyneRegion.navBar)!.slot,
        RobyneSlot.left,
      );
      expect(
        arrangement.placements.where(
          (placement) => placement.region == RobyneRegion.navBar,
        ),
        hasLength(1),
      );
    });

    test('order within a slot is the layout order', () {
      final mobile = RobyneArrangement.mobile;
      final bottom = mobile.inSlot(RobyneSlot.bottom).toList();

      // The player bar must sit above the tab strip, not below it.
      expect(bottom.first.region, RobyneRegion.playerBar);
      expect(bottom.last.region, RobyneRegion.navBar);
    });
  });

  group('RobyneShellPlan.resolve', () {
    test('content is never smaller than the floor on a desktop', () {
      final plan = RobyneShellPlan.resolve(
        arrangement: RobyneArrangement.desktop,
        width: 1280,
        height: 900,
      );
      expect(plan.contentWidth, greaterThanOrEqualTo(320));
      expect(plan.contentHeight, greaterThanOrEqualTo(200));
      expect(plan.queueOverlay, isFalse);
    });

    test('the queue yields to an overlay before content is starved', () {
      // Spec §2.3 step 1: on a narrow desktop the queue floats instead of
      // stealing a column.
      //
      // At 700dp the rail (98) plus the queue (240) still leaves 362dp of
      // content, so the queue legitimately keeps its column; starvation only
      // sets in once the two side regions together would push the content
      // column under the 320dp floor.
      final roomy = RobyneShellPlan.resolve(
        arrangement: RobyneArrangement.desktop,
        width: 700,
        height: 800,
      );
      expect(roomy.queueOverlay, isFalse);
      expect(roomy.contentWidth, greaterThanOrEqualTo(320));

      final plan = RobyneShellPlan.resolve(
        arrangement: RobyneArrangement.desktop,
        width: 420,
        height: 800,
      );
      expect(plan.queueOverlay, isTrue);
      expect(plan.contentWidth, greaterThanOrEqualTo(320));
    });

    test('a landscape phone degrades the bars and keeps content', () {
      // 800x360 is the size class ADR-001 records as the historical
      // breakage; it is compact-height but medium-width.
      final plan = RobyneShellPlan.resolve(
        arrangement: RobyneArrangement.mobile,
        width: 800,
        height: 360,
      );
      expect(plan.playerMini, isTrue);
      expect(plan.contentHeight, greaterThan(0));
      expect(plan.contentWidth, greaterThan(0));
      expect(plan.navSlot, RobyneSlot.bottom);
      expect(plan.navBarBottomHeight, greaterThan(0));
      expect(plan.contentHeight + plan.topExtent + plan.bottomExtent, 360);
    });

    test('a very short window drops the top bar rather than content', () {
      final plan = RobyneShellPlan.resolve(
        arrangement: RobyneArrangement.desktop,
        width: 900,
        height: 300,
      );
      expect(plan.contentHeight, greaterThan(0));
      expect(plan.contentHeight + plan.topExtent + plan.bottomExtent, 300);
    });

    test('degradation order is queue, top bar, player, then nav rail', () {
      // A desktop-only arrangement replayed on a phone viewport: the skin
      // asked for side rails, the queue yields first, then the top bar, then
      // the player compresses, and only then does the rail iconify.
      final plan = RobyneShellPlan.resolve(
        arrangement: RobyneArrangement.desktop,
        width: 620,
        height: 640,
      );
      expect(plan.queueOverlay, isTrue);
      expect(plan.navSlot, RobyneSlot.left);
      expect(plan.leftExtent, lessThanOrEqualTo(620));
      expect(plan.contentWidth, greaterThan(0));
    });

    test('a short desktop keeps the player and nav before chrome', () {
      // Height is the scarce axis here. D7 says the top bar goes before the
      // player or navigation, and the player compresses before the rail does.
      final plan = RobyneShellPlan.resolve(
        arrangement: RobyneArrangement.desktop,
        width: 1280,
        height: 220,
      );
      expect(plan.topBarVisible, isFalse);
      expect(plan.playerBarHeight, greaterThan(0));
      expect(plan.playerMini, isTrue);
      expect(plan.navSlot, RobyneSlot.left);
      expect(plan.navIconOnly, isTrue);
      expect(plan.contentHeight, greaterThan(0));
    });

    test('a docked queue shares a hostile ratio without starving content', () {
      final arrangement = RobyneArrangement.parse(<Object?>[
        <String, Object?>{'region': 'content', 'slot': 'center'},
        <String, Object?>{'region': 'navBar', 'slot': 'left', 'size': 0.05},
        <String, Object?>{'region': 'queue', 'slot': 'right', 'size': 0.40},
      ], formFactor: RobyneFormFactor.desktop);
      final plan = RobyneShellPlan.resolve(
        arrangement: arrangement,
        width: 1280,
        height: 900,
      );
      expect(plan.contentWidth, greaterThanOrEqualTo(320));
      expect(plan.queueSideExtent, greaterThan(0));
      expect(plan.leftExtent + plan.rightExtent + plan.contentWidth, 1280);
    });

    test('a zero or negative viewport does not produce negative extents', () {
      final plan = RobyneShellPlan.resolve(
        arrangement: RobyneArrangement.desktop,
        width: -100,
        height: -100,
      );
      expect(plan.contentWidth, greaterThanOrEqualTo(0));
      expect(plan.contentHeight, greaterThanOrEqualTo(0));
      expect(plan.topExtent, greaterThanOrEqualTo(0));
      expect(plan.bottomExtent, greaterThanOrEqualTo(0));
    });

    test('the nav bar reflects its declared slot', () {
      final mirrored = RobyneArrangement.parse(<Object?>[
        <String, Object?>{'region': 'content', 'slot': 'center'},
        <String, Object?>{'region': 'navBar', 'slot': 'right', 'size': 0.18},
      ], formFactor: RobyneFormFactor.desktop);

      final plan = RobyneShellPlan.resolve(
        arrangement: mirrored,
        width: 1280,
        height: 900,
      );
      expect(plan.navSlot, RobyneSlot.right);
      expect(plan.rightExtent, greaterThan(0));
      expect(plan.leftExtent, 0);
    });
  });
}
