import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/search_models.dart';
import 'music_service.dart';

class TidalService implements MusicService {
  static final _tidalUrlPattern = RegExp(
    r'(?:listen\.tidal\.com|tidal\.com/browse)/(track|album|artist)/([a-zA-Z0-9-]+)',
  );

  static const _apiBase = 'https://api.tidal.com/v1';
  static const _token = 'REDACTED';
  static final _countryCode =
      Platform.localeName.split('_').lastOrNull?.toUpperCase() ?? 'US';

  static const _searchTypes = {
    ContentType.song: 'tracks',
    ContentType.album: 'albums',
    ContentType.artist: 'artists',
  };

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
    final searchType = _searchTypes[params.type] ?? 'tracks';

    try {
      final uri = Uri.parse('$_apiBase/search/$searchType').replace(
        queryParameters: {
          'query': params.query,
          'limit': '10',
          'countryCode': _countryCode,
        },
      );

      final response = await http.get(uri, headers: {
        'x-tidal-token': _token,
      });

      if (response.statusCode != 200) {
        throw Exception('status ${response.statusCode}');
      }

      return _parseResults(jsonDecode(response.body), params.type);
    } catch (e) {
      debugPrint('Tidal search failed: $e');
      return SearchResult(results: []);
    }
  }

  SearchResult _parseResults(Map<String, dynamic> data, ContentType type) {
    final items = data['items'] as List? ?? [];
    final results = <SearchResultItem>[];

    for (final item in items) {
      final id = item['id'];
      if (id == null) continue;

      final String url;
      final String title;

      switch (type) {
        case ContentType.song:
          url = 'https://tidal.com/browse/track/$id';
          title = item['title'] as String? ?? '';
        case ContentType.album:
          url = 'https://tidal.com/browse/album/$id';
          title = item['title'] as String? ?? '';
        case ContentType.artist:
          url = 'https://tidal.com/browse/artist/$id';
          title = item['name'] as String? ?? '';
      }

      if (title.isNotEmpty) {
        results.add(SearchResultItem(url: url, title: title));
      }
      if (results.length >= 10) break;
    }

    return SearchResult(results: results);
  }
}
