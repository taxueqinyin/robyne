import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/theme/application/theme_providers.dart';
import 'package:robyne/core/theme/presentation/theme_ambient.dart';
import 'package:robyne/features/lyrics/application/lyrics_providers.dart';
import 'package:robyne/features/lyrics/domain/lyric_document.dart';
import 'package:robyne/features/player/application/player_providers.dart';
import 'package:robyne/features/player/domain/playback_item.dart';
import 'package:robyne/features/player/presentation/now_playing_page.dart';

import 'support/xuan_fixture.dart';

/// Renders the Now Playing page at a desktop size for visual inspection.
///
/// Run with `flutter test --update-goldens test/now_playing_screenshot_test.dart`
/// to refresh `test/goldens/now_playing_immersive.png`.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await (FontLoader(
      'MiSans',
    )..addFont(rootBundle.load('assets/fonts/MiSansVF.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  testWidgets('now playing immersive golden', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const item = PlaybackItem(
      id: 'plugin:x:A',
      type: PlaybackItemType.plugin,
      title: '昔涟',
      platform: 'HOYO-MiX',
      artist: '张韶涵 / HOYO-MiX',
      album: '崩坏：星穹铁道',
      duration: Duration(minutes: 3, seconds: 6),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          baseThemePackageProvider.overrideWithValue(xuanFixture()),
          storedCurrentLyricsProvider.overrideWith((ref) async => null),
          playerControllerProvider.overrideWith(
            () => _SeededPlayerController(
              const PlayerControllerState(
                queue: <PlaybackItem>[item],
                currentItem: item,
                lastPosition: Duration(seconds: 40),
                lastDuration: Duration(minutes: 3, seconds: 6),
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(fontFamily: 'MiSans'),
          home: Scaffold(
            // `showWindowControls` selects the desktop branch, which is where
            // the auto-hiding chrome (and therefore the transport bar) lives.
            body: NowPlayingPage(
              immersive: true,
              showWindowControls: true,
              onClose: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await expectLater(
      find.byType(NowPlayingPage),
      matchesGoldenFile('goldens/now_playing_immersive.png'),
    );
  });

  testWidgets('now playing song menu golden', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const item = PlaybackItem(
      id: 'plugin:x:A',
      type: PlaybackItemType.plugin,
      title: '昔涟',
      platform: 'HOYO-MiX',
      artist: '张韶涵 / HOYO-MiX',
      duration: Duration(minutes: 3, seconds: 6),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          baseThemePackageProvider.overrideWithValue(xuanFixture()),
          storedCurrentLyricsProvider.overrideWith((ref) async => null),
          playerControllerProvider.overrideWith(
            () => _SeededPlayerController(
              const PlayerControllerState(
                queue: <PlaybackItem>[item],
                currentItem: item,
                lastDuration: Duration(minutes: 3, seconds: 6),
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(fontFamily: 'MiSans'),
          home: const Scaffold(
            body: NowPlayingPage(immersive: true, showWindowControls: true),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final gesture = await tester.startGesture(
      const Offset(300, 480),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/now_playing_song_menu.png'),
    );
  });

  testWidgets('now playing lyrics golden', (tester) async {
    // Pins the lyric column's extent and its top/bottom edge fade: the reading
    // column runs well past the cover, and the first and last visible lines
    // dissolve into the backdrop instead of being sliced by the pane.
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const item = PlaybackItem(
      id: 'plugin:x:A',
      type: PlaybackItemType.plugin,
      title: '昔涟',
      platform: 'HOYO-MiX',
      artist: '张韶涵 / HOYO-MiX',
      album: '崩坏：星穹铁道',
      duration: Duration(minutes: 3, seconds: 6),
    );
    final lyrics = LyricDocument(
      raw: '',
      sourceType: LyricSourceType.plugin,
      lines: <LyricLine>[
        for (var index = 0; index < 24; index += 1)
          LyricLine(
            text: <String>[
              '听天河如梦流泻',
              '与往事徒劳诀别',
              '前路光明依然遥远',
              '拉长的背影未停留',
              '只余下景花一片',
            ][index % 5],
            timestamp: Duration(seconds: index * 8),
          ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          baseThemePackageProvider.overrideWithValue(xuanFixture()),
          playerControllerProvider.overrideWith(
            () => _SeededPlayerController(
              const PlayerControllerState(
                queue: <PlaybackItem>[item],
                currentItem: item,
                lastPosition: Duration(seconds: 96),
                lastDuration: Duration(minutes: 3, seconds: 6),
              ),
            ),
          ),
          storedCurrentLyricsProvider.overrideWith((ref) async => lyrics),
        ],
        child: MaterialApp(
          theme: ThemeData(fontFamily: 'MiSans'),
          home: const Scaffold(
            body: NowPlayingPage(immersive: true, showWindowControls: true),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await expectLater(
      find.byType(NowPlayingPage),
      matchesGoldenFile('goldens/now_playing_lyrics.png'),
    );
  });

  testWidgets('now playing with cover-derived colour golden', (tester) async {
    // The point of this capture is the background and the play button: both
    // must come from the artwork's dominant colour rather than from the skin
    // swatch or a flat average.
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(clearArtworkPaletteCache);

    const item = PlaybackItem(
      id: 'local:cover',
      type: PlaybackItemType.local,
      title: '蓝色的歌',
      artist: '取色测试',
      artworkUrl: 'assets/branding/robyne_logo_source.png',
      duration: Duration(minutes: 4),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          baseThemePackageProvider.overrideWithValue(xuanFixture()),
          storedCurrentLyricsProvider.overrideWith((ref) async => null),
          playerControllerProvider.overrideWith(
            () => _SeededPlayerController(
              const PlayerControllerState(
                queue: <PlaybackItem>[item],
                currentItem: item,
                lastDuration: Duration(minutes: 4),
              ),
            ),
          ),
          // The golden harness has no asset bundle for `Image.file`, so the
          // palette is supplied directly: the capture is about what the player
          // does with a palette, not about decoding a PNG.
          artworkPaletteProvider(item.artworkUrl!).overrideWith(
            (ref) async => const ArtworkPalette(
              primary: Color(0xFF5B7CFA),
              secondary: Color(0xFFB06CF0),
              isDark: false,
            ),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(fontFamily: 'MiSans'),
          home: const Scaffold(
            body: NowPlayingPage(immersive: true, showWindowControls: true),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await expectLater(
      find.byType(NowPlayingPage),
      matchesGoldenFile('goldens/now_playing_colour.png'),
    );
  });
}

class _SeededPlayerController extends PlayerController {
  _SeededPlayerController(this._seed);

  final PlayerControllerState _seed;

  @override
  Future<PlayerControllerState> build() async => _seed;
}
