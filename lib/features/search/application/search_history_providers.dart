import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../plugin/application/plugin_providers.dart';
import '../infrastructure/search_history_repository.dart';

final searchHistoryRepositoryProvider = Provider<SearchHistoryRepository>((
  ref,
) {
  return SearchHistoryRepository(
    database: ref.watch(appDatabaseProvider),
    legacyMigration: ref.watch(legacyStorageMigrationProvider),
  );
});
