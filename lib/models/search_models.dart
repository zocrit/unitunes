enum ContentType { song, artist, album }

class SearchParams {
  final String? name;
  final String? album;
  final String? artist;
  final ContentType type;

  SearchParams({
    this.name,
    this.album,
    this.artist,
    required this.type,
  });

  String get query {
    final parts = switch (type) {
      ContentType.album => [album, artist],
      ContentType.artist => [artist],
      ContentType.song => [name, artist],
    };
    return parts.whereType<String>().where((s) => s.isNotEmpty).join(' ');
  }
}

class SearchResult {
  final List<SearchResultItem> results;

  SearchResult({required this.results});
}

class SearchResultItem {
  final String url;
  final String title;

  SearchResultItem({required this.url, required this.title});
}
