import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/database/app_database.dart' as db;
import 'package:robyne/features/downloads/domain/download_task.dart';
import 'package:robyne/features/downloads/infrastructure/download_repository.dart';
import 'package:robyne/features/player/domain/playback_item.dart';

void main() {
  test('marks interrupted queued and downloading tasks as failed', () async {
    final database = db.AppDatabase.memory();
    addTearDown(database.close);
    final repository = DownloadRepository(database: database);
    final itemA = _item('A');
    final itemB = _item('B');
    final now = DateTime(2026);
    await repository.upsertTask(
      DownloadTask(
        id: itemA.id,
        item: itemA,
        status: DownloadStatus.queued,
        progress: 0,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await repository.upsertTask(
      DownloadTask(
        id: itemB.id,
        item: itemB,
        status: DownloadStatus.downloading,
        progress: 0.5,
        createdAt: now,
        updatedAt: now,
      ),
    );

    await repository.markInterruptedDownloadsFailed();

    final tasks = await repository.listTasks();
    expect(tasks.map((task) => task.status).toSet(), <DownloadStatus>{
      DownloadStatus.failed,
    });
    expect(tasks.every((task) => task.errorMessage != null), isTrue);
  });

  test('finds completed task for playback reuse', () async {
    final database = db.AppDatabase.memory();
    addTearDown(database.close);
    final repository = DownloadRepository(database: database);
    final item = _item('A');
    await repository.upsertTask(
      DownloadTask(
        id: item.id,
        item: item,
        status: DownloadStatus.completed,
        progress: 1,
        filePath: 'D:/music/A.audio',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        completedAt: DateTime(2026),
      ),
    );

    final completed = await repository.completedForItem(item.id);

    expect(completed?.filePath, 'D:/music/A.audio');
  });
}

PlaybackItem _item(String id) {
  return PlaybackItem.plugin(
    platform: 'Test',
    musicId: id,
    title: id,
    raw: <String, Object?>{'id': id},
  );
}
