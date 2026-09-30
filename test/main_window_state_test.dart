import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/app/main_window_state.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

void main() {
  test('restores a saved window inside the current display work area', () {
    final bounds = restoreMainWindowBounds(
      state: const MainWindowState(
        size: Size(1100, 700),
        position: Offset(3200, 180),
      ),
      workArea: const Rect.fromLTWH(0, 0, 1920, 1040),
    );

    expect(bounds.size, const Size(1100, 700));
    expect(bounds.left, 820);
    expect(bounds.top, 180);
  });

  test('clamps an oversized saved window to the work area', () {
    final bounds = restoreMainWindowBounds(
      state: const MainWindowState(
        size: Size(2600, 1600),
        position: Offset(-400, -200),
      ),
      workArea: const Rect.fromLTWH(0, 0, 1920, 1040),
    );

    expect(bounds.size, const Size(1920, 1040));
    expect(bounds.topLeft, Offset.zero);
  });

  test('centers a saved window with no usable position', () {
    final bounds = restoreMainWindowBounds(
      state: const MainWindowState(size: Size(1000, 600)),
      workArea: const Rect.fromLTWH(0, 0, 1600, 900),
    );

    expect(bounds, const Rect.fromLTWH(300, 150, 1000, 600));
  });

  test('round-trips the main window geometry', () async {
    SharedPreferencesAsyncPlatform.instance = _MemoryPreferencesPlatform();
    final store = MainWindowStateStore();

    await store.save(
      const MainWindowState(
        size: Size(1440, 900),
        position: Offset(120, 80),
        maximized: true,
      ),
    );

    final loaded = await store.load();
    expect(loaded?.size, const Size(1440, 900));
    expect(loaded?.position, const Offset(120, 80));
    expect(loaded?.maximized, isTrue);
  });

  test('malformed persistence does not crash startup', () async {
    final platform = _MemoryPreferencesPlatform();
    SharedPreferencesAsyncPlatform.instance = platform;
    platform.values[MainWindowStateStore.storageKey] = '{broken';

    expect(await MainWindowStateStore().load(), isNull);

    platform.values[MainWindowStateStore.storageKey] = jsonEncode(
      <String, Object?>{'width': 0, 'height': 0},
    );
    final loaded = await MainWindowStateStore().load();
    expect(loaded?.size, MainWindowState.minimumSize);
  });
}

final class _MemoryPreferencesPlatform extends SharedPreferencesAsyncPlatform {
  final Map<String, Object> values = <String, Object>{};

  @override
  Future<String?> getString(
    String key,
    SharedPreferencesOptions options,
  ) async {
    final value = values[key];
    return value is String ? value : null;
  }

  @override
  Future<void> setString(
    String key,
    String value,
    SharedPreferencesOptions options,
  ) async {
    values[key] = value;
  }

  @override
  Future<Map<String, Object>> getPreferences(
    GetPreferencesParameters parameters,
    SharedPreferencesOptions options,
  ) async {
    return Map<String, Object>.from(values);
  }

  @override
  Future<Set<String>> getKeys(
    GetPreferencesParameters parameters,
    SharedPreferencesOptions options,
  ) async {
    return values.keys.toSet();
  }

  @override
  Future<void> clear(
    ClearPreferencesParameters parameters,
    SharedPreferencesOptions options,
  ) async {
    values.clear();
  }

  @override
  Future<void> setBool(
    String key,
    bool value,
    SharedPreferencesOptions options,
  ) async {
    values[key] = value;
  }

  @override
  Future<bool?> getBool(String key, SharedPreferencesOptions options) async {
    final value = values[key];
    return value is bool ? value : null;
  }

  @override
  Future<void> setDouble(
    String key,
    double value,
    SharedPreferencesOptions options,
  ) async {
    values[key] = value;
  }

  @override
  Future<double?> getDouble(
    String key,
    SharedPreferencesOptions options,
  ) async {
    final value = values[key];
    return value is double ? value : null;
  }

  @override
  Future<void> setInt(
    String key,
    int value,
    SharedPreferencesOptions options,
  ) async {
    values[key] = value;
  }

  @override
  Future<int?> getInt(String key, SharedPreferencesOptions options) async {
    final value = values[key];
    return value is int ? value : null;
  }

  @override
  Future<void> setStringList(
    String key,
    List<String> value,
    SharedPreferencesOptions options,
  ) async {
    values[key] = value;
  }

  @override
  Future<List<String>?> getStringList(
    String key,
    SharedPreferencesOptions options,
  ) async {
    final value = values[key];
    return value is List<String> ? value : null;
  }
}
