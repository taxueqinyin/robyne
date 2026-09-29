import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../presentation/theme_backdrop.dart' show themeBackdropProvider;
import 'theme_controller.dart';
import 'theme_providers.dart';

/// Watches user skin directories and hot-reloads the active skin.
///
/// The roadmap deliberately keeps skin authoring in `theme.json` rather than
/// a bespoke editor. That only works if editing the file is pleasant, so the
/// app watches `<themes>/<skin-id>/theme.json` (and any sibling asset) and
/// re-reads the skin after a short quiet period.
///
/// Design notes:
/// - Editors write files in several steps (write temp, rename, truncate), so
///   a naive listener fires mid-write and parses a half-written manifest.
///   A debounce collapses a burst into one reload.
/// - A failed reload keeps the previous good package: [ThemeController]
///   already has that fallback policy, and this service never replaces it.
/// - The watcher is recursive and directory-level, because a skin may add
///   artwork while the app is running.
class ThemeHotReloadService {
  ThemeHotReloadService({
    this.ref,
    this.debounce = const Duration(milliseconds: 250),
    Directory? watchRoot,
    Future<void> Function()? onReload,
  }) : _watchRoot = watchRoot,
       _onReload = onReload;

  /// Provider reference. Null in tests that inject [watchRoot]/[onReload].
  final Ref? ref;

  final Duration debounce;

  final Directory? _watchRoot;
  final Future<void> Function()? _onReload;

  StreamSubscription<FileSystemEvent>? _subscription;
  Timer? _timer;
  Directory? _watchedRoot;

  /// Starts watching. Safe to call more than once.
  Future<void> start() async {
    if (_subscription != null) {
      return;
    }
    try {
      final providerRef = ref;
      final root =
          _watchRoot ??
          await providerRef!
              .read(themeRepositoryProvider)
              .userThemesDirectory();
      if (!await root.exists()) {
        await root.create(recursive: true);
      }
      _watchedRoot = root;
      _subscription = root
          .watch(recursive: true)
          .listen(
            _onEvent,
            onError: (_) {
              // A watcher failure must never break the app; the next edit simply
              // will not hot-reload until the app restarts.
            },
          );
    } on Object {
      // Platforms without a user-theme directory (or without watch support)
      // simply do not get hot reload.
    }
  }

  /// Stops watching and cancels any pending reload.
  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }

  void _onEvent(FileSystemEvent event) {
    final root = _watchedRoot;
    if (root == null || !_isRelevant(root, event.path)) {
      return;
    }
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(_reload()));
  }

  /// Manifest and asset edits matter; editor scratch/backup files do not.
  bool _isRelevant(Directory root, String path) {
    final relative = p.relative(path, from: root.path);
    if (relative.startsWith('..')) {
      return false;
    }
    final basename = p.basename(path);
    if (basename.startsWith('.') || basename.endsWith('~')) {
      return false;
    }
    return true;
  }

  Future<void> _reload() async {
    final injected = _onReload;
    if (injected != null) {
      await injected();
      return;
    }
    final providerRef = ref;
    if (providerRef == null || !providerRef.mounted) {
      return;
    }
    // Re-reads the catalog and re-resolves the active id. A manifest that is
    // still mid-write parses to null, the controller keeps the last good
    // package, and the next edit triggers another attempt.
    await providerRef.read(themeControllerProvider.notifier).refresh();
    if (!providerRef.mounted) {
      return;
    }
    providerRef.invalidate(themeBackdropProvider);
    providerRef.invalidate(activeSkinFontFamilyProvider);
  }
}

/// Keeps a hot-reload watcher alive for the lifetime of the app.
final themeHotReloadProvider = Provider<ThemeHotReloadService>((ref) {
  final service = ThemeHotReloadService(ref: ref);
  ref.onDispose(() {
    unawaited(service.dispose());
  });
  unawaited(service.start());
  return service;
});
