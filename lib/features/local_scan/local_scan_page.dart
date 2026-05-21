import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:robyne/core/audio/audio_player_service.dart';
import 'package:robyne/core/database/app_database.dart';
import 'package:robyne/features/local_scan/local_scan_provider.dart';
import 'package:robyne/shared/models/song_model.dart';
import 'package:robyne/shared/providers/database_provider.dart';

final localSongsProvider = StreamProvider<List<Song>>((ref) {
  final songRepo = ref.watch(songRepositoryProvider);
  return songRepo.watchLocalSongs();
});

class LocalScanPage extends ConsumerWidget {
  const LocalScanPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanState = ref.watch(localScanNotifierProvider);
    final localSongsAsync = ref.watch(localSongsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Music'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: () => _selectDirectory(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          if (scanState.isScanning)
            LinearProgressIndicator(
              value: scanState.totalFiles > 0
                  ? scanState.scannedCount / scanState.totalFiles
                  : null,
            ),
          if (scanState.error != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                scanState.error!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Expanded(
            child: localSongsAsync.when(
              data: (songs) => songs.isEmpty
                  ? const Center(child: Text('No local songs found'))
                  : ListView.builder(
                      itemCount: songs.length,
                      itemBuilder: (context, index) {
                        final song = songs[index];
                        return ListTile(
                          leading: const Icon(Icons.music_note),
                          title: Text(song.title),
                          subtitle: Text(song.artist ?? 'Unknown Artist'),
                          onTap: () => _playSong(ref, song),
                        );
                      },
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDirectory(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      ref.read(localScanNotifierProvider.notifier).scanDirectory(result);
    }
  }

  void _playSong(WidgetRef ref, Song song) {
    final songModel = SongModel(
      id: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album,
      isLocal: song.isLocal,
      localPath: song.localPath,
      durationMs: song.durationMs,
    );
    ref.read(audioPlayerServiceProvider.notifier).playSong(songModel);
  }
}
