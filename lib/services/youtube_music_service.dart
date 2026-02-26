import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/search_models.dart';
import 'music_service.dart';

class YoutubeMusicService implements MusicService {
  static const _searchUrl = 'https://music.youtube.com/youtubei/v1/search';
  static const _apiKey = 'REDACTED';

  static final _watchPattern = RegExp(
    r'music\.youtube\.com/watch\?v=([a-zA-Z0-9_-]+)',
  );
  static final _browsePattern = RegExp(
    r'music\.youtube\.com/browse/([a-zA-Z0-9_-]+)',
  );
  static final _channelPattern = RegExp(
    r'music\.youtube\.com/channel/([a-zA-Z0-9_-]+)',
  );

  final String _clientVersion;

  YoutubeMusicService() : _clientVersion = _buildClientVersion();

  static String _buildClientVersion() {
    final now = DateTime.now().toUtc();
    final date =
        '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    return '1.$date.01.00';
  }

  static const _filters = {
    ContentType.album: 'EgWKAQIYAWoKEAoQAxAEEAkQBQ%3D%3D',
    ContentType.artist: 'EgWKAQIgAWoKEAoQAxAEEAkQBQ%3D%3D',
    ContentType.song: 'EgWKAQIIAWoKEAoQAxAEEAkQBQ%3D%3D',
  };

  @override
  String get id => 'youtube_music';

  @override
  String get displayName => 'YouTube Music';

  @override
  Color get brandColor => const Color(0xFFFF0000);

  @override
  bool detect(String text) {
    return _watchPattern.hasMatch(text) ||
        _browsePattern.hasMatch(text) ||
        _channelPattern.hasMatch(text);
  }

  @override
  Future<SearchParams?> parse(String text) async {
    ContentType type;
    if (_watchPattern.hasMatch(text)) {
      type = ContentType.song;
    } else if (_browsePattern.hasMatch(text)) {
      type = ContentType.album;
    } else if (_channelPattern.hasMatch(text)) {
      type = ContentType.artist;
    } else {
      return null;
    }

    try {
      return await scrapeOgMeta(text, type);
    } catch (e) {
      debugPrint('YT Music parse failed: $e');
      return null;
    }
  }

  @override
  Future<SearchResult> search(SearchParams params) async {
    try {
      final response = await http.post(
        Uri.parse('$_searchUrl?key=$_apiKey'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
        body: jsonEncode({
          'context': {
            'client': {
              'clientName': 'WEB_REMIX',
              'clientVersion': _clientVersion,
            },
          },
          'query': params.query,
          'params': _filters[params.type],
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('status ${response.statusCode}');
      }

      return _parseResults(jsonDecode(response.body), params.type);
    } catch (e) {
      debugPrint('YT Music search failed: $e');
      return SearchResult(results: []);
    }
  }

  SearchResult _parseResults(Map<String, dynamic> data, ContentType type) {
    final results = <SearchResultItem>[];

    try {
      final contents =
          data['contents']?['tabbedSearchResultsRenderer']?['tabs']?[0]?['tabRenderer']?['content']?['sectionListRenderer']?['contents'];
      if (contents == null) return SearchResult(results: []);

      for (final section in contents) {
        final shelf = section['musicShelfRenderer'];
        if (shelf == null) continue;

        for (final item in shelf['contents'] ?? []) {
          final parsed = _parseItem(item, type);
          if (parsed != null) results.add(parsed);
          if (results.length >= 10) break;
        }
        if (results.length >= 10) break;
      }
    } catch (e) {
      debugPrint('Failed to parse YT Music response: $e');
    }

    return SearchResult(results: results);
  }

  SearchResultItem? _parseItem(Map<String, dynamic> item, ContentType type) {
    try {
      final renderer = item['musicResponsiveListItemRenderer'];
      if (renderer == null) return null;

      String? url;
      if (type == ContentType.song) {
        final videoId =
            renderer['overlay']?['musicItemThumbnailOverlayRenderer']?['content']?['musicPlayButtonRenderer']?['playNavigationEndpoint']?['watchEndpoint']?['videoId'];
        if (videoId != null) url = 'https://music.youtube.com/watch?v=$videoId';
      } else {
        final browseId =
            renderer['navigationEndpoint']?['browseEndpoint']?['browseId'];
        if (browseId != null) {
          url =
              type == ContentType.album
                  ? 'https://music.youtube.com/browse/$browseId'
                  : 'https://music.youtube.com/channel/$browseId';
        }
      }

      final cols = renderer['flexColumns'] as List?;
      final title =
          cols?[0]?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs']?[0]?['text']
              as String?;

      if (url == null || title == null) return null;
      return SearchResultItem(url: url, title: title);
    } catch (e) {
      debugPrint('Failed to parse YT Music item: $e');
      return null;
    }
  }
}
