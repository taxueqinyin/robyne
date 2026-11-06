import '../../player/domain/playback_item.dart';

class MusicPlaylist {
  const MusicPlaylist({
    required this.id,
    required this.name,
    required this.isFavorites,
    required this.items,
    this.description = '',
    this.coverUrl,
  });

  final String id;
  final String name;
  final String description;
  final String? coverUrl;
  final bool isFavorites;
  final List<PlaybackItem> items;

  /// The saved cover, or the first track's artwork as a generated fallback.
  String? get resolvedCoverUrl {
    final saved = coverUrl?.trim();
    if (saved != null && saved.isNotEmpty) {
      return saved;
    }
    for (final item in items) {
      final artwork = item.artworkUrl?.trim();
      if (artwork != null && artwork.isNotEmpty) {
        return artwork;
      }
    }
    return null;
  }

  MusicPlaylist copyWith({
    String? id,
    String? name,
    String? description,
    Object? coverUrl = _unset,
    bool? isFavorites,
    List<PlaybackItem>? items,
  }) {
    return MusicPlaylist(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      coverUrl: identical(coverUrl, _unset)
          ? this.coverUrl
          : coverUrl as String?,
      isFavorites: isFavorites ?? this.isFavorites,
      items: items ?? this.items,
    );
  }
}

const Object _unset = Object();
