import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../player/presentation/artwork_view.dart';
import '../application/tray_panel_controller.dart';

class TrayPanelWindowApp extends StatefulWidget {
  const TrayPanelWindowApp({super.key});

  @override
  State<TrayPanelWindowApp> createState() => _TrayPanelWindowAppState();
}

class _TrayPanelWindowAppState extends State<TrayPanelWindowApp>
    with WindowListener {
  TrayPanelPayload _payload = const TrayPanelPayload.empty();
  WindowController? _controller;
  bool _sizeReported = false;
  DateTime? _shownAt;
  Rect? _anchor;
  Rect? _workArea;
  Size? _measuredSize;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    Future<void>.microtask(_registerHandler);
  }

  Future<void> _registerHandler() async {
    final controller = await WindowController.fromCurrentEngine();
    _controller = controller;
    await controller.setWindowMethodHandler((call) async {
      switch (call.method) {
        case TrayPanelController.updateMethod:
          final arguments = call.arguments;
          if (arguments is Map<Object?, Object?> && mounted) {
            setState(() {
              _payload = TrayPanelPayload.fromJson(arguments);
            });
          }
        case TrayPanelController.showMethod:
          // The anchor usually arrives after the panel's first (hidden) layout,
          // so re-apply it here; `_fitWindowToContent` only runs once.
          final measured = _measuredSize;
          if (measured != null) {
            await _applyAnchor(measured);
          }
          await windowManager.show();
          await windowManager.focus();
          _shownAt = DateTime.now();
          return true;
        case TrayPanelController.hideMethod:
          await windowManager.hide();
          return true;
        case TrayPanelController.setAnchorMethod:
          final arguments = call.arguments;
          if (arguments is Map) {
            final anchor = _rectFrom(
              arguments,
              'left',
              'top',
              'right',
              'bottom',
            );
            final workArea = _rectFrom(
              arguments,
              'workLeft',
              'workTop',
              'workRight',
              'workBottom',
            );
            if (anchor != null && workArea != null) {
              _anchor = anchor;
              _workArea = workArea;
              final measured = _measuredSize;
              if (measured != null) {
                await _applyAnchor(measured);
              }
            }
          }
          return true;
      }
      return true;
    });
  }

  static Rect? _rectFrom(
    Map<Object?, Object?> map,
    String leftKey,
    String topKey,
    String rightKey,
    String bottomKey,
  ) {
    final left = (map[leftKey] as num?)?.toDouble();
    final top = (map[topKey] as num?)?.toDouble();
    final right = (map[rightKey] as num?)?.toDouble();
    final bottom = (map[bottomKey] as num?)?.toDouble();
    if (left == null || top == null || right == null || bottom == null) {
      return null;
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  Future<void> _invoke(String method, [Object? arguments]) async {
    try {
      await trayPanelControlChannel.invokeMethod<void>(method, arguments);
    } finally {
      await windowManager.hide();
      await _notifyHidden();
    }
  }

  Future<void> _notifyHidden() async {
    try {
      await trayPanelControlChannel.invokeMethod<void>(
        TrayPanelController.hiddenMethod,
      );
    } catch (_) {
      // The main window may already be closing.
    }
  }

  /// Measures the panel's content and resizes the window to fit it exactly.
  ///
  /// The window is created at the content's natural size, so a hardcoded
  /// height either clips the last row or leaves an empty strip below `退出` as
  /// rows are added. Measuring here keeps the frame and the content in lock
  /// step, and reports the size so the controller can anchor the panel.
  void _fitWindowToContent(Size size) {
    if (_sizeReported || size.width <= 0 || size.height <= 0) {
      return;
    }
    _sizeReported = true;
    _measuredSize = size;
    unawaited(() async {
      try {
        await windowManager.setSize(size);
      } catch (_) {}
      await _applyAnchor(size);
      try {
        await trayPanelControlChannel.invokeMethod<void>(
          TrayPanelController.sizeMethod,
          <String, double>{'width': size.width, 'height': size.height},
        );
      } catch (_) {}
    }());
  }

  /// Places the panel against the tray icon now that its height is known.
  ///
  /// Menu semantics: sit above a bottom taskbar, below a top one, and clamp
  /// inside the work area so the panel is never partly off-screen.
  Future<void> _applyAnchor(Size size) async {
    final anchor = _anchor;
    final area = _workArea;
    if (anchor == null || area == null) {
      return;
    }
    const gap = 8.0;
    const margin = 8.0;
    var left = anchor.center.dx - size.width / 2;
    var top = anchor.top - size.height - gap;
    if (top < area.top + margin) {
      top = anchor.bottom + gap;
    }
    final maxLeft = area.right - size.width - margin;
    final maxTop = area.bottom - size.height - margin;
    left = left.clamp(
      area.left + margin,
      maxLeft < area.left ? area.left : maxLeft,
    );
    top = top.clamp(area.top + margin, maxTop < area.top ? area.top : maxTop);
    try {
      await windowManager.setPosition(Offset(left, top));
    } catch (_) {}
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    final controller = _controller;
    if (controller != null) {
      unawaited(controller.setWindowMethodHandler(null));
    }
    super.dispose();
  }

  /// Dismisses on focus loss so the panel behaves like a real context menu:
  /// clicking anywhere else closes it instead of leaving it stranded on top.
  ///
  /// The short guard window matters because the panel is shown and focused in
  /// two steps, and the blur that arrives before the focus lands would
  /// otherwise hide the panel the instant it opened.
  @override
  void onWindowBlur() {
    final shownAt = _shownAt;
    if (shownAt == null) {
      return;
    }
    if (DateTime.now().difference(shownAt) <
        const Duration(milliseconds: 200)) {
      return;
    }
    _shownAt = null;
    unawaited(windowManager.hide());
    unawaited(_notifyHidden());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF6B3D),
          brightness: Brightness.dark,
        ),
      ),
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: _MeasuredPanel(
          onMeasured: _fitWindowToContent,
          child: Material(
            color: const Color(0xFF16171A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.white.withAlpha(22)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _TrackHeader(payload: _payload),
                  const SizedBox(height: 10),
                  _TransportRow(
                    payload: _payload,
                    onLike: () => _invoke('toggle-like'),
                    onPrevious: () => _invoke('previous'),
                    onPlayPause: () => _invoke('toggle-playback'),
                    onNext: () => _invoke('next'),
                    onMode: () => _invoke('cycle-mode'),
                  ),
                  const Divider(color: Colors.white12, height: 20),
                  _PanelRow(
                    icon: Icons.lyrics_outlined,
                    label: _payload.desktopLyricsEnabled ? '显示桌面歌词' : '开启桌面歌词',
                    active: _payload.desktopLyricsEnabled,
                    onTap: () => _invoke('toggle-desktop-lyrics'),
                  ),
                  _PanelRow(
                    icon: Icons.settings_outlined,
                    label: '设置',
                    onTap: () => _invoke('settings'),
                  ),
                  _PanelRow(
                    icon: Icons.power_settings_new_rounded,
                    label: '退出 Robyne',
                    onTap: () => _invoke('exit'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Measures its child's intrinsic size on first layout and reports it once.
class _MeasuredPanel extends StatefulWidget {
  const _MeasuredPanel({required this.child, required this.onMeasured});

  final Widget child;
  final ValueChanged<Size> onMeasured;

  @override
  State<_MeasuredPanel> createState() => _MeasuredPanelState();
}

class _MeasuredPanelState extends State<_MeasuredPanel> {
  bool _reported = false;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (!_reported) {
                    _reported = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        widget.onMeasured(constraints.biggest);
                      }
                    });
                  }
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackHeader extends StatelessWidget {
  const _TrackHeader({required this.payload});

  final TrayPanelPayload payload;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(16),
            borderRadius: BorderRadius.circular(10),
          ),
          clipBehavior: Clip.antiAlias,
          // Reuse the app's artwork resolver so local files, downloads and
          // network covers all render the same way the player does.
          child: ArtworkView(artworkUrl: payload.artworkUrl, size: 60),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                payload.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                payload.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withAlpha(168),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TransportRow extends StatelessWidget {
  const _TransportRow({
    required this.payload,
    required this.onLike,
    required this.onPrevious,
    required this.onPlayPause,
    required this.onNext,
    required this.onMode,
  });

  final TrayPanelPayload payload;
  final VoidCallback onLike;
  final VoidCallback onPrevious;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onMode;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: onLike,
          icon: Icon(
            payload.liked ? Icons.favorite : Icons.favorite_border,
            color: payload.liked ? const Color(0xFFFF6B3D) : null,
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: onPrevious,
          icon: const Icon(Icons.skip_previous_rounded, size: 28),
        ),
        IconButton.filled(
          onPressed: onPlayPause,
          iconSize: 30,
          icon: Icon(
            payload.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: onNext,
          icon: const Icon(Icons.skip_next_rounded, size: 28),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: onMode,
          icon: Icon(trayPanelModeIcon(payload.mode), size: 21),
        ),
      ],
    );
  }
}

class _PanelRow extends StatelessWidget {
  const _PanelRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
        child: Row(
          children: <Widget>[
            Icon(
              icon,
              size: 20,
              color: active ? const Color(0xFFFF6B3D) : Colors.white70,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: active ? const Color(0xFFFF6B3D) : Colors.white,
                ),
              ),
            ),
            if (active)
              const Icon(
                Icons.check_rounded,
                size: 18,
                color: Color(0xFFFF6B3D),
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> configureTrayPanelWindow() async {
  await windowManager.ensureInitialized();
  const options = WindowOptions(
    size: Size(288, 332),
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    alwaysOnTop: true,
    titleBarStyle: TitleBarStyle.hidden,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.setAsFrameless();
    await windowManager.setBackgroundColor(Colors.transparent);
    await windowManager.setSkipTaskbar(true);
    await windowManager.setResizable(false);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setHasShadow(false);
  });
}
