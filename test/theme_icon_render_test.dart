import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/app/router.dart';
import 'package:robyne/core/theme/application/theme_providers.dart';
import 'package:robyne/core/theme/domain/theme_icons.dart';
import 'package:robyne/features/player/presentation/player_bar.dart';

import 'support/xuan_fixture.dart';

/// The code points drawn anywhere inside [subtree].
///
/// A declared glyph is no longer an `Icon`: `ThemeIconView` renders it as
/// text, because building an `IconData` from a runtime code point stops the
/// release build's icon tree-shaker from running at all. Both renderers end up
/// as a `RenderParagraph` holding one character, so reading the glyph out of
/// the render tree is the assertion that survives either implementation — and
/// it is what the user actually sees.
Set<int> drawnCodePoints(WidgetTester tester, Finder subtree) {
  final found = <int>{};
  for (final element in subtree.evaluate()) {
    void walk(RenderObject? object) {
      if (object == null) {
        return;
      }
      if (object is RenderParagraph) {
        final text = object.text.toPlainText();
        if (text.isNotEmpty) {
          found.add(text.codeUnitAt(0));
        }
      }
      object.visitChildren(walk);
    }

    walk(element.renderObject);
  }
  return found;
}

/// The glyphs the rail draws.
Set<int> railGlyphs(WidgetTester tester) {
  return drawnCodePoints(tester, find.byKey(const Key('shell-nav-left')));
}

/// The rail paragraph drawing [codePoint].
RenderParagraph paragraphFor(WidgetTester tester, int codePoint) {
  for (final element in find.byKey(const Key('shell-nav-left')).evaluate()) {
    final hit = _firstParagraph(element.renderObject, codePoint);
    if (hit != null) {
      return hit;
    }
  }
  throw StateError('no glyph U+${codePoint.toRadixString(16)} in the rail');
}

/// The first [RenderParagraph] at or below [object] drawing [codePoint].
RenderParagraph? _firstParagraph(RenderObject? object, int codePoint) {
  if (object == null) {
    return null;
  }
  if (object is RenderParagraph) {
    final text = object.text.toPlainText();
    if (text.isNotEmpty && text.codeUnitAt(0) == codePoint) {
      return object;
    }
  }
  RenderParagraph? hit;
  object.visitChildren((child) {
    hit ??= _firstParagraph(child, codePoint);
  });
  return hit;
}

/// A declared icon must actually reach the screen, and an unusable one must
/// fall back rather than leave a hole where a control was.
///
/// These drive the real shell so the whole path is exercised: manifest ->
/// parser -> provider -> `ThemeIconView` -> the rail's own widget tree.
void main() {
  Future<void> pumpWith(WidgetTester tester, ThemeIcons icons) async {
    tester.view.physicalSize =
        const Size(1280, 900) * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    final skinned = xuanFixture().copyWith(icons: icons);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Object>[
          baseThemePackageProvider.overrideWithValue(skinned),
        ].cast(),
        child: const MaterialApp(home: RobyneShell()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('a skin can redraw a rail glyph', (tester) async {
    await pumpWith(
      tester,
      ThemeIcons.parse(<String, Object?>{'discover': 0xE037}),
    );

    // The rail renders the declared code point instead of Material's
    // `explore_outlined`.
    final glyphs = railGlyphs(tester);
    expect(glyphs, isNotEmpty);
    expect(glyphs, contains(0xE037));
    expect(tester.takeException(), isNull);
  });

  testWidgets('an unusable declaration keeps the built-in glyph', (
    tester,
  ) async {
    // The fallback is the point of the design: a skin may restyle a glyph but
    // must never be able to remove the control it labels.
    await pumpWith(
      tester,
      ThemeIcons.parse(<String, Object?>{'discover': 'not-a-number'}),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('shell-nav-left')), findsOneWidget);
    final glyphs = railGlyphs(tester);
    expect(glyphs, isNotEmpty, reason: 'the built-in glyph still draws');
    expect(glyphs, isNot(contains(0xE037)));
  });

  testWidgets('the selected rail row draws the active glyph', (tester) async {
    // Discover is the initial tab, so its rail row is the selected one. A skin
    // declaring an active twin must have it used exactly there: that is the
    // whole point of the variant.
    await pumpWith(
      tester,
      ThemeIcons.parse(<String, Object?>{
        'discover': <String, Object?>{
          'codePoint': 0xE900,
          'activeCodePoint': 0xE901,
        },
      }),
    );

    final glyphs = railGlyphs(tester);
    expect(
      glyphs,
      contains(0xE901),
      reason: 'the selected row draws activeCodePoint',
    );
    expect(
      glyphs,
      isNot(contains(0xE900)),
      reason: 'a selected row must not draw the inactive glyph',
    );
  });

  testWidgets('an unselected rail row draws the normal glyph', (tester) async {
    // The other half of the same contract: the twin applies only where the
    // surface says the entry is active.
    await pumpWith(
      tester,
      ThemeIcons.parse(<String, Object?>{
        'library': <String, Object?>{
          'codePoint': 0xE910,
          'activeCodePoint': 0xE911,
        },
      }),
    );

    final glyphs = railGlyphs(tester);
    expect(
      glyphs,
      contains(0xE910),
      reason: 'the unselected row draws the normal glyph',
    );
    expect(
      glyphs,
      isNot(contains(0xE911)),
      reason: 'active artwork must not leak onto unselected rows',
    );
  });

  testWidgets('every declared slot reaches a real surface', (tester) async {
    // A slot that no widget ever asks for is a lie in the documentation: the
    // skin declares it, sees no change, and cannot tell why. This renders the
    // shell with *every* slot declared to a distinct code point and counts how
    // many of them actually reach a glyph.
    await pumpWith(
      tester,
      ThemeIcons.parse(<String, Object?>{
        for (final slot in ThemeIconKey.values)
          slot.jsonName: <String, Object?>{'codePoint': 0xE000 + slot.index},
      }),
    );

    final drawn = <int>{
      ...railGlyphs(tester),
      ...drawnCodePoints(tester, find.byType(PlayerBar)),
    };
    final declared = <int>{
      for (final slot in ThemeIconKey.values) 0xE000 + slot.index,
    };

    // The rail and the transport row together query most of the set; the few
    // that do not (a desktop-only toggle on a 1280 window is fine) must not
    // dominate. Asserting a majority keeps this from passing on a stub.
    final reached = drawn.intersection(declared).length;
    expect(
      reached,
      // 14 is the whole set minus the ones that cannot appear on this one
      // render: `more` is the phone-only overflow entry, `back` only exists
      // inside the search/plugin browser, and play/pause never show together.
      greaterThanOrEqualTo(14),
      reason:
          'the desktop shell should query nearly every slot; '
          'saw $reached of ${declared.length}',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a declared glyph draws at the declared size', (tester) async {
    // The glyph renderer is hand-rolled rather than `Icon`, so its layout is
    // ours to get right: a declared size must size the glyph, or a 26dp one
    // silently renders at the default and breaks the row it sits in.
    await pumpWith(
      tester,
      ThemeIcons.parse(<String, Object?>{
        'discover': <String, Object?>{'codePoint': 0xE037, 'size': 26},
      }),
    );

    expect(railGlyphs(tester), contains(0xE037));
    expect(
      paragraphFor(tester, 0xE037).text.style?.fontSize,
      26,
      reason: 'a declared size sizes the glyph',
    );
  });

  testWidgets('a declared glyph follows the declared font family', (
    tester,
  ) async {
    // `fontFamily` is how a skin points a code point at a font that is not
    // Material's. Dropping it would draw the wrong shape out of the wrong
    // face — silently, and only in release.
    await pumpWith(
      tester,
      ThemeIcons.parse(<String, Object?>{
        'discover': <String, Object?>{
          'codePoint': 0xE050,
          'fontFamily': 'SegoeIcons',
        },
      }),
    );

    expect(
      paragraphFor(tester, 0xE050).text.style?.fontFamily,
      'SegoeIcons',
      reason: 'a declared family selects the face',
    );
  });

  testWidgets('a declared glyph takes the declared colour', (tester) async {
    // Colour is the one part of a glyph the surrounding surface cannot supply
    // for a skin: a brand tint on one slot has to survive to the paint.
    await pumpWith(
      tester,
      ThemeIcons.parse(<String, Object?>{
        'discover': <String, Object?>{
          'codePoint': 0xE037,
          'color': '#FFFF6B3D',
        },
      }),
    );

    expect(
      paragraphFor(tester, 0xE037).text.style?.color,
      const Color(0xFFFF6B3D),
      reason: 'a declared colour paints the glyph',
    );
  });
}
