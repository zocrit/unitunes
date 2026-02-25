import 'package:flutter/foundation.dart';
import '../models/search_models.dart';
import 'music_service.dart';

class TidalService implements MusicService {
  static final _tidalUrlPattern = RegExp(
    r'(?:listen\.tidal\.com|tidal\.com/browse)/(track|album|artist)/([a-zA-Z0-9-]+)',
  );

  @override
  String get id => 'tidal';

  @override
  String get displayName => 'Tidal';

  @override
  bool detect(String text) {
    return _tidalUrlPattern.hasMatch(text);
  }

  @override
  Future<SearchParams?> parse(String text) async {
    final match = _tidalUrlPattern.firstMatch(text);
    if (match == null) return null;

    final ContentType type;
    switch (match.group(1)!) {
      case 'track':
        type = ContentType.song;
      case 'album':
        type = ContentType.album;
      case 'artist':
        type = ContentType.artist;
      default:
        return null;
    }

    try {
      return await scrapeOgMeta(text, type);
    } catch (e) {
      debugPrint('Tidal parse failed: $e');
      return null;
    }
  }

  @override
  Future<SearchResult> search(SearchParams params) async {
    final encoded = Uri.encodeComponent(params.query);
    final url = 'https://listen.tidal.com/search?q=$encoded';

    return SearchResult(
      results: [SearchResultItem(url: url, title: params.query)],
    );
  }
}
