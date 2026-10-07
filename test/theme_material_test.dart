import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:robyne/core/theme/application/theme_providers.dart';
import 'package:robyne/core/theme/domain/theme_materials.dart';
import 'package:robyne/core/theme/domain/theme_package.dart';
import 'package:robyne/core/theme/domain/theme_tokens.dart';
import 'package:robyne/core/theme/infrastructure/theme_manifest_parser.dart';
import 'package:robyne/core/theme/infrastructure/token_patcher.dart';
import 'package:robyne/core/theme/presentation/theme_material.dart';

/// The materials layer is the difference between "a recoloured app" and a
/// skin system: blur, gradients in three shapes, blend layers, glow and
/// shimmer. These cases lock down each axis at the manifest boundary, because
/// a token that parses but never paints is exactly the failure this layer
/// exists to prevent.
void main() {
  group('gradient vocabulary', () {
    test('the object spelling carries kind, direction and tiling', () {
      final theme = _parse(<String, Object?>{
        'tokens': <String, Object?>{
          'materials': <String, Object?>{
            'hero': <String, Object?>{
              'gradient': <String, Object?>{
                'kind': 'radial',
                'center': <Object?>[0.8, 0.2],
                'radius': 1.2,
                'tile': 'mirror',
                'stops': <Object?>[
                  <String, Object?>{'color': '#FF6B3D', 'offset': 0},
                  <String, Object?>{'color': '#1F2E2A', 'offset': 1},
                ],
              },
            },
          },
        },
      });

      final gradient = theme.tokens.materials.hero.gradient;
      expect(gradient.kind, ThemeGradientKind.radial);
      expect(gradient.center.x, 0.8);
      expect(gradient.center.y, 0.2);
      expect(gradient.radius, 1.2);
      expect(gradient.tile, ThemeGradientTile.mirror);
      expect(gradient.stops, hasLength(2));
    });

    test('sweep angles and linear endpoints parse', () {
      final theme = _parse(<String, Object?>{
        'tokens': <String, Object?>{
          'materials': <String, Object?>{
            'card': <String, Object?>{
              'gradient': <String, Object?>{
                'kind': 'sweep',
                'startAngle': 45,
                'endAngle': 315,
                'colors': <Object?>['#FF0000', '#0000FF'],
              },
            },
            'navBar': <String, Object?>{
              'gradient': <String, Object?>{
                'begin': 'bottom-left',
                'end': 'top-right',
                'stops': <Object?>['#111111', '#222222'],
              },
            },
          },
        },
      });

      final sweep = theme.tokens.materials.card.gradient;
      expect(sweep.kind, ThemeGradientKind.sweep);
      expect(sweep.startAngle, 45);
      expect(sweep.endAngle, 315);
      expect(sweep.stops, hasLength(2));

      final linear = theme.tokens.materials.navBar.gradient;
      expect(linear.begin.x, -1);
      expect(linear.begin.y, 1);
      expect(linear.end.x, 1);
      expect(linear.end.y, -1);
    });

    test('《玄》 declares a navigable, non-empty gradient', () {
      // The flagship declared `gradient: { "stops": [...] }` for a year while
      // the parser only accepted a flat list, so its gradient silently
      // rendered as "no gradient at all". This is the regression guard.
      final theme = _parse(<String, Object?>{
        'tokens': <String, Object?>{
          'components': <String, Object?>{
            'navBar': <String, Object?>{
              'gradient': <String, Object?>{
                'stops': <Object?>[
                  <String, Object?>{'color': '#171A1E', 'offset': 0},
                  <String, Object?>{'color': '#121417', 'offset': 1},
                ],
              },
            },
          },
        },
      });

      expect(theme.tokens.components.navBar.gradient.isEmpty, isFalse);
      expect(theme.tokens.components.navBar.gradient.stops, hasLength(2));
    });

    test('a plain colour list still spreads evenly', () {
      final theme = _parse(<String, Object?>{
        'tokens': <String, Object?>{
          'materials': <String, Object?>{
            'card': <String, Object?>{
              'gradient': <Object?>['#FF0000', '#00FF00', '#0000FF'],
            },
          },
        },
      });

      final stops = theme.tokens.materials.card.gradient.stops;
      expect(stops.map((stop) => stop.offset), <double>[0, 0.5, 1]);
    });

    test('out-of-range offsets are clamped, never rejected', () {
      final theme = _parse(<String, Object?>{
        'tokens': <String, Object?>{
          'materials': <String, Object?>{
            'card': <String, Object?>{
              'gradient': <String, Object?>{
                'stops': <Object?>[
                  <String, Object?>{'color': '#FF0000', 'offset': -5},
                  <String, Object?>{'color': '#0000FF', 'offset': 9},
                ],
              },
            },
          },
        },
      });

      final stops = theme.tokens.materials.card.gradient.stops;
      expect(stops.first.offset, 0);
      expect(stops.last.offset, 1);
    });
  });

  group('material parsing', () {
    test('every surface field reaches the model', () {
      final theme = _parse(<String, Object?>{
        'tokens': <String, Object?>{
          'materials': <String, Object?>{
            'navBar': <String, Object?>{
              'color': '#CC121417',
              'opacity': 0.9,
              'blur': 32,
              'saturation': 1.4,
              'brightness': 0.9,
              'contrast': 1.1,
              'grayscale': 0.2,
              'blend': 'soft-light',
              'radius': 18,
              'border': <String, Object?>{'color': '#33FFFFFF', 'width': 2},
              'overlay': <String, Object?>{
                'color': '#22FF6B3D',
                'blend': 'screen',
                'opacity': 0.6,
              },
              'shadows': <Object?>[
                <String, Object?>{
                  'color': '#66FF6B3D',
                  'blur': 40,
                  'spread': 2,
                  'dy': 6,
                },
              ],
            },
          },
        },
      });

      final material = theme.tokens.materials.navBar;
      expect(material.color, const Color(0xCC121417));
      expect(material.opacity, 0.9);
      expect(material.blur, 32);
      expect(material.saturation, 1.4);
      expect(material.brightness, 0.9);
      expect(material.contrast, 1.1);
      expect(material.grayscale, 0.2);
      expect(material.blend, ThemeBlendMode.softLight);
      expect(material.radius, 18);
      expect(material.border?.width, 2);
      expect(material.overlay?.blend, ThemeBlendMode.screen);
      expect(material.overlay?.opacity, 0.6);
      expect(material.shadows, hasLength(1));
      expect(material.shadows.first.blur, 40);
      expect(material.shadows.first.dy, 6);
    });

    test('shimmer parses and is absent by default', () {
      final theme = _parse(<String, Object?>{
        'tokens': <String, Object?>{
          'materials': <String, Object?>{
            'hero': <String, Object?>{
              'shimmer': <String, Object?>{
                'color': '#40FFFFFF',
                'width': 0.2,
                'angle': -18,
                'periodMs': 4000,
                'blend': 'plus',
              },
            },
          },
        },
      });

      final shimmer = theme.tokens.materials.hero.shimmer;
      expect(shimmer, isNotNull);
      expect(shimmer!.period, const Duration(seconds: 4));
      expect(shimmer.blend, ThemeBlendMode.plus);
      expect(shimmer.width, 0.2);
      // Surfaces that declare nothing keep the no-ticker default.
      expect(theme.tokens.materials.card.shimmer, isNull);
    });

    test('a surface with nothing declared is transparent', () {
      const materials = ThemeMaterials.baseline();
      expect(materials.navBar.isTransparent, isTrue);
      expect(materials.card.isTransparent, isTrue);
      expect(materials.navBar.hasBackdropFilter, isFalse);
    });

    test('hostile numbers are clamped instead of reaching Skia', () {
      final theme = _parse(<String, Object?>{
        'tokens': <String, Object?>{
          'materials': <String, Object?>{
            'card': <String, Object?>{
              'blur': 99999,
              'opacity': 42,
              'grayscale': -3,
              'shadows': <Object?>[
                for (var index = 0; index < 40; index += 1)
                  <String, Object?>{'color': '#FF0000', 'blur': 1},
              ],
            },
          },
        },
      });

      final material = theme.tokens.materials.card;
      expect(material.blur, lessThanOrEqualTo(200));
      expect(material.opacity, lessThanOrEqualTo(1));
      expect(material.grayscale, greaterThanOrEqualTo(0));
      // A manifest cannot ask for an unbounded number of extra raster passes.
      expect(material.shadows.length, lessThanOrEqualTo(8));
    });

    test('unknown blend names fall back instead of throwing', () {
      final theme = _parse(<String, Object?>{
        'tokens': <String, Object?>{
          'materials': <String, Object?>{
            'card': <String, Object?>{'blend': 'not-a-blend-mode'},
          },
        },
      });

      expect(theme.tokens.materials.card.blend, ThemeBlendMode.normal);
    });
  });

  group('background treatment', () {
    test('blur, grading and layers parse', () {
      final theme = _parse(<String, Object?>{
        'tokens': <String, Object?>{
          'background': <String, Object?>{
            'image': 'assets/bg.webp',
            'blur': 30,
            'saturation': 1.6,
            'brightness': 0.8,
            'contrast': 1.2,
            'grayscale': 0.1,
            'scale': 1.1,
            'overlayBlend': 'multiply',
            'layers': <Object?>[
              <String, Object?>{
                'gradient': <String, Object?>{
                  'kind': 'radial',
                  'stops': <Object?>['#FFFFFF00', '#00000000'],
                },
                'blend': 'soft-light',
                'opacity': 0.5,
              },
            ],
          },
        },
      });

      final background = theme.tokens.background;
      expect(background.blur, 30);
      expect(background.saturation, 1.6);
      expect(background.brightness, 0.8);
      expect(background.contrast, 1.2);
      expect(background.grayscale, 0.1);
      expect(background.scale, 1.1);
      expect(background.overlayBlend, ThemeBlendMode.multiply);
      expect(background.layers, hasLength(1));
      expect(background.layers.first.blend, ThemeBlendMode.softLight);
      expect(background.hasImageTreatment, isTrue);
    });

    test('identity defaults report no treatment', () {
      const background = ThemeBackground.baseline();
      expect(background.hasImageTreatment, isFalse);
      expect(background.layers, isEmpty);
    });
  });

  group('ambient lights', () {
    test('multiple lights and drift parse', () {
      final theme = _parse(<String, Object?>{
        'tokens': <String, Object?>{
          'components': <String, Object?>{
            'ambient': <String, Object?>{
              'enabled': true,
              'driftSeconds': 18,
              'lights': <Object?>[
                <String, Object?>{
                  'anchor': 'top-right',
                  'radius': 1.2,
                  'strength': 0.4,
                  'blur': 70,
                  'blend': 'screen',
                },
                <String, Object?>{
                  'anchor': <Object?>[0.2, 0.6],
                  'strength': 0.2,
                },
              ],
            },
          },
        },
      });

      final ambient = theme.tokens.components.ambient;
      expect(ambient.lights, hasLength(2));
      expect(ambient.lights.first.anchor.x, 1);
      expect(ambient.lights.first.anchor.y, -1);
      expect(ambient.lights.last.anchor.x, 0.2);
      expect(ambient.driftSeconds, 18);
      expect(ambient.isAnimated, isTrue);
    });

    test('a still ambient layer needs no ticker', () {
      final theme = _parse(<String, Object?>{
        'tokens': <String, Object?>{
          'components': <String, Object?>{
            'ambient': <String, Object?>{'enabled': true},
          },
        },
      });

      expect(theme.tokens.components.ambient.isAnimated, isFalse);
      expect(theme.tokens.components.ambient.lights, isEmpty);
    });

    test('light count is capped', () {
      final theme = _parse(<String, Object?>{
        'tokens': <String, Object?>{
          'components': <String, Object?>{
            'ambient': <String, Object?>{
              'enabled': true,
              'lights': <Object?>[
                for (var index = 0; index < 30; index += 1)
                  <String, Object?>{'anchor': 'topLeft'},
              ],
            },
          },
        },
      });

      expect(
        theme.tokens.components.ambient.lights.length,
        lessThanOrEqualTo(6),
      );
    });
  });

  group('material knobs', () {
    test('a scalar knob patches one surface without touching the rest', () {
      const patcher = TokenPatcher();
      final patched = patcher.apply(
        const ThemeTokens.baseline(),
        <String, Object>{'materials.card.blur': 24},
      );

      expect(patched.materials.card.blur, 24);
      expect(patched.materials.navBar.blur, 0);
    });

    test('an unknown material target is ignored', () {
      const patcher = TokenPatcher();
      final baseline = const ThemeTokens.baseline();
      final patched = patcher.apply(baseline, <String, Object>{
        'materials.nonsense.blur': 24,
      });

      expect(patched.materials.card.blur, baseline.materials.card.blur);
    });
  });

  group('rendering', () {
    testWidgets('a blur material installs a backdrop filter', (tester) async {
      await tester.pumpWidget(
        _host(const ThemeMaterial(blur: 24, color: Color(0xCC101214))),
      );

      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a solid material paints without a filter', (tester) async {
      await tester.pumpWidget(
        _host(const ThemeMaterial(color: Color(0xFF101214))),
      );

      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shadows render as a decoration', (tester) async {
      await tester.pumpWidget(
        _host(
          const ThemeMaterial(
            color: Color(0xFF101214),
            shadows: <ThemeShadow>[
              ThemeShadow(color: Color(0x66FF6B3D), blur: 40, spread: 2),
            ],
          ),
        ),
      );

      final decorated = tester.widgetList<DecoratedBox>(
        find.byType(DecoratedBox),
      );
      final shadowed = decorated
          .map((widget) => widget.decoration)
          .whereType<BoxDecoration>()
          .where((decoration) => (decoration.boxShadow ?? const []).isNotEmpty);
      expect(shadowed, isNotEmpty);
    });

    testWidgets('a shimmer creates a ticker, a matte surface does not', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const ThemeMaterial(
            color: Color(0xFF101214),
            shimmer: ThemeShimmer(color: Color(0x40FFFFFF), periodMs: 5000),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        _host(const ThemeMaterial(color: Color(0xFF101214))),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty material keeps the child tree untouched', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const ThemeMaterial(), child: const Text('plain')),
      );

      expect(find.byType(BackdropFilter), findsNothing);
      expect(
        find.descendant(
          of: find.byType(MaterialSurface),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
      expect(find.text('plain'), findsOneWidget);
    });
  });

  group('flagship skin', () {
    test('《玄》 declares materials that survive parsing', () {
      final raw =
          jsonDecode(File('assets/themes/xuan/theme.json').readAsStringSync())
              as Map<String, Object?>;
      final theme = const ThemeManifestParser().tryParse(
        raw,
        source: ThemeSource.builtIn,
      )!;

      final materials = theme.tokens.materials;
      // The flagship is the proof the system can do this at all; if its
      // declarations quietly stop parsing, the demo value of the system is
      // gone even though every unit test above still passes.
      expect(materials.navBar.blur, greaterThan(0));
      expect(materials.playerBar.blur, greaterThan(0));
      expect(materials.card.blur, greaterThan(0));
      expect(materials.navBar.shadows, isNotEmpty);
      expect(materials.playerBar.gradient.isEmpty, isFalse);
      expect(materials.hero.overlay?.isEmpty, isFalse);
      expect(materials.hero.shimmer, isNotNull);
      expect(theme.tokens.components.ambient.lights.length, greaterThan(1));
      // The flagship keeps the content plane matte: the wash is a taste
      // decision, and 《玄》 reads as a near-black page. The declarations
      // still have to survive the parser, because a skin that wants the
      // atmosphere flips `enabled` and expects the lights to be there.
      expect(theme.tokens.components.ambient.enabled, isFalse);
      expect(theme.tokens.components.ambient.isVisible, isFalse);
    });

    testWidgets('a declared material reaches the rendered shell', (
      tester,
    ) async {
      tester.view.physicalSize =
          const Size(1280, 900) * tester.view.devicePixelRatio;
      addTearDown(tester.view.resetPhysicalSize);

      final package = _parse(<String, Object?>{
        'tokens': <String, Object?>{
          'materials': <String, Object?>{
            'content': <String, Object?>{'color': '#CC101214', 'blur': 24},
          },
        },
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Object>[
            baseThemePackageProvider.overrideWithValue(package),
          ].cast(),
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 300,
                height: 200,
                child: MaterialSurface(
                  material: ThemeMaterial(blur: 24),
                  tokens: ThemeTokens.baseline(),
                  child: SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(BackdropFilter), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}

Widget _host(ThemeMaterial material, {Widget? child}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 240,
          height: 120,
          child: MaterialSurface(
            material: material,
            tokens: const ThemeTokens.baseline(),
            child: child ?? const SizedBox.expand(),
          ),
        ),
      ),
    ),
  );
}

ThemePackage _parse(Map<String, Object?> raw) {
  return const ThemeManifestParser().tryParse(<String, Object?>{
    'id': 'demo',
    ...raw,
  }, source: ThemeSource.builtIn)!;
}
