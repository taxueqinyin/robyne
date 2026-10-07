/// One remembered search keyword.
///
/// The keyword is the identity: searching the same word again refreshes the
/// existing entry instead of adding a duplicate.
class SearchHistoryEntry {
  const SearchHistoryEntry({required this.keyword, required this.searchedAt});

  final String keyword;
  final DateTime searchedAt;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'keyword': keyword,
      'searchedAt': searchedAt.toIso8601String(),
    };
  }

  static SearchHistoryEntry? fromJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    final keyword = value['keyword']?.toString().trim() ?? '';
    if (keyword.isEmpty) {
      return null;
    }
    final searchedAt = DateTime.tryParse(value['searchedAt']?.toString() ?? '');
    return SearchHistoryEntry(
      keyword: keyword,
      searchedAt: searchedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SearchHistoryEntry &&
        other.keyword == keyword &&
        other.searchedAt == searchedAt;
  }

  @override
  int get hashCode => Object.hash(keyword, searchedAt);

  @override
  String toString() => 'SearchHistoryEntry($keyword)';
}
