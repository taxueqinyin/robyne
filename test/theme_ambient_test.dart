import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/theme/application/theme_providers.dart';
import 'package:robyne/core/theme/domain/theme_components.dart';
import 'package:robyne/core/theme/domain/theme_layout.dart';
import 'package:robyne/core/theme/domain/theme_package.dart';
import 'package:robyne/core/theme/domain/theme_tokens.dart';
import 'package:robyne/core/theme/infrastructure/theme_manifest_parser.dart';
import 'package:robyne/core/theme/infrastructure/token_resolver.dart';
import 'package:robyne/features/library/application/library_providers.dart';
import 'package:robyne/features/library/presentation/library_page.dart';
import 'package:robyne/features/player/domain/playback_item.dart';

/// Two component groups that used to be parsed, exported and round-tripped by
/// tests while no widget read them: a skin could declare a motion rhythm or an
/// atmosphere and see nothing change. These lock down that they are real.
void main() {
  group('ambient (design spec §3.4 封面驱动氛围)', () {
    test('is off by default, so every pre-existing skin is unchanged', () {
      const ambient = ThemeAmbientComponents.baseline();

      expect(ambient.enabled, isFalse);
      expect(ambient.isVisible, isFalse);
    });

    test('the flagship declares the documented strength and reach', () {
      final package = _parse(<String, Object?>{
        'tokens': <String, Object?>{
          'components': <String, Object?>{
            'ambient': <String, Object?>{
              'enabled': true,
              'strength': 0.28,
              'heightFraction': 0.32,
            },
          },
        },
      });

      final ambient = package.tokens.components.ambient;
      expect(ambient.isVisible, isTrue);
      // §3.4 asks for 20%–35% opacity over the top 25%–35% of content.
      expect(ambient.strength, inInclusiveRange(0.20, 0.35));
      expect(ambient.heightFraction, inInclusiveRange(0.25, 0.35));
    });

    test('a strength that would swallow the text is clamped', () {
      // The atmosphere layer must not decide readability, so the parser caps
      // it rather than trusting the manifest.
      final package = _parse(<String, Object?>{
        'tokens': <String, Object?>{
          'components': <String, Object?>{
            'ambient': <String, Object?>{'enabled': true, 'strength': 9},
          },
        },
      });

      expect(
        package.tokens.components.ambient.strength,
        lessThanOrEqualTo(0.6),
      );
    });

    test('a partial group keeps every field the skin omitted', () {
      final package = _parse(<String, Object?>{
        'tokens': <String, Object?>{
          'components': <String, Object?>{
            'ambient': <String, Object?>{'enabled': true},
          },
        },
      });

      final ambient = package.tokens.components.ambient;
      expect(ambient.enabled, isTrue);
      expect(ambient.strength, 0.28);
      expect(ambient.blur, 48);
    });

    test('zero strength renders nothing even when enabled', () {
      final ambient = const ThemeAmbientComponents.baseline().copyWith(
        enabled: true,
        strength: 0,
      );

      expect(ambient.isVisible, isFalse);
    });
  });

  group('motion', () {
    test('a curve converts to a real Flutter curve', () {
      // The domain layer publishes control points to stay widget-free; this
      // is the one place they become animatable.
      for (final curve in ThemeMotionCurve.values) {
        final resolved = curve.toCurve;
        expect(resolved.transform(0), 0);
        expect(resolved.transform(1), 1);
      }
    });

    test('a skin can declare a slower rhythm', () {
      final package = _parse(<String, Object?>{
        'tokens': <String, Object?>{
          'components': <String, Object?>{
            'motion': <String, Object?>{
              'mediumDurationMs': 900,
              'curve': 'decelerate',
            },
          },
        },
      });

      final motion = package.tokens.components.motion;
      expect(motion.medium, const Duration(milliseconds: 900));
      expect(motion.curve, ThemeMotionCurve.decelerate);
    });
  });

  group('typography roles (design spec §3.3)', () {
    test('the five design roles resolve to the drawn sizes', () {
      // Before role sizes existed, a skin could only scale *everything* at
      // once. Choosing a voice — big titles, tight labels — was impossible.
      const type = ThemeTypography.baseline();

      expect(type.resolvedPageTitleSize, 24);
      expect(type.resolvedSectionTitleSize, 18);
      expect(type.resolvedListPrimarySize, 15);
      expect(type.resolvedListSecondarySize, 13);
      expect(type.resolvedLabelSize, 11);
      expect(type.resolvedLabelWeight, 500);
    });

    test('a skin can restate one role without touching the other four', () {
      final package = _parse(<String, Object?>{
        'tokens': <String, Object?>{
          'typography': <String, Object?>{'pageTitleSize': 32},
        },
      });

      final type = package.tokens.typography;
      expect(type.resolvedPageTitleSize, 32);
      // The rest keep their defaults rather than collapsing to zero.
      expect(type.resolvedSectionTitleSize, 18);
      expect(type.resolvedListPrimarySize, 15);
      expect(type.resolvedLabelWeight, 500);
    });

    test('unreadable and absurd sizes are clamped', () {
      final package = _parse(<String, Object?>{
        'tokens': <String, Object?>{
          'typography': <String, Object?>{'pageTitleSize': 400, 'labelSize': 1},
        },
      });

      final type = package.tokens.typography;
      expect(type.resolvedPageTitleSize, lessThanOrEqualTo(96));
      expect(type.resolvedLabelSize, greaterThanOrEqualTo(8));
    });

    test('the global scale still multiplies a role size', () {
      // The role is the skin's intent; `scale` stays the user-facing knob, so
      // the two compose rather than one silently replacing the other.
      final package = _parse(<String, Object?>{
        'tokens': <String, Object?>{
          'typography': <String, Object?>{'pageTitleSize': 24, 'scale': 1.25},
        },
      });

      final theme = const TokenResolver().resolve(
        package.tokens,
        Brightness.dark,
        ThemeModePreference.dark,
      );

      expect(theme.textTheme.headlineMedium?.fontSize, 30);
    });
  });

  group('content metrics (design spec §3.2)', () {
    test('defaults match the numbers the design sheets draw', () {
      const metrics = ThemeContentMetrics.baseline();

      expect(metrics.gutter, 28);
      expect(metrics.gutterCompact, 16);
      expect(metrics.rowHeight, 56);
      expect(metrics.rowHeightCompact, 48);
      expect(metrics.cardMinWidth, 180);
      expect(metrics.cardGap, 16);
    });

    test('a skin can tighten the row rhythm', () {
      // "把行距收紧一点" used to be a code change; it is now a manifest edit.
      final package = _parse(<String, Object?>{
        'tokens': <String, Object?>{
          'components': <String, Object?>{
            'content': <String, Object?>{'rowHeight': 44, 'gutter': 20},
          },
        },
      });

      final metrics = package.tokens.components.content;
      expect(metrics.rowHeight, 44);
      expect(metrics.gutter, 20);
      // Unmentioned values keep their defaults.
      expect(metrics.rowHeightCompact, 48);
      expect(metrics.cardGap, 16);
    });

    test('per-shape helpers pick the right value', () {
      const metrics = ThemeContentMetrics.baseline();

      expect(metrics.gutterFor(compact: true), 16);
      expect(metrics.gutterFor(compact: false), 28);
      expect(metrics.rowHeightFor(compact: true), 48);
      expect(metrics.rowHeightFor(compact: false), 56);
      expect(metrics.cardMinWidthFor(compact: true), 140);
      expect(metrics.cardGapFor(compact: true), 12);
    });

    test('untappable and absurd geometry is clamped', () {
      final package = _parse(<String, Object?>{
        'tokens': <String, Object?>{
          'components': <String, Object?>{
            'content': <String, Object?>{
              'rowHeight': 1,
              'gutter': 5000,
              'cardGap': -20,
            },
          },
        },
      });

      final metrics = package.tokens.components.content;
      expect(metrics.rowHeight, greaterThanOrEqualTo(32));
      expect(metrics.gutter, lessThanOrEqualTo(96));
      expect(metrics.cardGap, greaterThanOrEqualTo(0));
    });

    test('density is a factor on the declared row height', () {
      // Both used to be inert for the same reason: nothing read them. They
      // compose rather than compete — the skin sets the base height, density
      // says tighter or airier than that base.
      expect(ThemeDensity.compact.rowScale, lessThan(1));
      expect(ThemeDensity.regular.rowScale, 1);
      expect(ThemeDensity.comfortable.rowScale, greaterThan(1));

      final package = _parse(<String, Object?>{
        'layout': <String, Object?>{
          'content': <String, Object?>{
            'density': 'comfortable',
            'listStyle': 'list',
          },
        },
      });

      final density = package.layout.content.density;
      final metrics = package.tokens.components.content;
      expect(
        metrics.rowHeightFor(compact: false) * density.rowScale,
        greaterThan(metrics.rowHeight),
      );
    });

    test('chrome proportions are declarable too', () {
      // The rail's icon, brand mark and avatar were literals; a skin could
      // recolour them and not resize them.
      final package = _parse(<String, Object?>{
        'tokens': <String, Object?>{
          'components': <String, Object?>{
            'content': <String, Object?>{
              'navIconSize': 26,
              'logoSize': 32,
              'avatarSize': 44,
            },
          },
        },
      });

      final metrics = package.tokens.components.content;
      expect(metrics.navIconSize, 26);
      expect(metrics.logoSize, 32);
      expect(metrics.avatarSize, 44);
    });

    test('chrome proportions are clamped to sane ranges', () {
      final package = _parse(<String, Object?>{
        'tokens': <String, Object?>{
          'components': <String, Object?>{
            'content': <String, Object?>{'navIconSize': 999, 'logoSize': 1},
          },
        },
      });

      final metrics = package.tokens.components.content;
      expect(metrics.navIconSize, lessThanOrEqualTo(40));
      expect(metrics.logoSize, greaterThanOrEqualTo(12));
    });

    testWidgets('a declared gutter actually moves the content', (tester) async {
      // The whole point of the token: without this the numbers are inert and
      // "make the gutter wider" stays a code change.
      tester.view.physicalSize =
          const Size(900, 700) * tester.view.devicePixelRatio;
      addTearDown(tester.view.resetPhysicalSize);

      Future<double> leftOfTitle(double gutter) async {
        final package = _parse(<String, Object?>{
          'tokens': <String, Object?>{
            'components': <String, Object?>{
              'content': <String, Object?>{'gutter': gutter},
            },
          },
        });
        await tester.pumpWidget(
          ProviderScope(
            overrides: <Object>[
              baseThemePackageProvider.overrideWithValue(package),
              localMusicLibraryProvider.overrideWith(
                () => _SeededLibrary(<PlaybackItem>[
                  PlaybackItem.plugin(
                    platform: 'Library',
                    musicId: 'a',
                    title: 'Track A',
                    raw: const <String, Object?>{'id': 'a'},
                  ),
                ]),
              ),
            ].cast(),
            child: const MaterialApp(home: Scaffold(body: LibraryPage())),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        // The demo package declares no strings, so the title is the neutral
        // default rather than 《玄》's Chinese label.
        return tester.getTopLeft(find.text('Library').first).dx;
      }

      final narrow = await leftOfTitle(12);
      final wide = await leftOfTitle(64);
      expect(
        wide,
        greaterThan(narrow),
        reason: 'a larger gutter must push the title inward',
      );
    });
  });

  group('content style per surface (design spec §2.5)', () {
    test('the design table maps styles per destination, not globally', () {
      // §2.5 gives `list` for 本地库 and `grid` for 发现页. One global value
      // cannot say both, which is what made 《玄》 declare `banner` everywhere
      // and render its library as a shelf of oversized covers.
      final package = _parse(<String, Object?>{
        'layout': <String, Object?>{
          'content': <String, Object?>{
            'listStyle': 'list',
            'styles': <String, Object?>{
              'library': 'list',
              'discover': 'grid',
              'playlists': 'card',
            },
          },
        },
      });

      final content = package.layout.content;
      expect(
        content.styleFor(ThemeContentSurface.library),
        ThemeListStyle.list,
      );
      expect(
        content.styleFor(ThemeContentSurface.discover),
        ThemeListStyle.grid,
      );
      expect(
        content.styleFor(ThemeContentSurface.playlists),
        ThemeListStyle.card,
      );
      // An undeclared destination inherits the global value.
      expect(content.styleFor(ThemeContentSurface.search), ThemeListStyle.list);
    });

    test('unknown destinations and values are dropped, not coerced', () {
      // `ThemeListStyle.fromName` falls back to `list`, so a typo routed
      // through it would become a real override. The parser checks the enum
      // instead.
      final package = _parse(<String, Object?>{
        'layout': <String, Object?>{
          'content': <String, Object?>{
            'listStyle': 'grid',
            'styles': <String, Object?>{
              'invented': 'banner',
              'library': 'not-a-style',
            },
          },
        },
      });

      final content = package.layout.content;
      expect(content.styles, isEmpty);
      // The global value still applies to everything.
      expect(
        content.styleFor(ThemeContentSurface.library),
        ThemeListStyle.grid,
      );
    });

    test('《玄》 declares the styles the design sheets draw', () {
      final decoded =
          jsonDecode(File('assets/themes/xuan/theme.json').readAsStringSync())
              as Map<String, Object?>;
      final package = const ThemeManifestParser().tryParse(
        decoded,
        source: ThemeSource.builtIn,
      )!;

      final content = package.layout.content;
      expect(
        content.styleFor(ThemeContentSurface.library),
        ThemeListStyle.list,
        reason: '§2.5 puts 本地库 on the row list',
      );
      expect(
        content.styleFor(ThemeContentSurface.discover),
        ThemeListStyle.grid,
        reason: '§2.5 puts 发现页 on the grid',
      );
    });
  });

  group('content.style has no dead values', () {
    // `banner` was declared in the enum, documented in the design spec
    // (§2.5 "推荐横幅") and accepted by the parser, but no widget branch ever
    // handled it — a skin asking for a banner silently got rows. This walks
    // every declared value past the pages that honour them.
    for (final style in ThemeListStyle.values) {
      testWidgets('$style renders the library without throwing', (
        tester,
      ) async {
        tester.view.physicalSize =
            const Size(900, 700) * tester.view.devicePixelRatio;
        addTearDown(tester.view.resetPhysicalSize);

        final package = _parse(<String, Object?>{
          'layout': <String, Object?>{
            'content': <String, Object?>{'listStyle': style.name},
          },
        });
        expect(
          package.layout.content.listStyle,
          style,
          reason: '${style.name} must survive the parser',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: <Object>[
              baseThemePackageProvider.overrideWithValue(package),
              // An empty library renders the empty state, which would make
              // this test pass for any style — including one with no branch.
              localMusicLibraryProvider.overrideWith(
                () => _SeededLibrary(<PlaybackItem>[
                  PlaybackItem.plugin(
                    platform: 'Library',
                    musicId: 'a',
                    title: 'Track A',
                    raw: const <String, Object?>{'id': 'a'},
                  ),
                  PlaybackItem.plugin(
                    platform: 'Library',
                    musicId: 'b',
                    title: 'Track B',
                    raw: const <String, Object?>{'id': 'b'},
                  ),
                ]),
              ),
            ].cast(),
            // A Scaffold, because the app shell always provides one and the
            // page's own InkWells need a Material ancestor.
            child: const MaterialApp(home: Scaffold(body: LibraryPage())),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);

        // A style is only implemented if it renders *differently*: asserting
        // "no exception" would also pass for a branch that silently fell
        // through to the row list, which is exactly the bug being guarded.
        final scrollables = tester
            .widgetList<Scrollable>(find.byType(Scrollable))
            .map((widget) => widget.axisDirection)
            .toList();
        if (style == ThemeListStyle.banner) {
          expect(
            scrollables.any(
              (axis) =>
                  axis == AxisDirection.right || axis == AxisDirection.left,
            ),
            isTrue,
            reason: 'banner is the horizontal cover flow',
          );
        } else {
          expect(
            scrollables.any(
              (axis) => axis == AxisDirection.down || axis == AxisDirection.up,
            ),
            isTrue,
            reason: '${style.name} lays out vertically',
          );
        }
      });
    }
  });
}

ThemePackage _parse(Map<String, Object?> raw) {
  return const ThemeManifestParser().tryParse(<String, Object?>{
    'id': 'demo',
    ...raw,
  }, source: ThemeSource.builtIn)!;
}

/// A library with real rows, so a style branch is observable.
class _SeededLibrary extends LocalMusicLibraryController {
  _SeededLibrary(this._tracks);

  final List<PlaybackItem> _tracks;

  @override
  Future<List<PlaybackItem>> build() async => _tracks;
}
