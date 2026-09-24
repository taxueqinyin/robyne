import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/plugin/application/plugin_providers.dart';
import '../../../features/settings/application/settings_providers.dart';
import '../domain/theme_layout.dart';
import '../domain/theme_package.dart';
import '../domain/theme_tokens.dart';
import '../infrastructure/theme_repository.dart';
import 'theme_providers.dart';

/// Aggregates built-in and user themes into one list.
final themeRepositoryProvider = Provider<ThemeRepository>((ref) {
  return _CompositeThemeRepository(
    const BuiltInThemeRepository(),
    FileThemeRepository(fileStore: ref.watch(localFileStoreProvider)),
  );
});

/// Controls which skin is active.
///
/// ## Fallback policy
/// A skin that fails to load must never leave the app without a theme. The
/// controller therefore remembers the last theme that loaded successfully and
/// falls back to that one, not to the built-in default. Only when no theme has
/// ever loaded successfully does it use the built-in light skin.
final themeControllerProvider =
    AsyncNotifierProvider<ThemeController, ThemeState>(ThemeController.new);

/// The active skin plus the catalog of available skins.
class ThemeState {
  const ThemeState({
    required this.package,
    required this.available,
    required this.lastError,
  });

  final ThemePackage package;
  final List<ThemePackage> available;

  /// Set when the requested skin could not be loaded and a fallback was used.
  final String? lastError;

  ThemeState copyWith({
    ThemePackage? package,
    List<ThemePackage>? available,
    Object? lastError = _sentinel,
  }) {
    return ThemeState(
      package: package ?? this.package,
      available: available ?? this.available,
      lastError: identical(lastError, _sentinel)
          ? this.lastError
          : lastError as String?,
    );
  }

  static const Object _sentinel = Object();
}

class ThemeController extends AsyncNotifier<ThemeState> {
  /// Last id that resolved to a real package. Drives the fallback policy.
  ThemePackage? _lastGood;

  static const String _fallbackId = 'official.light';

  @override
  Future<ThemeState> build() async {
    final repository = ref.watch(themeRepositoryProvider);
    final available = await repository.listThemes();
    final requestedId = ref.watch(activeThemeIdProvider);
    final resolved = await _resolve(repository, requestedId, available);
    _lastGood = resolved.package;
    return resolved;
  }

  /// Re-reads the catalog, e.g. after an import or deletion.
  Future<void> refresh() async {
    final repository = ref.read(themeRepositoryProvider);
    final available = await repository.listThemes();
    final currentId = state.value?.package.id ?? _fallbackId;
    final resolved = await _resolve(repository, currentId, available);
    _lastGood = resolved.package;
    state = AsyncData(resolved);
  }

  /// Switches to [id], keeping the previous skin when the new one is broken.
  Future<void> selectTheme(String id) async {
    final previous = state.value;
    final repository = ref.read(themeRepositoryProvider);
    final available = previous?.available ?? await repository.listThemes();
    final resolved = await _resolve(repository, id, available);
    _lastGood = resolved.package;
    state = AsyncData(resolved);
    await ref
        .read(settingsControllerProvider.notifier)
        .setActiveThemeId(resolved.package.id);
  }

  Future<ThemeState> _resolve(
    ThemeRepository repository,
    String requestedId,
    List<ThemePackage> available,
  ) async {
    ThemePackage? requested;
    try {
      requested = await repository.loadTheme(requestedId);
    } on Object {
      requested = null;
    }
    final byId = <String, ThemePackage>{
      for (final theme in available) theme.id: theme,
    };

    final chosen =
        requested ?? byId[requestedId] ?? _lastGood ?? byId[_fallbackId];
    if (chosen != null) {
      final error = (requested == null && chosen.id != requestedId)
          ? '皮肤 “$requestedId” 加载失败，已回退到 “${chosen.name}”'
          : null;
      return ThemeState(
        package: chosen,
        available: available,
        lastError: error,
      );
    }

    // Nothing at all could be loaded: synthesise the baseline skin so the app
    // still renders instead of white-screening.
    final availableList = available.isEmpty
        ? <ThemePackage>[await _builtInFallback(repository)]
        : available;
    return ThemeState(
      package: availableList.first,
      available: availableList,
      lastError: '无法加载任何皮肤，已使用内置默认皮肤',
    );
  }

  Future<ThemePackage> _builtInFallback(ThemeRepository repository) async {
    final builtIn = await repository.loadTheme(_fallbackId);
    if (builtIn != null) {
      return builtIn;
    }
    return ThemePackage(
      id: _fallbackId,
      name: 'Robyne 默认',
      author: 'Robyne',
      authorUrl: null,
      version: '1.0.0',
      description: '内置默认皮肤',
      preview: '#F7F8FA',
      tags: const <String>['light'],
      mode: ThemeModePreference.light,
      schemaVersion: 1,
      tokens: const ThemeTokens.baseline(),
      layout: const ThemeLayout.baseline(),
      settings: const <ThemeSetting>[],
      assets: const ThemeAssets.empty(),
      source: ThemeSource.builtIn,
    );
  }
}

class _CompositeThemeRepository implements ThemeRepository {
  const _CompositeThemeRepository(this._builtIn, this._user);

  final ThemeRepository _builtIn;
  final ThemeRepository _user;

  @override
  Future<List<ThemePackage>> listThemes() async {
    final builtIn = await _builtIn.listThemes();
    final user = await _safeUserThemes();
    return <ThemePackage>[...builtIn, ...user];
  }

  @override
  Future<ThemePackage?> loadTheme(String id) async {
    // User skins win over built-ins with the same id.
    //
    // This is what makes "copy an official skin and edit it" work (see
    // THEME_ROADMAP D5): a copied skin keeps its id, and must not be silently
    // shadowed by the built-in it was derived from. The reverse order made
    // the copy invisible while still listing it in the catalog.
    //
    // A broken user skin is not a hazard here: ThemeController remembers the
    // last skin that loaded successfully and falls back to that.
    final user = await _safeUserLoad(id);
    if (user != null) {
      return user;
    }
    return _builtIn.loadTheme(id);
  }

  Future<ThemePackage?> _safeUserLoad(String id) async {
    try {
      return await _user.loadTheme(id);
    } on Object {
      return null;
    }
  }

  @override
  Future<Directory> userThemesDirectory() => _user.userThemesDirectory();

  @override
  Future<bool> deleteTheme(String id) => _user.deleteTheme(id);

  /// A broken user theme directory must not hide the rest of the catalog.
  Future<List<ThemePackage>> _safeUserThemes() async {
    try {
      return await _user.listThemes();
    } on Object {
      return const <ThemePackage>[];
    }
  }
}
