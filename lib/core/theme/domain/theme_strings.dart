/// Skin-declared text for the shell's own chrome.
///
/// A skin describes what the navigation rail, the queue panel and the search
/// field say. This is deliberately **not** a localisation system: there are no
/// plurals, no dates, no number formatting, and feature pages keep their own
/// copy. The question these slots answer is narrower and skin-shaped — "the
/// design is written in Chinese, so why does the rail still say `Discover`?"
///
/// The key set is closed for the same reason the region set is: a skin may
/// rename what the app already renders, but it cannot invent chrome. An
/// unknown key is dropped at parse time and the app falls back to the same
/// slot's default, so a skin written against a newer app cannot break an older
/// one.
library;

import 'package:flutter/material.dart';

import '../infrastructure/token_resolver.dart';

/// The chrome strings a skin may override.
///
/// Every value carries the neutral default, which is also the single source of
/// truth for call sites: the shell asks for a slot and gets whatever is in
/// effect, never a literal of its own.
enum ThemeStringKey {
  // Navigation rail.
  navSearch('nav.search', 'Search'),
  navDiscover('nav.discover', 'Discover'),
  navLibrary('nav.library', 'Library'),
  navNowPlaying('nav.nowPlaying', 'Now Playing'),
  navLiked('nav.liked', 'Liked songs'),
  navPlaylists('nav.playlists', 'Playlists'),
  navDownloads('nav.downloads', 'Downloads'),
  navPlugins('nav.plugins', 'Plugins'),
  navSettings('nav.settings', 'Settings'),
  navSectionPlaylists('nav.section.playlists', 'My playlists'),
  navPlaylistsEmpty('nav.playlists.empty', 'No playlists yet'),

  /// The secondary group's heading in the rail ("工具" in the design).
  ///
  /// The rail groups its destinations by intent — browse, collections,
  /// personal library, then tools — and the heading is part of that
  /// composition, so it belongs to the skin rather than to the widget.
  navSectionTools('nav.section.tools', 'Tools'),

  /// The rail's footer lockup: the product line and its build marker.
  navFooter('nav.footer', 'Robyne MVP'),
  navFooterVersion('nav.footer.version', 'v0.1'),

  /// The overflow entry's own label.
  navMore('nav.more', 'More'),

  // Brand lockup and the profile block above the rail.
  railBrand('rail.brand', 'Robyne'),
  railProfileName('rail.profile.name', 'Listener'),
  railProfileSubtitle('rail.profile.subtitle', 'Local library'),

  /// The library row's trailing count in the rail.
  railLibraryCount('rail.library.count', '{count}'),

  /// The liked-songs row's trailing count in the rail.
  railLikedCount('rail.liked.count', '{count}'),

  /// The downloads row's trailing count in the rail.
  railDownloadsCount('rail.downloads.count', '{count}'),

  /// The plugins row's trailing count in the rail.
  railPluginsCount('rail.plugins.count', '{count}'),

  // Phone tab strip. These are separate slots from the rail on purpose: the
  // design labels the same destination `我喜欢` on a desktop rail and `我的`
  // in a phone tab, and collapsing them would lose that distinction.
  tabDiscover('tab.discover', 'Discover'),
  tabLibrary('tab.library', 'Library'),
  tabSearch('tab.search', 'Search'),
  tabMine('tab.mine', 'Mine'),

  // Top bar.
  searchHint('search.hint', 'Search songs, artists, albums'),
  searchAction('search.action', 'Search'),
  searchStop('search.stop', 'Stop'),

  // Queue panel.
  queueTitle('queue.title', 'Now playing'),

  /// The queue's item count. `{count}` is replaced with the number.
  ///
  /// Exactly one placeholder is supported and no pluralisation is attempted:
  /// the design is written in a language without plural agreement, and
  /// building a plural engine here would be inventing a localisation system
  /// under a skin system's name. An English skin that wants "1 song" instead
  /// of "1 songs" should omit the word.
  queueCount('queue.count', '{count} songs'),
  queueTabQueue('queue.tab.queue', 'Queue'),
  queueTabLiked('queue.tab.liked', 'Liked'),
  queueEmpty('queue.empty', 'The queue is empty'),
  queueLikedEmpty('queue.likedEmpty', 'No liked songs yet'),
  queueClear('queue.clear', 'Clear queue'),
  queueCollapse('queue.collapse', 'Collapse queue'),
  queueShow('queue.show', 'Show queue'),
  queueHide('queue.hide', 'Hide queue'),

  // Library page header, which the shell frames rather than owns.
  libraryTitle('library.title', 'Library'),

  // Appearance panel: brightness override labels.
  appearanceModeSystem('appearance.mode.system', 'Follow skin'),
  appearanceModeLight('appearance.mode.light', 'Light'),
  appearanceModeDark('appearance.mode.dark', 'Dark'),

  // Player bar tooltips and the immersive player's close affordance.
  playerBack('player.back', 'Back'),
  playerNothingPlaying('player.nothingPlaying', 'Nothing playing'),
  nowPlayingClose('nowPlaying.close', 'Back to library'),
  playerPlay('player.play', 'Play'),
  playerPause('player.pause', 'Pause'),
  playerPrevious('player.previous', 'Previous'),
  playerNext('player.next', 'Next'),
  playerAddToLiked('player.like.add', 'Add to liked'),
  playerRemoveFromLiked('player.like.remove', 'Remove from liked'),
  playerMore('player.more', 'More'),
  playerDownload('player.download', 'Download'),
  playerStopPlayback('player.stopPlayback', 'Stop playback'),
  playerQueue('player.queue', 'Play queue'),
  playerVolume('player.volume', 'Volume'),

  /// The title-bar entry that collapses the shell into the floating capsule.
  ///
  /// The capsule is a *window state*, so its label belongs with the other
  /// title-bar chrome rather than with a feature page: a skin that writes its
  /// own language should not have to accept an English tooltip on a button the
  /// shell itself draws.
  playerCapsuleEnter('player.capsule.enter', 'Capsule mode'),

  /// The capsule's own close affordance: it restores the full shell.
  playerCapsuleExit('player.capsule.exit', 'Restore window'),

  /// The capsule's trailing button: it toggles the playlist panel below.
  playerCapsuleQueue('player.capsule.queue', 'Playlist'),

  /// Heading of the panel the capsule unfolds under itself.
  playerCapsulePlaylist('player.capsule.playlist', 'Playlist'),

  /// Shown when the capsule has nothing queued to list.
  playerCapsulePlaylistEmpty(
    'player.capsule.playlistEmpty',
    'The playlist is empty',
  ),

  playerShowDesktopLyric('player.desktopLyric.show', 'Show desktop lyric'),
  playerHideDesktopLyric('player.desktopLyric.hide', 'Hide desktop lyric'),
  playerSearchLyric('player.lyric.search', 'Search and link lyric'),
  playerLinkLocalLyric('player.lyric.linkLocal', 'Link local lyric file'),
  playerAddToPlaylist('player.playlist.add', 'Add to playlist'),
  playerClearLyricLink('player.lyric.clearLink', 'Clear lyric link'),
  playerLyricOffset('player.lyric.offset', 'Lyric offset'),
  playerLyricOffsetHint(
    'player.lyric.offsetHint',
    'Drag to shift lyric timing in real time.',
  ),
  playerLyricsEmpty('player.lyrics.empty', 'No lyrics linked.'),
  playerLyricsDisabled(
    'player.lyrics.disabled',
    'Lyrics temporarily disabled.',
  ),
  playerPlaylistEmpty('player.playlist.empty', 'Create a playlist first.'),
  playerSearchLyricsTitle('player.lyrics.searchTitle', 'Search lyrics'),
  playerLyricPluginsEmpty('player.lyrics.pluginsEmpty', 'No lyric plugins.'),
  playerSearchLyricAction('player.lyrics.searchAction', 'Search'),
  playerSearchLyricStop('player.lyrics.searchStop', 'Stop'),
  playerAddToLikedShort('player.like.addShort', 'Add to liked'),
  playerRemoveFromLikedShort('player.like.removeShort', 'Remove from liked'),
  nowPlayingTabNow('nowPlaying.tab.now', 'Now'),
  nowPlayingTabLyrics('nowPlaying.tab.lyrics', 'Lyrics'),
  // The quality chip labels two buckets, not the plugin's free-form strings.
  qualityLossless('quality.lossless', 'Lossless'),
  qualityStandard('quality.standard', 'Standard'),
  qualityUnknown('quality.unknown', 'Unknown quality'),
  qualityTooltip('quality.tooltip', 'Quality: {quality}'),

  // Discover / library shelf chrome that the shell frames.
  discoverMore('discover.more', 'Explore more'),

  /// The design's labelled entry into the plugin rankings browser.
  ///
  /// The mockup puts a named pill ("插件榜单") on the home header rather than
  /// a bare glyph, because a secondary surface needs a name to be
  /// discoverable.
  discoverRankingEntry('discover.rankingEntry', 'Rankings'),
  discoverBack('discover.back', 'Back to home'),

  // The plugin rankings browser's own chrome. It is a secondary surface, but
  // its headings, tabs and empty states are still chrome text: a skin that
  // writes its own language should not have to accept "Sources" for 来源.
  discoverSources('discover.sources', 'Sources'),
  discoverRankings('discover.rankings', 'Rankings'),
  discoverHotPlaylists('discover.hotPlaylists', 'Hot playlists'),
  discoverSheetTags('discover.sheetTags', 'Playlist tags'),
  discoverMoreTags('discover.moreTags', 'More tags'),
  discoverRefresh('discover.refresh', 'Refresh'),
  discoverEnablePlugin(
    'discover.enablePlugin',
    'Enable a plugin to browse rankings and playlists',
  ),
  discoverEmptyRankings('discover.emptyRankings', 'No rankings'),
  discoverEmptyPlaylists('discover.emptyPlaylists', 'No playlists'),
  discoverChooseCollection(
    'discover.chooseCollection',
    'Choose a ranking or playlist',
  ),
  discoverRetry('discover.retry', 'Retry'),
  discoverBackToBrowse('discover.backToBrowse', 'Back to list'),
  discoverPlay('discover.play', 'Play'),
  discoverDownload('discover.download', 'Download'),
  discoverMoreActions('discover.moreActions', 'More'),
  discoverTagSheetTitle('discover.tagSheetTitle', 'Playlist tags'),

  /// The detail panel's track count. `{count}` is replaced with the number.
  discoverTrackCount('discover.trackCount', '{count} tracks'),
  discoverPlayCollection('discover.playCollection', 'Play collection'),
  discoverFavoriteCollection(
    'discover.favoriteCollection',
    'Favourite collection',
  ),
  discoverUnfavoriteCollection(
    'discover.unfavoriteCollection',
    'Remove favourite',
  ),
  discoverFavoriteCollectionFailed(
    'discover.favoriteCollectionFailed',
    'Could not load this collection. Nothing was saved.',
  ),

  // Playing a whole collection asks once how it should join the queue. Both
  // answers are reasonable and neither is recoverable, so the copy has to say
  // what each one costs.
  collectionPlayTitle('collection.playTitle', 'Add this collection?'),

  /// `{title}` is the collection name, `{count}` its track count.
  collectionPlayPrompt(
    'collection.playPrompt',
    'How should "{title}" ({count} tracks) join the queue?',
  ),
  collectionPlayAppend('collection.playAppend', 'Add to queue'),
  collectionPlayAppendHint(
    'collection.playAppendHint',
    'Keep playing, then play these tracks',
  ),
  collectionPlayReplace('collection.playReplace', 'Replace queue'),
  collectionPlayReplaceHint(
    'collection.playReplaceHint',
    'Stop now and start this collection',
  ),
  collectionPlayRemember(
    'collection.playRemember',
    'Use this choice from now on (changeable in Settings)',
  ),
  settingsPlaylistAction('settings.playlistAction', 'When playing a playlist'),
  settingsPlaylistActionAsk('settings.playlistActionAsk', 'Always ask'),
  settingsPlaylistActionAppend('settings.playlistActionAppend', 'Add to queue'),
  settingsPlaylistActionReplace(
    'settings.playlistActionReplace',
    'Replace queue',
  ),
  librarySubtitle('library.subtitle', 'Local library, available offline'),
  libraryImportFiles('library.importFiles', 'Import files'),
  libraryImportFolder('library.importFolder', 'Import folder'),
  libraryEmpty('library.empty', 'No local music imported'),

  // Search surface chrome. The shell's top bar owns the entry pill, but the
  // page itself has its own empty/heading copy, result tabs and row actions
  // that a skin should be able to rename.
  searchPageTitle('search.pageTitle', 'Search'),
  searchPageSubtitle('search.pageSubtitle', 'Search songs, artists, albums'),
  searchEmpty('search.empty', 'Import a plugin, then search music'),
  searchEmptyResults('search.emptyResults', 'No results'),
  searchResultCount('search.resultCount', '{count}'),
  searchResultErrorSuffix('search.resultErrorSuffix', '{platform} failed'),
  searchResultLoadingSuffix('search.resultLoadingSuffix', '{platform} …'),
  searchPlay('search.play', 'Play'),
  searchDownload('search.download', 'Download'),
  searchMoreActions('search.moreActions', 'More'),
  searchHistoryTitle('search.historyTitle', 'Recent searches'),
  searchHistoryEmpty('search.historyEmpty', 'No recent searches'),
  searchHistoryClearAll('search.historyClearAll', 'Clear all'),
  searchHistoryRemove('search.historyRemove', 'Remove'),
  searchHistoryClearAllTitle('search.historyClearAllTitle', 'Clear search history'),
  searchHistoryClearAllMessage(
    'search.historyClearAllMessage',
    'Remove every remembered search keyword? This cannot be undone.',
  ),

  // Playback mode names. The queue picker and the player bar read the same
  // slots, so a skin renames a mode once and it changes everywhere.
  modeSequence('mode.sequence', 'Sequence'),
  modeRandom('mode.random', 'Random'),
  modeAllLoop('mode.allLoop', 'Loop all'),
  modeSingleLoop('mode.singleLoop', 'Loop one'),
  modeTooltip('mode.tooltip', 'Playback mode'),

  // The queue/history page's own chrome. The docked queue panel has its slots
  // above; these are the full-page surface's headings and actions.
  queuePageTitle('queue.pageTitle', 'Queue'),
  queueTabHistory('queue.tab.history', 'History'),
  queueHistoryEmpty('queue.historyEmpty', 'History is empty'),
  queueClearHistory('queue.clearHistory', 'Clear history'),
  queueRemove('queue.remove', 'Remove'),

  // Downloads surface chrome.
  downloadsTitle('downloads.title', 'Downloads'),
  downloadsEmpty('downloads.empty', 'No downloads'),
  downloadsTabActive('downloads.tab.active', 'Downloading'),
  downloadsTabCompleted('downloads.tab.completed', 'Completed'),
  downloadsStatusQueued('downloads.status.queued', 'Queued'),
  downloadsStatusDownloading(
    'downloads.status.downloading',
    'Downloading {percent}%',
  ),
  downloadsStatusConverting('downloads.status.converting', 'Converting'),
  downloadsStatusCompleted('downloads.status.completed', 'Completed'),
  downloadsStatusFailed('downloads.status.failed', 'Failed'),
  downloadsPlay('downloads.play', 'Play'),
  downloadsRetry('downloads.retry', 'Retry'),
  downloadsDelete('downloads.delete', 'Delete'),

  // Playlists surface chrome.
  playlistsTitle('playlists.title', 'Playlists'),
  playlistsLikedTitle('playlists.likedTitle', 'Liked songs'),
  playlistsOwnedTab('playlists.ownedTab', 'Created'),
  playlistsCollectionsTab('playlists.collectionsTab', 'Saved'),
  playlistsAll('playlists.all', 'All playlists'),
  playlistsNew('playlists.new', 'New playlist'),
  playlistsEmpty('playlists.empty', 'No playlists'),
  playlistsTrackCount('playlists.trackCount', '{count} tracks'),
  playlistsEmptyTracks('playlists.emptyTracks', 'No tracks'),
  playlistsNewTitle('playlists.newTitle', 'New playlist'),
  playlistsRename('playlists.rename', 'Rename'),
  playlistsDelete('playlists.delete', 'Delete'),
  playlistsDeleteTitle('playlists.deleteTitle', 'Delete playlist'),
  playlistsDeleteMessage('playlists.deleteMessage', 'Delete "{name}"?'),
  playlistsRemoveTitle('playlists.removeTitle', 'Remove track'),
  playlistsRemoveMessage(
    'playlists.removeMessage',
    'Remove "{track}" from "{playlist}"?',
  ),
  playlistsNameField('playlists.nameField', 'Name'),

  // Plugin surface chrome.
  pluginsTitle('plugins.title', 'Plugins'),
  pluginsImportFiles('plugins.importFiles', 'Import files'),
  pluginsImportFolder('plugins.importFolder', 'Import folder'),
  pluginsImportUrl('plugins.importUrl', 'Import from URL'),
  pluginsEmpty('plugins.empty', 'No installed plugins yet'),
  pluginsSubtitle(
    'plugins.subtitle',
    'Import MusicFree-style JavaScript plugins from local files, folders, or URLs',
  ),
  pluginsNoJsFiles('plugins.noJsFiles', 'No JavaScript plugin files found'),
  pluginsConfigureTooltip('plugins.configureTooltip', 'Configure'),
  pluginsChooseFolder('plugins.chooseFolder', 'Choose plugin folder'),
  pluginsImportPreparing(
    'plugins.importPreparing',
    'Preparing plugin import...',
  ),
  pluginsImportProgress(
    'plugins.importProgress',
    'Importing {file} ({done}/{total})',
  ),
  pluginsImportSummary(
    'plugins.importSummary',
    'Imported {imported}, updated {updated}, skipped {skipped}',
  ),
  pluginsImportFailed(
    'plugins.importFailed',
    '{count} failed. {code}: {message}',
  ),
  pluginsImportUrlTitle('plugins.importUrlTitle', 'Import plugin from URL'),
  pluginsUrlField('plugins.urlField', 'Plugin URL'),
  pluginsUrlHint('plugins.urlHint', 'https://example.com/plugin.js'),
  pluginsUrlInvalid('plugins.urlInvalid', 'Enter an http:// or https:// URL'),
  pluginsImport('plugins.import', 'Import'),
  pluginsConfigure('plugins.configure', 'Configure {platform}'),
  pluginsSave('plugins.save', 'Save'),
  pluginsEnable('plugins.enable', 'Enable'),
  pluginsDisable('plugins.disable', 'Disable'),
  pluginsDelete('plugins.delete', 'Delete'),
  pluginsSortTooltip('plugins.sortTooltip', 'Sort plugins'),

  /// The user's own dragged arrangement. First in the enum because it is the
  /// only order that is stored: the other modes are views over it.
  pluginsSortManual('plugins.sort.manual', 'My order'),
  pluginsSortAdded('plugins.sort.added', 'Date added'),
  pluginsSortName('plugins.sort.name', 'Name'),
  pluginsSortEnabled('plugins.sort.enabled', 'Enabled first'),
  pluginsSortUpdated('plugins.sort.updated', 'Recently updated'),

  /// Tells the user the rows can be dragged, shown while [pluginsSortManual]
  /// is the active order.
  pluginsSortDragHint('plugins.sort.dragHint', 'Drag a row to reorder'),

  /// Tooltip on the row's drag handle.
  pluginsDragHandle('plugins.dragHandle', 'Drag to reorder'),

  // Shared dialog actions, used by several surfaces.
  actionCancel('action.cancel', 'Cancel'),
  actionRetry('action.retry', 'Retry'),
  actionRemove('action.remove', 'Remove'),
  actionClear('action.clear', 'Clear'),
  actionCreate('action.create', 'Create'),

  // Settings surface chrome. The tab names and every row's copy are skin
  // text: a skin that ships in another language should not have to accept
  // hard-coded Chinese for "常规" or "快捷键".
  settingsTitle('settings.title', 'Settings'),
  settingsTabGeneral('settings.tab.general', 'General'),
  settingsTabAppearance('settings.tab.appearance', 'Appearance'),
  settingsTabShortcuts('settings.tab.shortcuts', 'Shortcuts'),
  settingsTabLyrics('settings.tab.lyrics', 'Lyrics'),

  // General tab.
  settingsCacheSize('settings.cacheSize', 'Cache size'),
  settingsCacheLocation('settings.cacheLocation', 'Cache location'),
  settingsDownloadLocation('settings.downloadLocation', 'Download location'),
  settingsDownloadFormat('settings.downloadFormat', 'Download format'),
  settingsCacheSizeDialog('settings.cacheSizeDialog', 'Cache size'),
  settingsSizeField('settings.sizeField', 'Size'),
  settingsChooseCacheLocation(
    'settings.chooseCacheLocation',
    'Choose cache location',
  ),
  settingsChooseDownloadLocation(
    'settings.chooseDownloadLocation',
    'Choose download location',
  ),
  settingsDirectoryPickerFailed(
    'settings.directoryPickerFailed',
    'Could not open the directory picker: {error}',
  ),
  settingsDirectoryManualTitle(
    'settings.directoryManualTitle',
    'Enter a directory path',
  ),
  settingsDirectoryField('settings.directoryField', 'Folder path'),

  // Lyrics tab.
  settingsLyricsShowDesktop(
    'settings.lyrics.showDesktop',
    'Show desktop lyrics',
  ),
  settingsLyricsShowDesktopSub(
    'settings.lyrics.showDesktopSub',
    'Synced with the desktop window and the player',
  ),
  settingsLyricsAlwaysOnTop('settings.lyrics.alwaysOnTop', 'Keep on top'),
  settingsLyricsAlwaysOnTopSub(
    'settings.lyrics.alwaysOnTopSub',
    'The lyric window stays in front',
  ),
  settingsLyricsLocked('settings.lyrics.locked', 'Lock desktop lyrics'),
  settingsLyricsLockedSub(
    'settings.lyrics.lockedSub',
    'The window cannot be dragged once locked',
  ),
  settingsLyricsDoubleLine('settings.lyrics.doubleLine', 'Two-line mode'),
  settingsLyricsDoubleLineSub(
    'settings.lyrics.doubleLineSub',
    'Show the current and next line side by side',
  ),
  settingsLyricsFont('settings.lyrics.font', 'Lyric font'),
  settingsLyricsFontSub(
    'settings.lyrics.fontSub',
    'Font used by the desktop lyric window',
  ),
  settingsLyricsFontSize('settings.lyrics.fontSize', 'Lyric font size'),
  settingsLyricsFontSizeSub(
    'settings.lyrics.fontSizeSub',
    'Desktop lyric size ({min}-{max})',
  ),
  settingsLyricsColor('settings.lyrics.color', 'Lyric colour'),
  settingsLyricsColorSub(
    'settings.lyrics.colorSub',
    'Fill colour of the active line',
  ),
  settingsLyricsStroke('settings.lyrics.stroke', 'Lyric outline colour'),
  settingsLyricsStrokeSub(
    'settings.lyrics.strokeSub',
    'Outline drawn around the lyric text',
  ),
  settingsLyricsDecreaseFont('settings.lyrics.decreaseFont', 'Decrease size'),
  settingsLyricsIncreaseFont('settings.lyrics.increaseFont', 'Increase size'),
  settingsLyricsNoStroke('settings.lyrics.noStroke', 'No outline'),
  settingsLyricsFontDefault('settings.lyrics.fontDefault', 'Default'),

  // Shortcuts tab.
  settingsShortcutScope('settings.shortcut.scope', 'In-app'),
  settingsShortcutUnset('settings.shortcut.unset', 'Unset'),
  settingsShortcutClear('settings.shortcut.clear', 'Clear'),
  settingsShortcutEditTitle('settings.shortcut.editTitle', 'Set {action}'),
  settingsShortcutHint(
    'settings.shortcut.hint',
    'Click the area below, then press the key or combination to bind',
  ),
  settingsShortcutSingle('settings.shortcut.single', 'Single tap'),
  settingsShortcutDouble('settings.shortcut.double', 'Double tap'),
  settingsShortcutPress('settings.shortcut.press', 'Press a shortcut'),
  settingsShortcutListening(
    'settings.shortcut.listening',
    'Listening for keyboard input',
  ),
  settingsShortcutStartRecording(
    'settings.shortcut.startRecording',
    'Click this area to start recording',
  ),
  settingsShortcutConflict(
    'settings.shortcut.conflict',
    'Conflicts with "{action}", pick different keys',
  ),
  settingsShortcutConflictSaved(
    'settings.shortcut.conflictSaved',
    'Conflicts with "{action}", not saved',
  ),

  // Appearance tab. These are the panel's own headings and its explanatory
  // copy; the skin list and token preview below them are data.
  settingsAppearanceLoadFailed(
    'settings.appearance.loadFailed',
    'Failed to load the skin',
  ),
  settingsAppearanceMode('settings.appearance.mode', 'Appearance mode'),
  settingsAppearanceActive('settings.appearance.active', 'Active skin'),
  settingsAppearanceSpec('settings.appearance.spec', 'Design notes'),
  settingsAppearanceSpecBody(
    'settings.appearance.specBody',
    'The flagship skin is driven by its bundled theme.json. Colours, radii, '
        'layout, images and fonts are all declared by the skin package; the '
        'client only renders them',
  ),
  settingsAppearanceTokens('settings.appearance.tokens', 'Active tokens'),
  settingsAppearanceDirectoryUnavailable(
    'settings.appearance.directoryUnavailable',
    'The skin directory is unavailable',
  ),

  // Tray menu and the first-close confirmation. The tray is native chrome, but
  // its wording still belongs to the skin so a different language skin does
  // not fall back to Chinese labels inside a native surface.
  trayMyFavorite('tray.myFavorite', 'Liked'),
  trayQueue('tray.queue', 'Queue'),
  trayVolume('tray.volume', 'Volume {volume}'),
  trayDesktopLyrics('tray.desktopLyrics', 'Desktop lyrics'),
  trayExit('tray.exit', 'Exit'),
  trayCloseTitle('tray.close.title', 'Close Robyne'),
  trayCloseBody(
    'tray.close.body',
    'Robyne will keep playing in the tray. Do you want to exit instead?',
  ),
  trayCloseMinimize('tray.close.minimize', 'Minimize to tray'),
  trayCloseExit('tray.close.exit', 'Exit'),

  // Close button behaviour, editable after the first prompt.
  settingsTrayCloseAction('settings.tray.closeAction', '关闭按钮行为'),
  settingsTrayCloseAsk('settings.tray.closeAsk', '每次询问'),
  settingsTrayCloseMinimize('settings.tray.closeMinimize', '最小化到托盘'),
  settingsTrayCloseExit('settings.tray.closeExit', '退出 Robyne'),
  settingsTrayCloseSub('settings.tray.closeSub', '点击窗口关闭按钮时执行的操作');

  const ThemeStringKey(this.jsonKey, this.fallback);

  /// The dotted name a skin writes in `theme.json`.
  ///
  /// Dotted rather than the enum's own name so the manifest reads like the
  /// token paths authors already use (`components.lyric.activeLine`).
  final String jsonKey;

  /// What the app shows when the skin says nothing.
  final String fallback;

  static ThemeStringKey? fromJsonKey(String? key) {
    if (key == null) {
      return null;
    }
    for (final value in values) {
      if (value.jsonKey == key) {
        return value;
      }
    }
    return null;
  }
}

/// The chrome strings in effect, resolved against the skin's declarations.
///
/// Immutable and total: [resolve] never returns null, so no call site needs a
/// fallback of its own and no missing key can render an empty label.
class ThemeStrings {
  const ThemeStrings(this._values);

  const ThemeStrings.empty() : _values = const <ThemeStringKey, String>{};

  final Map<ThemeStringKey, String> _values;

  /// True when the skin declares nothing, which the appearance panel reports
  /// as "this skin uses the default wording".
  bool get isEmpty => _values.isEmpty;

  /// The live strings for the active skin from the widget's resolved theme.
  ///
  /// Used by callbacks that survive navigation (the tray controller) where a
  /// Riverpod `ref` is not available, but a valid context still is.
  static ThemeStrings of(BuildContext context) {
    final strings = RobyneTheme.maybeOf(context)?.strings;
    return strings ?? const ThemeStrings.empty();
  }

  /// The text for [key]: the skin's value when it declared one, otherwise the
  /// slot's default.
  String resolve(ThemeStringKey key) => _values[key] ?? key.fallback;

  /// The skin's declaration for [key], or null when it stayed silent.
  String? declared(ThemeStringKey key) => _values[key];

  /// Parses the manifest's `strings` object.
  ///
  /// Unknown keys and non-string values are dropped rather than rejected: a
  /// skin authored for a newer app still loads, just with the defaults it does
  /// not understand. Values are trimmed and length-capped by the caller, which
  /// owns the untrusted-input budget.
  static ThemeStrings parse(
    Object? raw, {
    String? Function(Object? value, int maxLength)? readText,
    int maxLength = 64,
  }) {
    if (raw is! Map) {
      return const ThemeStrings.empty();
    }
    final read = readText ?? _defaultReadText;
    final values = <ThemeStringKey, String>{};
    for (final entry in raw.entries) {
      final key = ThemeStringKey.fromJsonKey(entry.key?.toString().trim());
      if (key == null) {
        continue;
      }
      final text = read(entry.value, maxLength);
      if (text != null && text.isNotEmpty) {
        values[key] = text;
      }
    }
    if (values.isEmpty) {
      return const ThemeStrings.empty();
    }
    return ThemeStrings(Map<ThemeStringKey, String>.unmodifiable(values));
  }

  /// Serialises back to the manifest shape, for export and round-trip tests.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      for (final entry in _values.entries) entry.key.jsonKey: entry.value,
    };
  }

  /// The parser's `_bounded`, so manifests are screened exactly once and by one
  /// rule. Kept as a seam so [ThemeStrings] stays free of parser internals.
  static String? _defaultReadText(Object? value, int maxLength) {
    if (value == null) {
      return null;
    }
    if (value is! String && value is! num && value is! bool) {
      return null;
    }
    final text = value.toString().trim();
    if (text.isEmpty) {
      return null;
    }
    return text.length > maxLength ? text.substring(0, maxLength) : text;
  }

  @override
  bool operator ==(Object other) {
    if (other is! ThemeStrings || other._values.length != _values.length) {
      return false;
    }
    for (final entry in _values.entries) {
      if (other._values[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode {
    // Map iteration order is insertion order, and manifests are parsed in the
    // same order, but sorting by key keeps equality independent of that.
    final entries = _values.entries.toList()
      ..sort((a, b) => a.key.index.compareTo(b.key.index));
    return Object.hashAll(<Object>[
      for (final entry in entries) ...<Object>[entry.key, entry.value],
    ]);
  }
}
