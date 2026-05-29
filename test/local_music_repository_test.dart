import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:robyne/core/result/result.dart';
import 'package:robyne/core/storage/local_file_store.dart';
import 'package:robyne/features/library/infrastructure/local_music_repository.dart';

void main() {
  test(
    'imports supported local files, filters unsupported files, and dedupes paths',
    () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'robyne_local_music_test_',
      );
      addTearDown(() async {
        await tempDirectory.delete(recursive: true);
      });
      final songA = await _writeFile(tempDirectory, 'A.mp3');
      final songB = await _writeFile(tempDirectory, 'B.FLAC');
      final note = await _writeFile(tempDirectory, 'notes.txt');

      final repository = LocalMusicRepository(
        fileStore: LocalFileStore(baseDirectory: tempDirectory),
      );

      final result = await repository.importFiles(<String>[
        songA.path,
        songA.path,
        songB.path,
        note.path,
      ]);

      final items = switch (result) {
        Ok(:final value) => value,
        Failure(:final error) => fail(error.toString()),
      };
      expect(items.map((item) => item.title), <String>['A', 'B']);

      final listed = await repository.listTracks();
      expect(
        listed.fold(
          (tracks) => tracks.map((item) => item.title).toList(),
          (_) => <String>[],
        ),
        <String>['A', 'B'],
      );
    },
  );

  test('imports a folder recursively and ignores unsupported files', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'robyne_local_folder_test_',
    );
    addTearDown(() async {
      await tempDirectory.delete(recursive: true);
    });
    await _writeFile(tempDirectory, 'root.mp3');
    final child = Directory('${tempDirectory.path}/child');
    await child.create();
    await _writeFile(child, 'nested.m4a');
    await _writeFile(child, 'cover.jpg');

    final repository = LocalMusicRepository(
      fileStore: LocalFileStore(baseDirectory: tempDirectory),
    );

    final result = await repository.importFolder(tempDirectory.path);
    final items = switch (result) {
      Ok(:final value) => value,
      Failure(:final error) => fail(error.toString()),
    };

    expect(items.map((item) => item.title).toSet(), <String>{'root', 'nested'});
  });

  test(
    'returns local.file_missing when importing a missing local file',
    () async {
      final tempDirectory = await Directory.systemTemp.createTemp(
        'robyne_local_missing_test_',
      );
      addTearDown(() async {
        await tempDirectory.delete(recursive: true);
      });
      final repository = LocalMusicRepository(
        fileStore: LocalFileStore(baseDirectory: tempDirectory),
      );

      final result = await repository.importFiles(<String>[
        '${tempDirectory.path}/missing.mp3',
      ]);

      expect(result, isA<Failure>());
      expect(
        result.fold((_) => '', (error) => error.code),
        'local.file_missing',
      );
    },
  );
}

Future<File> _writeFile(Directory directory, String name) async {
  final file = File('${directory.path}/$name');
  await file.writeAsBytes(<int>[1, 2, 3]);
  return file;
}
