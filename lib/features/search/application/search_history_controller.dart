import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/search_history_entry.dart';
import 'search_history_providers.dart';

/// The remembered search keywords, newest first.
///
/// Kept out of [SearchState] on purpose: history is persisted and survives
/// navigation, while `SearchState` is one in-flight search that is rebuilt
/// every time the user searches. Mixing them would make a cancelled search
/// discard the history too.
final searchHistoryControllerProvider =
    AsyncNotifierProvider<SearchHistoryController, List<SearchHistoryEntry>>(
      SearchHistoryController.new,
    );

class SearchHistoryController extends AsyncNotifier<List<SearchHistoryEntry>> {
  @override
  Future<List<SearchHistoryEntry>> build() async {
    return ref.watch(searchHistoryRepositoryProvider).load();
  }

  Future<void> remember(String keyword) async {
    final repository = ref.read(searchHistoryRepositoryProvider);
    try {
      final next = await repository.remember(keyword);
      if (ref.mounted) {
        state = AsyncData(next);
      }
    } catch (_) {
      // History is a convenience; a failed write must not disturb the rest
      // of the search page.
    }
  }

  Future<void> remove(String keyword) async {
    final repository = ref.read(searchHistoryRepositoryProvider);
    try {
      final next = await repository.remove(keyword);
      if (ref.mounted) {
        state = AsyncData(next);
      }
    } catch (_) {
      // Ignore: see [remember].
    }
  }

  Future<void> clear() async {
    final repository = ref.read(searchHistoryRepositoryProvider);
    try {
      final next = await repository.clear();
      if (ref.mounted) {
        state = AsyncData(next);
      }
    } catch (_) {
      // Ignore: see [remember].
    }
  }
}
