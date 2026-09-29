import '../../downloads/domain/download_audio_format.dart';
import '../../../core/theme/domain/theme_layout_override.dart';
import 'lyric_settings.dart';
import 'shortcut_settings.dart';

class UserSettings {
  const UserSettings({
    required this.cacheSizeBytes,
    required this.cacheDirectoryPath,
    required this.downloadsDirectoryPath,
    required this.downloadAudioFormat,
    required this.shortcuts,
    required this.lyricSettings,
    required this.activeThemeId,
    required this.themeModeOverrideName,
    required this.themeSettingValues,
    required this.themeLayoutOverrides,
    this.sidebarWidth,
    this.playlistOpenAction = PlaylistOpenAction.alwaysAsk,
    this.queuePanelVisible = false,
    this.trayCloseAction = TrayCloseAction.ask,
  });

  static const String defaultActiveThemeId = 'xuan';
  static const String defaultThemeModeOverrideName = 'system';

  final int cacheSizeBytes;
  final String cacheDirectoryPath;
  final String downloadsDirectoryPath;
  final DownloadAudioFormat downloadAudioFormat;
  final ShortcutSettings shortcuts;
  final LyricSettings lyricSettings;

  /// Id of the skin currently applied.
  final String activeThemeId;

  /// `ThemeMode.system` defers to the skin's own brightness preference.
  final String themeModeOverrideName;

  /// User tweaks to skin-declared knobs, keyed by `<themeId>/<settingKey>`.
  final Map<String, Object> themeSettingValues;

  /// L2 layout overrides keyed by theme id.
  ///
  /// Kept beside (not inside) `themeSettingValues` because layout overrides
  /// are structurally different from token knobs: L2 must be validated as an
  /// arrangement, never smuggled through the token patcher.
  final Map<String, ThemeLayoutOverride> themeLayoutOverrides;

  /// User-adjusted desktop rail width in logical pixels.
  ///
  /// `null` means "use the skin's arrangement ratio". Once the user drags the
  /// rail, the explicit value wins so the choice survives a relaunch.
  final double? sidebarWidth;

  /// What playing an online collection does to the current queue.
  ///
  /// `alwaysAsk` is the first-run default: the user sees the choice once and
  /// can pin it, after which the pinned answer is used without a dialog.
  final PlaylistOpenAction playlistOpenAction;

  /// Whether the queue panel was last open, so the next launch restores it
  /// instead of always starting with it docked.
  ///
  /// Only meaningful on desktop, where the panel docks beside the content
  /// rather than opening over it; a phone has no room to remember it.
  final bool queuePanelVisible;

  /// Whether the close button asks before minimizing to tray.
  ///
  /// The first close offers a real choice; once answered, it remembers the
  /// decision and stops interrupting until changed in settings.
  final TrayCloseAction trayCloseAction;

  UserSettings copyWith({
    int? cacheSizeBytes,
    String? cacheDirectoryPath,
    String? downloadsDirectoryPath,
    DownloadAudioFormat? downloadAudioFormat,
    ShortcutSettings? shortcuts,
    LyricSettings? lyricSettings,
    String? activeThemeId,
    String? themeModeOverrideName,
    Map<String, Object>? themeSettingValues,
    Map<String, ThemeLayoutOverride>? themeLayoutOverrides,
    Object? sidebarWidth = _sidebarWidthSentinel,
    TrayCloseAction? trayCloseAction,
  }) {
    return UserSettings(
      cacheSizeBytes: cacheSizeBytes ?? this.cacheSizeBytes,
      cacheDirectoryPath: cacheDirectoryPath ?? this.cacheDirectoryPath,
      downloadsDirectoryPath:
          downloadsDirectoryPath ?? this.downloadsDirectoryPath,
      downloadAudioFormat: downloadAudioFormat ?? this.downloadAudioFormat,
      shortcuts: shortcuts ?? this.shortcuts,
      lyricSettings: lyricSettings ?? this.lyricSettings,
      activeThemeId: activeThemeId ?? this.activeThemeId,
      themeModeOverrideName:
          themeModeOverrideName ?? this.themeModeOverrideName,
      themeSettingValues: themeSettingValues ?? this.themeSettingValues,
      themeLayoutOverrides: themeLayoutOverrides ?? this.themeLayoutOverrides,
      sidebarWidth: identical(sidebarWidth, _sidebarWidthSentinel)
          ? this.sidebarWidth
          : sidebarWidth as double?,
      playlistOpenAction: playlistOpenAction,
      queuePanelVisible: queuePanelVisible,
      trayCloseAction: trayCloseAction ?? this.trayCloseAction,
    );
  }
}

const Object _sidebarWidthSentinel = Object();

/// How opening an online collection (ranking / recommend sheet) affects the
/// queue.
///
/// The first open has to ask — appending to a queue the user is listening to
/// and replacing it are both reasonable, and guessing wrong loses either the
/// collection or the queue. Once answered, the choice is remembered and the
/// dialog stops interrupting.
enum PlaylistOpenAction {
  /// Show the choice every time.
  alwaysAsk,

  /// Keep the current queue and append the collection after it.
  append,

  /// Drop the current queue and start the collection from its first track.
  replace,
}

/// What the desktop close button should do after the first prompt.
enum TrayCloseAction {
  /// Show the one-time choice until the user answers it.
  ask,

  /// Hide to tray and keep playing.
  minimizeToTray,

  /// Quit the app.
  exit,
}
