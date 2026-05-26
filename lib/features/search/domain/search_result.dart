import 'music_item.dart';

class SearchResult {
  const SearchResult({
    required this.items,
    required this.page,
    required this.isEnd,
    this.raw,
  });

  final List<MusicItem> items;
  final int page;
  final bool isEnd;
  final Map<String, Object?>? raw;
}
