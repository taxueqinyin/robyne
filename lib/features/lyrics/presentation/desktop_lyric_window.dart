import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../../settings/application/shortcut_runtime.dart';
import '../../settings/domain/lyric_settings.dart';
import '../../settings/domain/shortcut_binding.dart';
import '../application/desktop_lyric_window_controller.dart';

class DesktopLyricWindowApp extends StatefulWidget {
  const DesktopLyricWindowApp({super.key});

  @override
  State<DesktopLyricWindowApp> createState() => _DesktopLyricWindowAppState();
}

class _DesktopLyricWindowAppState extends State<DesktopLyricWindowApp>
    with WindowListener {
  static const double _surfaceRadius = 16;
  static const double _horizontalPadding = 18;
  static const double _expandedTopPadding = 14;
  static const double _bottomPadding = 18;
  static const double _headerGap = 14;
  static const double _doubleLineGap = 10;
  static const double _toolbarHeight = 40;

  DesktopLyricPayload _payload = const DesktopLyricPayload.empty();
  final ShortcutTracker _shortcutTracker = ShortcutTracker();
  WindowController? _controller;
  Timer? _hoverExitTimer;
  bool _showChrome = false;
  bool _pointerPressed = false;
  bool _hoverExitPending = false;
  bool _windowSyncQueued = false;
  bool _windowPositionInitialized = false;
  Size? _lastWindowSize;
  bool? _lastAlwaysOnTop;
  Offset? _pendingProgrammaticWindowPosition;
  Offset? _lastReportedWindowPosition;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleShortcut);
    windowManager.addListener(this);
    Future<void>.microtask(_registerHandler);
  }

  Future<void> _registerHandler() async {
    final controller = await WindowController.fromCurrentEngine();
    _controller = controller;
    await controller.setWindowMethodHandler((call) async {
      if (call.method != DesktopLyricWindowController.updateMethod) {
        return null;
      }
      final arguments = call.arguments;
      if (arguments is! Map<Object?, Object?>) {
        return null;
      }
      final nextPayload = DesktopLyricPayload.fromJson(arguments);
      if (!mounted) {
        return true;
      }
      setState(() {
        if (_payload.toggleBinding != nextPayload.toggleBinding) {
          _shortcutTracker.reset();
        }
        _payload = nextPayload;
      });
      _scheduleWindowSync();
      return true;
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleShortcut);
    windowManager.removeListener(this);
    _hoverExitTimer?.cancel();
    final controller = _controller;
    if (controller != null) {
      unawaited(controller.setWindowMethodHandler(null));
    }
    super.dispose();
  }

  bool _handleShortcut(KeyEvent event) {
    final binding = _payload.toggleBinding;
    final matches = <(String, ShortcutBinding)>[];
    if (binding != null && binding.matchesSinglePress(event)) {
      matches.add(('toggle', binding));
    }
    final action = _shortcutTracker.match(event, matches);
    if (action != 'toggle') {
      return false;
    }
    unawaited(_invokeControl(desktopLyricToggleEnabledMethod));
    return true;
  }

  void _setChromeVisible(bool visible) {
    if (_showChrome == visible || !mounted) {
      return;
    }
    setState(() {
      _showChrome = visible;
    });
  }

  void _handleHoverEnter(PointerEnterEvent _) {
    _hoverExitTimer?.cancel();
    _hoverExitPending = false;
    _setChromeVisible(true);
  }

  void _handlePointerDown(PointerDownEvent _) {
    _hoverExitTimer?.cancel();
    _pointerPressed = true;
    _hoverExitPending = false;
  }

  void _handlePointerUp(PointerEvent _) {
    final shouldCollapse = _hoverExitPending;
    _pointerPressed = false;
    _hoverExitPending = false;
    if (shouldCollapse) {
      _setChromeVisible(false);
    }
  }

  void _handleHoverExit() {
    if (_pointerPressed) {
      _hoverExitPending = true;
      return;
    }
    _hoverExitTimer?.cancel();
    _hoverExitTimer = Timer(const Duration(milliseconds: 90), () {
      _hoverExitTimer = null;
      if (mounted) {
        _setChromeVisible(false);
      }
    });
  }

  void _scheduleWindowSync() {
    if (_windowSyncQueued || !mounted) {
      return;
    }
    _windowSyncQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _windowSyncQueued = false;
      unawaited(_applyWindowConfiguration());
    });
  }

  Future<void> _applyWindowConfiguration() async {
    if (!mounted) {
      return;
    }
    final settings = _payload.lyricSettings;
    final nextSize = _windowSizeFor(settings);
    final nextAlwaysOnTop = settings.desktopLyricsAlwaysOnTop;
    final savedPosition = settings.desktopLyricWindowOffset;

    try {
      await windowManager.setBackgroundColor(Colors.transparent);
      await windowManager.setHasShadow(false);
      await windowManager.setSkipTaskbar(true);
      await windowManager.setResizable(false);

      if (_lastAlwaysOnTop != nextAlwaysOnTop) {
        _lastAlwaysOnTop = nextAlwaysOnTop;
        await windowManager.setAlwaysOnTop(nextAlwaysOnTop);
      }

      final bounds = await windowManager.getBounds();
      final currentSize = bounds.size;
      final currentPosition = bounds.topLeft;
      final needsResize =
          !_sameSize(_lastWindowSize, nextSize) ||
          !_sameSize(currentSize, nextSize);
      final needsMoveToSaved =
          savedPosition != null && !_sameOffset(currentPosition, savedPosition);
      final needsCenter = savedPosition == null && !_windowPositionInitialized;

      if (!needsResize && !needsMoveToSaved && !needsCenter) {
        return;
      }

      _lastWindowSize = nextSize;
      await windowManager.setMinimumSize(nextSize);
      await windowManager.setMaximumSize(nextSize);

      if (savedPosition != null) {
        _windowPositionInitialized = true;
        await _applyProgrammaticWindowBounds(
          size: nextSize,
          position: savedPosition,
        );
        return;
      }

      if (!_windowPositionInitialized) {
        _windowPositionInitialized = true;
        await _applyProgrammaticWindowCenter(nextSize);
        return;
      }

      if (needsResize) {
        await _applyProgrammaticWindowBounds(
          size: nextSize,
          position: currentPosition,
        );
      }
    } catch (_) {}
  }

  Future<void> _applyProgrammaticWindowBounds({
    required Size size,
    required Offset position,
  }) async {
    await windowManager.setBounds(null, size: size, position: position);
    await _rememberProgrammaticWindowPosition();
  }

  Future<void> _applyProgrammaticWindowCenter(Size size) async {
    await windowManager.setSize(size);
    await windowManager.center();
    await _rememberProgrammaticWindowPosition();
  }

  Future<void> _rememberProgrammaticWindowPosition() async {
    final position = await windowManager.getPosition();
    _pendingProgrammaticWindowPosition = position;
    _lastReportedWindowPosition = position;
  }

  bool _sameSize(Size? left, Size right) {
    if (left == null) {
      return false;
    }
    return (left.width - right.width).abs() < 0.5 &&
        (left.height - right.height).abs() < 0.5;
  }

  bool _sameOffset(Offset left, Offset right) {
    return (left.dx - right.dx).abs() < 0.5 && (left.dy - right.dy).abs() < 0.5;
  }

  Size _windowSizeFor(LyricSettings settings) {
    final fontSize = settings.fontSize;
    final baseWidth = settings.desktopLyricsDoubleLine ? 860.0 : 760.0;
    final width = ((fontSize - 28) * 5 + baseWidth).clamp(560.0, 1040.0);
    return Size(
      width.toDouble(),
      _expandedSurfaceHeight(settings).clamp(88.0, 300.0),
    );
  }

  double _lyricBlockHeight(LyricSettings settings) {
    final lineHeight = settings.fontSize * 1.22;
    final lyricLineCount =
        settings.desktopLyricsDoubleLine && _payload.nextLyric.isNotEmpty
        ? 2.0
        : 1.0;
    return lineHeight * lyricLineCount +
        (lyricLineCount > 1 ? _doubleLineGap + settings.fontSize * 0.18 : 0);
  }

  double _expandedSurfaceHeight(LyricSettings settings) {
    final metadataHeight = _payload.subtitle.isNotEmpty ? 40.0 : 20.0;
    final headerHeight = metadataHeight > _toolbarHeight
        ? metadataHeight
        : _toolbarHeight;
    return _expandedTopPadding +
        headerHeight +
        _headerGap +
        _lyricBlockHeight(settings) +
        _bottomPadding;
  }

  Future<void> _invokeControl(String method, [Object? arguments]) async {
    try {
      await desktopLyricControlChannel.invokeMethod<void>(method, arguments);
    } catch (_) {}
  }

  @override
  void onWindowMoved() {
    unawaited(_syncWindowPosition());
  }

  Future<void> _syncWindowPosition() async {
    if (!mounted) {
      return;
    }
    try {
      final position = await windowManager.getPosition();
      final pendingProgrammaticPosition = _pendingProgrammaticWindowPosition;
      if (pendingProgrammaticPosition != null) {
        if (_sameOffset(position, pendingProgrammaticPosition)) {
          _pendingProgrammaticWindowPosition = null;
          return;
        }
        _pendingProgrammaticWindowPosition = null;
      }
      final lastReportedWindowPosition = _lastReportedWindowPosition;
      if (lastReportedWindowPosition != null &&
          _sameOffset(position, lastReportedWindowPosition)) {
        return;
      }
      _lastReportedWindowPosition = position;
      await _invokeControl(
        desktopLyricSetWindowPositionMethod,
        <String, double>{'left': position.dx, 'top': position.dy},
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = _payload.theme;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      color: Colors.transparent,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: theme.titleColor,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Colors.transparent,
        canvasColor: Colors.transparent,
      ),
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: _buildWindowFrame(context),
      ),
    );
  }

  Widget _buildWindowFrame(BuildContext context) {
    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerUp,
      child: MouseRegion(
        opaque: false,
        onEnter: _handleHoverEnter,
        onExit: (_) => _handleHoverExit(),
        child: _buildWindowSurface(context, showChrome: _showChrome),
      ),
    );
  }

  Widget _buildWindowSurface(BuildContext context, {required bool showChrome}) {
    final theme = _payload.theme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(_surfaceRadius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: showChrome
              ? theme.backgroundColor.withAlpha(238)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(_surfaceRadius),
          border: Border.all(
            color: showChrome
                ? theme.titleColor.withAlpha(60)
                : Colors.transparent,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (!_payload.lyricSettings.desktopLyricsLocked)
              const Positioned.fill(
                child: DragToMoveArea(child: SizedBox.expand()),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                _horizontalPadding,
                _expandedTopPadding,
                _horizontalPadding,
                _bottomPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  IgnorePointer(
                    ignoring: !showChrome,
                    child: Opacity(
                      opacity: showChrome ? 1 : 0,
                      child: _buildHeaderRow(context),
                    ),
                  ),
                  const SizedBox(height: _headerGap),
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: IgnorePointer(child: _buildLyricBody(context)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderRow(BuildContext context) {
    final theme = _payload.theme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: IgnorePointer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  _payload.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: theme.titleColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_payload.subtitle.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    _payload.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: theme.subtitleColor),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        _buildControlRow(),
      ],
    );
  }

  Widget _buildControlRow() {
    if (_payload.lyricSettings.desktopLyricsLocked) {
      return _DesktopLyricToolbar(
        actions: <Widget>[
          _LyricToolButton(
            icon: Icons.lock_open_rounded,
            tooltip: '解锁歌词',
            onPressed: () => _invokeControl(desktopLyricToggleLockedMethod),
          ),
        ],
      );
    }

    return _DesktopLyricToolbar(
      actions: <Widget>[
        _LyricToolButton(
          icon: _payload.lyricSettings.desktopLyricsAlwaysOnTop
              ? Icons.push_pin_rounded
              : Icons.push_pin_outlined,
          tooltip: _payload.lyricSettings.desktopLyricsAlwaysOnTop
              ? '取消置顶'
              : '桌面歌词置顶',
          active: _payload.lyricSettings.desktopLyricsAlwaysOnTop,
          onPressed: () => _invokeControl(desktopLyricToggleAlwaysOnTopMethod),
        ),
        const _ToolbarDivider(),
        _LyricToolButton(
          icon: Icons.text_decrease_rounded,
          tooltip: '减小字体',
          onPressed: () => _invokeControl(desktopLyricDecreaseFontSizeMethod),
        ),
        _LyricToolButton(
          icon: Icons.text_increase_rounded,
          tooltip: '增大字体',
          onPressed: () => _invokeControl(desktopLyricIncreaseFontSizeMethod),
        ),
        const _ToolbarDivider(),
        _LyricToolButton(
          icon: Icons.skip_previous_rounded,
          tooltip: '上一首',
          onPressed: () => _invokeControl(desktopLyricPreviousTrackMethod),
        ),
        _LyricToolButton(
          icon: _payload.isPlaying
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
          tooltip: _payload.isPlaying ? '暂停' : '播放',
          onPressed: () => _invokeControl(desktopLyricTogglePlaybackMethod),
        ),
        _LyricToolButton(
          icon: Icons.skip_next_rounded,
          tooltip: '下一首',
          onPressed: () => _invokeControl(desktopLyricNextTrackMethod),
        ),
        const _ToolbarDivider(),
        _LyricToolButton(
          icon: Icons.lock_outline_rounded,
          tooltip: '锁定歌词',
          onPressed: () => _invokeControl(desktopLyricToggleLockedMethod),
        ),
      ],
    );
  }

  Widget _buildLyricBody(BuildContext context) {
    final settings = _payload.lyricSettings;
    final fontSize = settings.fontSize;
    final lyricColor = settings.textColor;
    final nextLyricColor = settings.textColor.withAlpha(196);

    if (settings.desktopLyricsDoubleLine && _payload.nextLyric.isNotEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          _OutlinedLyricText(
            text: _payload.lyric,
            fontFamily: settings.desktopLyricFontFamily,
            fontSize: fontSize,
            fillColor: lyricColor,
            strokeColor: settings.strokeColor,
            textAlign: TextAlign.left,
            alignment: Alignment.centerLeft,
            fontWeight: FontWeight.w700,
          ),
          const SizedBox(height: _doubleLineGap),
          _OutlinedLyricText(
            text: _payload.nextLyric,
            fontFamily: settings.desktopLyricFontFamily,
            fontSize: fontSize * 0.92,
            fillColor: nextLyricColor,
            strokeColor: settings.strokeColor,
            textAlign: TextAlign.right,
            alignment: Alignment.centerRight,
            fontWeight: FontWeight.w600,
          ),
        ],
      );
    }

    return _OutlinedLyricText(
      text: _payload.lyric,
      fontFamily: settings.desktopLyricFontFamily,
      fontSize: fontSize,
      fillColor: lyricColor,
      strokeColor: settings.strokeColor,
      textAlign: TextAlign.center,
      alignment: Alignment.center,
      fontWeight: FontWeight.w700,
    );
  }
}

class _OutlinedLyricText extends StatelessWidget {
  const _OutlinedLyricText({
    required this.text,
    required this.fontFamily,
    required this.fontSize,
    required this.fillColor,
    required this.strokeColor,
    required this.textAlign,
    required this.alignment,
    required this.fontWeight,
  });

  final String text;
  final String? fontFamily;
  final double fontSize;
  final Color fillColor;
  final Color strokeColor;
  final TextAlign textAlign;
  final Alignment alignment;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    final strokeWidth = (fontSize / 9).clamp(1.5, 4.5);
    final hasStroke = strokeColor.a > 0;
    final baseStyle = TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      height: 1.15,
      fontWeight: fontWeight,
    );
    return Align(
      alignment: alignment,
      child: Stack(
        children: <Widget>[
          if (hasStroke)
            ExcludeSemantics(
              child: Text(
                text,
                textAlign: textAlign,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: baseStyle.copyWith(
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeJoin = StrokeJoin.round
                    ..strokeWidth = strokeWidth
                    ..color = strokeColor,
                ),
              ),
            ),
          Text(
            text,
            textAlign: textAlign,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: baseStyle.copyWith(color: fillColor),
          ),
        ],
      ),
    );
  }
}

class _DesktopLyricToolbar extends StatelessWidget {
  const _DesktopLyricToolbar({required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: actions),
      ),
    );
  }
}

class _LyricToolButton extends StatelessWidget {
  const _LyricToolButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final foreground = active
        ? Theme.of(context).colorScheme.primary
        : Colors.white.withAlpha(232);
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      splashRadius: 18,
      iconSize: 20,
      style: IconButton.styleFrom(
        foregroundColor: foreground,
        backgroundColor: active ? foreground.withAlpha(26) : Colors.transparent,
      ),
      icon: Icon(icon),
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: Colors.white.withAlpha(28),
    );
  }
}

Future<void> configureDesktopLyricWindow() async {
  await windowManager.ensureInitialized();
  const options = WindowOptions(
    size: Size(720, 108),
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    alwaysOnTop: false,
    titleBarStyle: TitleBarStyle.hidden,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.setAsFrameless();
    await windowManager.setBackgroundColor(Colors.transparent);
    await windowManager.setSkipTaskbar(true);
    await windowManager.setResizable(false);
    await windowManager.setHasShadow(false);
    await windowManager.setAlignment(Alignment.center);
    await windowManager.show(inactive: true);
  });
}
