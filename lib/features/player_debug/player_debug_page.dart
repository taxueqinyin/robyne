import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:robyne/shared/providers/app_providers.dart';
import 'package:robyne/core/audio/playback_state.dart';

class PlayerDebugPage extends ConsumerStatefulWidget {
  const PlayerDebugPage({super.key});
  @override
  ConsumerState<PlayerDebugPage> createState() => _PlayerDebugPageState();
}

class _PlayerDebugPageState extends ConsumerState<PlayerDebugPage> {
  double _volume = 1.0;

  @override
  Widget build(BuildContext context) {
    final playbackState = ref.watch(playbackStateProvider);
    final state = playbackState.valueOrNull ?? const PlaybackState();
    final service = ref.read(playbackServiceProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Player Debug')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 播放状态
            Text('Status: ${state.status.name}',
                style: TextStyle(fontSize: 14, color: Colors.grey)),

            SizedBox(height: 12),

            // 当前曲目信息
            if (state.currentTrack != null) ...[
              Text(
                state.currentTrack!.title,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                state.currentTrack!.artist,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              if (state.currentTrack!.album != null)
                Text(
                  state.currentTrack!.album!,
                  style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                ),
            ] else
              Text('No track playing',
                  style: TextStyle(fontSize: 16, color: Colors.grey)),

            SizedBox(height: 16),

            // 进度条
            if (state.position != null && state.duration != null) ...[
              Row(
                children: [
                  Text(_formatDuration(state.position!),
                      style: TextStyle(fontSize: 12)),
                  Expanded(child: SizedBox()),
                  Text(_formatDuration(state.duration!),
                      style: TextStyle(fontSize: 12)),
                ],
              ),
              Slider(
                value: state.position!.inMilliseconds
                    .toDouble()
                    .clamp(0.0, state.duration!.inMilliseconds.toDouble()),
                max: state.duration!.inMilliseconds.toDouble(),
                onChanged: (v) =>
                    service.seek(Duration(milliseconds: v.toInt())),
              ),
            ],

            SizedBox(height: 8),

            // 播放控制按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.skip_previous, size: 36),
                  onPressed: () => service.playPrevious(),
                ),
                SizedBox(width: 16),
                IconButton(
                  icon: Icon(
                    state.status == PlaybackStatus.playing
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    size: 56,
                  ),
                  onPressed: () {
                    if (state.status == PlaybackStatus.playing) {
                      service.pause();
                    } else {
                      service.resume();
                    }
                  },
                ),
                SizedBox(width: 16),
                IconButton(
                  icon: Icon(Icons.skip_next, size: 36),
                  onPressed: () => service.playNext(),
                ),
              ],
            ),

            SizedBox(height: 16),

            // 音量调节
            Row(
              children: [
                Icon(Icons.volume_down, size: 20),
                Expanded(
                  child: Slider(
                    value: _volume,
                    min: 0.0,
                    max: 1.0,
                    onChanged: (v) {
                      setState(() => _volume = v);
                      service.setVolume(v);
                    },
                  ),
                ),
                Icon(Icons.volume_up, size: 20),
              ],
            ),

            SizedBox(height: 8),

            // 循环模式
            Row(
              children: [
                Text('Repeat: ${state.repeatMode.name}'),
                SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    service.setRepeatMode(
                      state.repeatMode == RepeatMode.off
                          ? RepeatMode.one
                          : RepeatMode.off,
                    );
                  },
                  child: Text('Toggle'),
                ),
              ],
            ),

            // 队列信息
            if (state.queue.isNotEmpty && state.queueIndex != null) ...[
              SizedBox(height: 8),
              Text(
                'Queue: ${state.queueIndex! + 1}/${state.queue.length}',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],

            // 错误信息
            if (state.errorMessage != null)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Error: ${state.errorMessage}',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
