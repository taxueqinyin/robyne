import 'dart:io';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:robyne/core/database/app_database.dart';
import 'package:robyne/core/database/repositories/song_repository.dart';
import 'package:robyne/core/metadata/tag_reader.dart';
import 'package:robyne/shared/providers/database_provider.dart';

part 'local_scan_provider.g.dart';

@riverpod
class LocalScanNotifier extends _$LocalScanNotifier {
  late SongRepository _songRepo;
  final TagReader _tagReader = TagReader();

  @override
  LocalScanState build() {
    _songRepo = ref.watch(songRepositoryProvider);
    return LocalScanState.initial();
  }

  Future<void> scanDirectory(String dirPath) async {
    state = state.copyWith(isScanning: true, error: null, scannedCount: 0);

    try {
      final files = await _tagReader.scanDirectory(dirPath);
      final totalFiles = files.length;
      var scannedCount = 0;
      final songsToInsert = <SongsCompanion>[];

      for (final file in files) {
        try {
          final tag = _tagReader.readTag(file as File);
          if (tag != null) {
            songsToInsert.add(SongsCompanion(
              title: Value(tag.title ?? _tagReader.getFileNameWithoutExtension(file.path)),
              artist: Value(tag.artist),
              album: Value(tag.album),
              durationMs: Value(tag.duration?.inMilliseconds),
              isLocal: const Value(true),
              localPath: Value(file.path),
            ));
          }
          scannedCount++;
          state = state.copyWith(scannedCount: scannedCount);
        } catch (e) {
          // Skip files that can't be read
          scannedCount++;
          state = state.copyWith(scannedCount: scannedCount);
        }
      }

      if (songsToInsert.isNotEmpty) {
        await _songRepo.insertSongs(songsToInsert);
      }

      state = state.copyWith(
        isScanning: false,
        totalFiles: totalFiles,
        successCount: songsToInsert.length,
      );
    } catch (e) {
      state = state.copyWith(
        isScanning: false,
        error: 'Scan failed: $e',
      );
    }
  }

  Future<void> rescanDirectory(String dirPath) async {
    // Delete existing local songs and rescan
    final existingSongs = await _songRepo.getLocalSongs();
    for (final song in existingSongs) {
      await _songRepo.deleteSong(song.id);
    }
    await scanDirectory(dirPath);
  }
}

class LocalScanState {
  final bool isScanning;
  final int scannedCount;
  final int totalFiles;
  final int successCount;
  final String? error;

  const LocalScanState({
    this.isScanning = false,
    this.scannedCount = 0,
    this.totalFiles = 0,
    this.successCount = 0,
    this.error,
  });

  LocalScanState copyWith({
    bool? isScanning,
    int? scannedCount,
    int? totalFiles,
    int? successCount,
    String? error,
  }) {
    return LocalScanState(
      isScanning: isScanning ?? this.isScanning,
      scannedCount: scannedCount ?? this.scannedCount,
      totalFiles: totalFiles ?? this.totalFiles,
      successCount: successCount ?? this.successCount,
      error: error,
    );
  }

  factory LocalScanState.initial() => const LocalScanState();
}
