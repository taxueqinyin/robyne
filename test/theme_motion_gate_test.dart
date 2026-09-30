import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/theme/domain/theme_materials.dart';
import 'package:robyne/core/theme/domain/theme_tokens.dart';
import 'package:robyne/core/theme/presentation/theme_material.dart';

/// Theme motion is decoration, but an endless ticker is not free: it burns
/// battery, and under stepped frames it means the app never reaches a stable
/// state. These cases lock down that the gate exists and that the paints
/// survive without their animation.
void main() {
  testWidgets('reduce-motion stops theme motion', (tester) async {
    late bool allowed;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(
          builder: (context) {
            allowed = themeMotionAllowed(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(allowed, isFalse);
  });

  testWidgets('a still surface still paints every layer', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 100,
              child: MaterialSurface(
                material: const ThemeMaterial(
                  color: Color(0xFF101214),
                  blur: 24,
                  shimmer: ThemeShimmer(
                    color: Color(0x40FFFFFF),
                    periodMs: 4000,
                  ),
                ),
                tokens: const ThemeTokens.baseline(),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // The frost is still there; only the moving highlight is withheld.
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
