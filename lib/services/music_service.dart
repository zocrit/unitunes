import 'dart:ui';
import 'package:http/http.dart' as http;
import '../models/search_models.dart';

abstract class MusicService {
  String get id;
  String get displayName;
  Color get brandColor;

  bool detect(String text);
  Future<SearchParams?> parse(String text);
  Future<SearchResult> search(SearchParams params);
}

extension MusicServiceLookup on List<MusicService> {
  String displayNameFor(String id) =>
      where((s) => s.id == id).firstOrNull?.displayName ?? id;

  Color? colorFor(String id) =>
      where((s) => s.id == id).firstOrNull?.brandColor;
}

String normalizeUrl(String url) => url.startsWith('http') ? url : 'https://$url';

final _ogTitle = RegExp(r'<meta\s+property="og:title"\s+content="([^"]*)"');
final _ogDesc = RegExp(
  r'<meta\s+property="og:description"\s+content="([^"]*)"',
);
final _ogImage = RegExp(r'<meta\s+property="og:image"\s+content="([^"]*)"');

Future<SearchParams?> scrapeOgMeta(String url, ContentType type) async {
  final fullUrl = normalizeUrl(url);
  final response = await http.get(
    Uri.parse(fullUrl),
    headers: {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    },
  );
  if (response.statusCode != 200) return null;

  final html = response.body;
  final title = _ogTitle.firstMatch(html)?.group(1);
  if (title == null) return null;
  final description = _ogDesc.firstMatch(html)?.group(1);
  final imageUrl = _ogImage.firstMatch(html)?.group(1);

  return switch (type) {
    ContentType.song => SearchParams(
      name: title,
      artist: description,
      imageUrl: imageUrl,
      type: type,
    ),
    ContentType.album => SearchParams(
      album: title,
      artist: description,
      imageUrl: imageUrl,
      type: type,
    ),
    ContentType.artist => SearchParams(
      artist: title,
      imageUrl: imageUrl,
      type: type,
    ),
  };
}
