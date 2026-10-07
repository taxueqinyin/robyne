import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/theme/domain/theme_materials.dart';
import 'package:robyne/core/theme/domain/theme_tokens.dart';
import 'package:robyne/core/theme/presentation/theme_material.dart';

/// Renders the materials layer through Flutter's own pipeline and writes a
/// PNG, so the effect can be inspected without a GPU-backed desktop session.
///
/// Tagged `preview` and skipped by default: it asserts nothing about
/// behaviour, and its only output is a file under `build/shots/`. Run it
/// explicitly with:
///
/// ```
/// flutter test test/theme_material_preview_test.dart --tags preview
/// ```
void main() {
  testWidgets(
    'renders a materials preview sheet',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MediaQuery(
          // The sheet demonstrates the paints, not the motion; freezing
          // animation also keeps the stepped test clock from never settling.
          data: MediaQueryData(disableAnimations: true),
          child: _PreviewSheet(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      // `matchesGoldenFile` is the one capture path that works under the
      // headless test renderer; `RenderRepaintBoundary.toImage` needs a real
      // GPU surface and hangs in a stepped test. `--update-goldens` writes the
      // sheet to disk for inspection.
      await expectLater(
        find.byKey(const Key('preview-sheet')),
        // `test/shots/` is git-ignored: inspecting the effect must never add a
        // binary to the repository, and the file is regenerated on demand.
        matchesGoldenFile('shots/materials-preview.png'),
      );
    },
    // Opt-in only: the sheet writes a PNG under `build/shots/`, which is
    // gitignored and therefore absent on a clean checkout. Running it by
    // default would make CI depend on a directory that does not exist.
    skip: !Platform.environment.containsKey('ROBYNE_PREVIEW'),
    tags: <String>['preview'],
  );
}

class _PreviewSheet extends StatelessWidget {
  const _PreviewSheet();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 1100,
        height: 1040,
        child: RepaintBoundary(
          key: const Key('preview-sheet'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[Color(0xFF101826), Color(0xFF241322)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const _Label('frosted navBar + glow'),
                    _Card(
                      material: const ThemeMaterial(
                        color: Color(0xCC181F2E),
                        blur: 28,
                        saturation: 1.3,
                        border: ThemeMaterialBorder(color: Color(0x1FFFFFFF)),
                        shadows: <ThemeShadow>[
                          ThemeShadow(
                            color: Color(0x668B5CF6),
                            blur: 46,
                            spread: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    const _Label('radial overlay · screen · shimmer'),
                    _Card(
                      material: ThemeMaterial(
                        gradient: const ThemeGradient(
                          stops: <ThemeGradientStop>[
                            ThemeGradientStop(
                              color: Color(0xFFFF6B3D),
                              offset: 0,
                            ),
                            ThemeGradientStop(
                              color: Color(0xFF2A1B2E),
                              offset: 1,
                            ),
                          ],
                        ),
                        overlay: const ThemeMaterialOverlay(
                          gradient: ThemeGradient(
                            kind: ThemeGradientKind.radial,
                            center: ThemePoint(0.82, 0.2),
                            radius: 0.9,
                            stops: <ThemeGradientStop>[
                              ThemeGradientStop(
                                color: Color(0x99FFD9C2),
                                offset: 0,
                              ),
                              ThemeGradientStop(
                                color: Color(0x00FFD9C2),
                                offset: 1,
                              ),
                            ],
                          ),
                          blend: ThemeBlendMode.screen,
                          opacity: 0.8,
                        ),
                        shadows: <ThemeShadow>[
                          ThemeShadow(color: Color(0x55FF6B3D), blur: 40),
                        ],
                        shimmer: ThemeShimmer(
                          color: Color(0x4DFFFFFF),
                          width: 0.16,
                          angle: -22,
                          periodMs: 5200,
                          opacity: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const _Label('sweep gradient · multiply overlay'),
                    _Card(
                      material: ThemeMaterial(
                        gradient: const ThemeGradient(
                          kind: ThemeGradientKind.sweep,
                          stops: <ThemeGradientStop>[
                            ThemeGradientStop(
                              color: Color(0xFF63D8C3),
                              offset: 0,
                            ),
                            ThemeGradientStop(
                              color: Color(0xFF7C4DFF),
                              offset: 0.5,
                            ),
                            ThemeGradientStop(
                              color: Color(0xFF63D8C3),
                              offset: 1,
                            ),
                          ],
                        ),
                        overlay: const ThemeMaterialOverlay(
                          color: Color(0x66000000),
                          blend: ThemeBlendMode.multiply,
                        ),
                        border: ThemeMaterialBorder(color: Color(0x33FFFFFF)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFE8EAED),
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.material});

  final ThemeMaterial material;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: MaterialSurface(
        material: material,
        tokens: const ThemeTokens.baseline(),
        borderRadius: BorderRadius.circular(18),
        scaleToFill: true,
        child: const SizedBox.expand(),
      ),
    );
  }
}
