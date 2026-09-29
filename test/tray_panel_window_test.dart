import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/features/tray/application/tray_panel_controller.dart';
import 'package:robyne/features/tray/presentation/tray_panel_window.dart';

void main() {
  testWidgets('tray panel renders track header and controls', (tester) async {
    await tester.pumpWidget(const TrayPanelWindowApp());
    await tester.pump();

    expect(find.text('暂无播放'), findsOneWidget);
    expect(find.text('Robyne'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
    expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
    expect(find.text('开启桌面歌词'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('退出 Robyne'), findsOneWidget);
    // A native tray menu cannot show cover art; the Flutter panel must. With
    // nothing playing it falls back to the app's shared placeholder glyph.
    expect(find.byIcon(Icons.album), findsOneWidget);
  });

  testWidgets('tray payload decodes playback state', (tester) async {
    const payload = TrayPanelPayload(
      title: 'Test track',
      artist: 'Test artist',
      playing: true,
      liked: true,
      desktopLyricsEnabled: true,
      mode: 'allLoop',
      artworkUrl: 'https://example.com/cover.jpg',
    );
    final decoded = TrayPanelPayload.fromJson(payload.toJson());

    expect(decoded.title, 'Test track');
    expect(decoded.artist, 'Test artist');
    expect(decoded.playing, isTrue);
    expect(decoded.liked, isTrue);
    expect(decoded.desktopLyricsEnabled, isTrue);
    expect(decoded.mode, 'allLoop');
    expect(decoded.artworkUrl, 'https://example.com/cover.jpg');
    expect(trayPanelModeIcon(decoded.mode), Icons.repeat);
  });
}
