import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/search_models.dart';
import 'music_service.dart';

class TidalService implements MusicService {
  static final _tidalUrlPattern = RegExp(
    r'(?:listen\.tidal\.com|tidal\.com(?:/browse)?)/(track|album|artist)/([a-zA-Z0-9-]+)(?:/\w+)?',
  );

  static const _apiBase = 'https://api.tidal.com/v1';
  static const _token = String.fromEnvironment(
    'TIDAL_TOKEN',
    defaultValue: '',
  );
  static final _countryCode = () {
    final parts = Platform.localeName.split('_');
    if (parts.length < 2) return 'US';
    return parts[1].split('.').first.toUpperCase();
  }();

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
  Color get brandColor => const Color(0xFFFFFFFF);

  @override
  bool detect(String text) {
    return _tidalUrlPattern.hasMatch(text);
  }

  @override
  Future<SearchParams?> parse(String text) async {
    final match = _tidalUrlPattern.firstMatch(text);
    if (match == null) return null;

    final type = switch (match.group(1)!) {
      'track' => ContentType.song,
      'album' => ContentType.album,
      'artist' => ContentType.artist,
      _ => null,
    };
    if (type == null) return null;

    try {
      return await scrapeOgMeta(match.group(0)!, type);
    } catch (e) {
      debugPrint('Tidal parse failed: $e');
      return null;
    }
  }

  @override
  Future<SearchResult> search(SearchParams params) async {
    if (_token.isEmpty) {
      debugPrint('Tidal search: no key');
      return SearchResult(results: []);
    }

    final searchType = _searchTypes[params.type] ?? 'tracks';

    try {
      final uri = Uri.parse('$_apiBase/search/$searchType').replace(
        queryParameters: {
          'query': params.query,
          'limit': '10',
          'countryCode': _countryCode,
        },
      );

      final response = await http
          .get(uri, headers: {'x-tidal-token': _token})
          .timeout(const Duration(seconds: 10));

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

      final (url, title) = switch (type) {
        ContentType.song => (
          'https://tidal.com/browse/track/$id',
          item['title'] as String? ?? '',
        ),
        ContentType.album => (
          'https://tidal.com/browse/album/$id',
          item['title'] as String? ?? '',
        ),
        ContentType.artist => (
          'https://tidal.com/browse/artist/$id',
          item['name'] as String? ?? '',
        ),
      };

      if (title.isNotEmpty) {
        results.add(SearchResultItem(url: url, title: title));
      }
      if (results.length >= 10) break;
    }

    return SearchResult(results: results);
  }
}
