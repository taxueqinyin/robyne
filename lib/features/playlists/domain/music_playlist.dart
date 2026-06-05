import '../../player/domain/playback_item.dart';

class MusicPlaylist {
  const MusicPlaylist({
    required this.id,
    required this.name,
    required this.isFavorites,
    required this.items,
  });

  final String id;
  final String name;
  final bool isFavorites;
  final List<PlaybackItem> items;
}
