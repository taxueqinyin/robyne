import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:robyne/shared/providers/app_providers.dart';
import 'package:robyne/shared/models/track.dart';

class LocalDebugPage extends ConsumerWidget {
  const LocalDebugPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(localTracksProvider);
    final service = ref.read(playbackServiceProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Local Debug')),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: () async {
              final result = await FilePicker.platform.getDirectoryPath();
              if (result != null) {
                try {
                  await ref.read(localTracksProvider.notifier).scan(result);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Scan failed: $e')),
                    );
                  }
                }
              }
            },
            child: Text('Scan Directory'),
          ),
          Expanded(
            child: tracks.isEmpty
                ? Center(child: Text('No local tracks'))
                : ListView.builder(
                    itemCount: tracks.length,
                    itemBuilder: (context, index) {
                      final track = tracks[index];
                      return ListTile(
                        title: Text(track.title),
                        subtitle: Text(track.artist),
                        onTap: () {
                          // 设置播放队列，支持上下首切换
                          final items = tracks
                              .map((t) => QueueItem.fromTrack(t))
                              .toList();
                          service.setQueue(items, startIndex: index);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
