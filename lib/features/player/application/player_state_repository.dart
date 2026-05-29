import 'dart:convert';
import 'dart:io';

import '../../../core/storage/local_file_store.dart';
import 'player_providers.dart';

class PlayerStateRepository {
  PlayerStateRepository({required LocalFileStore fileStore})
    : _fileStore = fileStore;

  static const _fileName = 'player_state.v1.json';

  final LocalFileStore _fileStore;

  Future<PlayerControllerState> load() async {
    try {
      final file = await _storageFile();
      if (!await file.exists()) {
        return const PlayerControllerState();
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) {
        return const PlayerControllerState();
      }
      return PlayerControllerState.fromJson(
        decoded.map(
          (key, dynamic value) => MapEntry(key.toString(), value as Object?),
        ),
      );
    } catch (_) {
      return const PlayerControllerState();
    }
  }

  Future<void> save(PlayerControllerState state) async {
    final file = await _storageFile();
    await file.writeAsString(jsonEncode(state.toJson()));
  }

  Future<File> _storageFile() async {
    return File('${(await _fileStore.dataDirectory()).path}/$_fileName');
  }
}
