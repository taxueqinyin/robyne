import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/result/result.dart';
import 'package:robyne/core/errors/app_error.dart';
import 'package:robyne/features/plugin/domain/plugin_definition.dart';
import 'package:robyne/features/plugin/domain/plugin_repository.dart';
import 'package:robyne/features/plugin/application/plugin_providers.dart';
import 'package:robyne/features/search/application/search_history_controller.dart';
import 'package:robyne/features/search/domain/search_history_entry.dart';
import 'package:robyne/features/search/presentation/search_page.dart';
import 'package:robyne/shared/widgets/search_field_with_history.dart';
import 'package:robyne/shared/widgets/search_history_overlay.dart';

/// The remembered searches live in a dropdown on the search field, the way a
/// web search box behaves: focus opens it, typing filters it, picking a row
/// runs it.
void main() {
  testWidgets('focusing the field opens the remembered searches', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        pluginRepositoryProvider.overrideWithValue(_EmptyPluginRepository()),
        searchHistoryControllerProvider.overrideWith(
          _SeededHistoryController.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    final focusNode = FocusNode();
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SearchFieldWithHistory(
              controller: controller,
              focusNode: focusNode,
              onSubmit: (_) {},
            ),
          ),
        ),
      ),
    );

    // Closed until the user actually engages with the field: a panel over the
    // page before anyone typed would just be clutter.
    expect(find.text('Recent searches'), findsNothing);

    focusNode.requestFocus();
    await tester.pumpAndSettle();

    expect(find.text('Recent searches'), findsOneWidget);
    expect(find.text('moonhalo'), findsOneWidget);
    expect(find.text('jay chou'), findsOneWidget);
  });

  testWidgets('typing filters the dropdown to matching entries', (tester) async {
    final container = ProviderContainer(
      overrides: [
        pluginRepositoryProvider.overrideWithValue(_EmptyPluginRepository()),
        searchHistoryControllerProvider.overrideWith(
          _SeededHistoryController.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    final focusNode = FocusNode();
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SearchFieldWithHistory(
              controller: controller,
              focusNode: focusNode,
              onSubmit: (_) {},
            ),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pumpAndSettle();

    controller.text = 'moon';
    await tester.pumpAndSettle();

    expect(find.text('moonhalo'), findsOneWidget);
    expect(find.text('jay chou'), findsNothing);

    // A keyword nothing matches falls back to the empty state rather than to
    // an empty panel with no explanation.
    controller.text = 'zzzz';
    await tester.pumpAndSettle();
    expect(find.text('No recent searches'), findsOneWidget);
  });

  testWidgets('picking a row fills the field and runs the search', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        pluginRepositoryProvider.overrideWithValue(_EmptyPluginRepository()),
        searchHistoryControllerProvider.overrideWith(
          _SeededHistoryController.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    final focusNode = FocusNode();
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    final submitted = <String>[];

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SearchFieldWithHistory(
              controller: controller,
              focusNode: focusNode,
              onSubmit: submitted.add,
            ),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pumpAndSettle();

    await tester.tap(find.text('moonhalo'));
    await tester.pumpAndSettle();

    expect(controller.text, 'moonhalo');
    expect(submitted, <String>['moonhalo']);
    // The panel closes once a choice is made, so the page underneath is
    // reachable again without a second dismiss.
    expect(find.text('Recent searches'), findsNothing);
  });

  testWidgets('arrowing down and pressing enter runs the highlighted row', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        pluginRepositoryProvider.overrideWithValue(_EmptyPluginRepository()),
        searchHistoryControllerProvider.overrideWith(
          _SeededHistoryController.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    final focusNode = FocusNode();
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    final submitted = <String>[];

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SearchFieldWithHistory(
              controller: controller,
              focusNode: focusNode,
              onSubmit: submitted.add,
            ),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pumpAndSettle();

    // Newest first, so the first ArrowDown lands on "moonhalo".
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    // Enter reaches a text field as the input action, not as a raw key event,
    // so drive it the way the platform does.
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(submitted, <String>['moonhalo']);
  });

  testWidgets('escape closes the dropdown', (tester) async {
    final container = ProviderContainer(
      overrides: [
        pluginRepositoryProvider.overrideWithValue(_EmptyPluginRepository()),
        searchHistoryControllerProvider.overrideWith(
          _SeededHistoryController.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    final focusNode = FocusNode();
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SearchFieldWithHistory(
              controller: controller,
              focusNode: focusNode,
              onSubmit: (_) {},
            ),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(find.text('Recent searches'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Recent searches'), findsNothing);
  });

  test('matchSearchHistory is case-insensitive and bounded', () {
    final entries = <SearchHistoryEntry>[
      for (var index = 0; index < 20; index += 1)
        SearchHistoryEntry(
          keyword: 'song $index',
          searchedAt: DateTime(2026, 1, index + 1),
        ),
    ];
    expect(matchSearchHistory(entries, 'SONG 3').single.keyword, 'song 3');
    // A long history is a dropdown, not a page: only the first rows are
    // offered, so the panel can never outgrow the viewport.
    expect(matchSearchHistory(entries, ''), hasLength(8));
  });

  testWidgets('the remove button drops just that entry', (tester) async {
    final container = ProviderContainer(
      overrides: [
        pluginRepositoryProvider.overrideWithValue(_EmptyPluginRepository()),
        searchHistoryControllerProvider.overrideWith(
          _SeededHistoryController.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    final focusNode = FocusNode();
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SearchFieldWithHistory(
              controller: controller,
              focusNode: focusNode,
              onSubmit: (_) {},
            ),
          ),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pumpAndSettle();

    // Two rows, so two remove buttons.
    expect(find.byIcon(Icons.close), findsNWidgets(2));
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();

    // The panel stays open so the user can keep pruning: removing one entry
    // must not look like dismissing the list.
    expect(find.text('Recent searches'), findsOneWidget);
    expect(find.text('moonhalo'), findsNothing);
    expect(find.text('jay chou'), findsOneWidget);
  });

  testWidgets('the search page no longer hosts the history', (tester) async {
    // The history was moved onto the field; a section on the results page
    // would duplicate it and push the results down.
    final container = ProviderContainer(
      overrides: [
        pluginRepositoryProvider.overrideWithValue(_EmptyPluginRepository()),
        searchHistoryControllerProvider.overrideWith(
          _SeededHistoryController.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SearchPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recent searches'), findsNothing);
    expect(find.byIcon(Icons.history), findsNothing);
  });
}

class _SeededHistoryController extends SearchHistoryController {
  @override
  Future<List<SearchHistoryEntry>> build() async => <SearchHistoryEntry>[
    SearchHistoryEntry(keyword: 'moonhalo', searchedAt: DateTime(2026, 1, 2)),
    SearchHistoryEntry(keyword: 'jay chou', searchedAt: DateTime(2026, 1, 1)),
  ];

  @override
  Future<void> remove(String keyword) async {
    final current = state.value ?? const <SearchHistoryEntry>[];
    state = AsyncData(
      current.where((entry) => entry.keyword != keyword).toList(),
    );
  }

  @override
  Future<void> clear() async {
    state = const AsyncData(<SearchHistoryEntry>[]);
  }
}

class _EmptyPluginRepository implements PluginRepository {
  @override
  Future<Result<List<PluginDefinition>>> listPlugins() async =>
      const Ok(<PluginDefinition>[]);

  @override
  Future<Result<void>> deletePlugin(String id) async => const Ok(null);

  @override
  Future<Result<List<PluginDefinition>>> reorderPlugins(
    List<String> orderedIds,
  ) async {
    return const Ok(<PluginDefinition>[]);
  }

  @override
  Future<Result<PluginDefinition>> importPluginFromPath(String path) async =>
      const Failure(AppError(code: 'unused', message: 'unused'));

  @override
  Future<PluginImportBatchResult> importPluginsFromPaths(
    List<String> paths, {
    PluginImportProgressCallback? onProgress,
  }) async =>
      const PluginImportBatchResult(
        importedCount: 0,
        updatedCount: 0,
        skippedCount: 0,
        errors: <AppError>[],
      );

  @override
  Future<Result<PluginDefinition>> importPluginFromUrl(String url) async =>
      const Failure(AppError(code: 'unused', message: 'unused'));

  @override
  Future<PluginImportBatchResult> importPluginBatchFromUrl(
    String url, {
    PluginImportProgressCallback? onProgress,
  }) async =>
      const PluginImportBatchResult(
        importedCount: 0,
        updatedCount: 0,
        skippedCount: 0,
        errors: <AppError>[],
      );

  @override
  Future<Result<PluginDefinition>> setEnabled(String id, bool enabled) async =>
      const Failure(AppError(code: 'unused', message: 'unused'));

  @override
  Future<Result<PluginDefinition>> updateUserVariableValues(
    String id,
    Map<String, String> values,
  ) async =>
      const Failure(AppError(code: 'unused', message: 'unused'));
}
