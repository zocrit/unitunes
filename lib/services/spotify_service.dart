import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:spotify/spotify.dart';
import '../models/search_models.dart';
import 'music_service.dart';

class SpotifyService implements MusicService {
  final SpotifyApi? _spotifyApi;

  static final _spotifyUrlPattern = RegExp(
    r'(?:https?://)?open\.spotify\.com/(track|artist|album)/([a-zA-Z0-9]+)',
  );
  static final _shortLinkPattern = RegExp(
    r'https?://spotify\.link/[a-zA-Z0-9]+',
  );
  static final _jsonLdPattern = RegExp(
    r'<script\s+type="application/ld\+json">\s*(.*?)\s*</script>',
    dotAll: true,
  );

  SpotifyService([this._spotifyApi]);

  static Future<SpotifyService> create(
    String clientId,
    String clientSecret,
  ) async {
    final credentials = SpotifyApiCredentials(clientId, clientSecret);
    final spotifyApi = SpotifyApi(credentials);
    return SpotifyService(spotifyApi);
  }

  @override
  String get id => 'spotify';

  @override
  String get displayName => 'Spotify';

  @override
  bool detect(String text) {
    return _spotifyUrlPattern.hasMatch(text) ||
        _shortLinkPattern.hasMatch(text);
  }

  @override
  Future<SearchParams?> parse(String text) async {
    final resolved = await _resolveUrl(text);
    if (resolved == null) return null;

    final match = _spotifyUrlPattern.firstMatch(resolved);
    if (match == null) return null;

    final urlType = match.group(1)!;
    final id = match.group(2)!;
    final fullUrl = match.group(0)!;

    final scraped = await _scrape(fullUrl, urlType);
    if (scraped != null) return scraped;

    if (_spotifyApi != null) {
      final apiResult = await _apiLookup(id, urlType);
      if (apiResult != null) return apiResult;
    }

    return null;
  }

  @override
  Future<SearchResult> search(SearchParams params) async {
    if (_spotifyApi != null) {
      try {
        final result = await _apiSearch(params);
        if (result != null) return result;
      } catch (_) {}
    }

    final encoded = Uri.encodeComponent(params.query);
    final url = 'https://open.spotify.com/search/$encoded';
    return SearchResult(
      results: [SearchResultItem(url: url, title: params.query)],
    );
  }

  Future<SearchResult?> _apiSearch(SearchParams params) async {
    final query = params.query;
    if (query.isEmpty) return null;

    final (searchType, urlSegment) = switch (params.type) {
      ContentType.song => (SearchType.track, 'track'),
      ContentType.album => (SearchType.album, 'album'),
      ContentType.artist => (SearchType.artist, 'artist'),
    };

    final pages =
        await _spotifyApi!.search.get(query, types: [searchType]).first();
    final items = pages.first.items;
    if (items == null || items.isEmpty) return null;

    final first = items.first;
    final (id, name) = switch (first) {
      Track t => (t.id, t.name),
      AlbumSimple a => (a.id, a.name),
      Artist a => (a.id, a.name),
      _ => (null, null),
    };
    if (id == null) return null;

    return SearchResult(
      results: [
        SearchResultItem(
          url: 'https://open.spotify.com/$urlSegment/$id',
          title: name ?? query,
        ),
      ],
    );
  }

  Future<String?> _resolveUrl(String text) async {
    if (_spotifyUrlPattern.hasMatch(text)) return text;

    if (_shortLinkPattern.hasMatch(text)) {
      final shortUrl = _shortLinkPattern.firstMatch(text)!.group(0)!;
      final resolved = await _resolveShortLink(shortUrl);
      if (resolved != null && _spotifyUrlPattern.hasMatch(resolved)) {
        return resolved;
      }
    }

    return null;
  }

  Future<SearchParams?> _scrape(String url, String urlType) async {
    try {
      final fullUrl = url.startsWith('http') ? url : 'https://$url';
      final response = await http.get(Uri.parse(fullUrl));
      if (response.statusCode != 200) return null;
      return _parseJsonLd(response.body, urlType);
    } catch (_) {
      return null;
    }
  }

  SearchParams? _parseJsonLd(String html, String urlType) {
    final match = _jsonLdPattern.firstMatch(html);
    if (match == null) return null;

    try {
      final jsonStr = match.group(1)!;
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final name = data['name'] as String?;
      if (name == null) return null;

      final description = data['description'] as String? ?? '';
      final ogImage = RegExp(
        r'<meta\s+property="og:image"\s+content="([^"]*)"',
      );
      final imageUrl = ogImage.firstMatch(html)?.group(1);

      return switch (urlType) {
        'track' => SearchParams(
          name: name,
          artist: _extractArtistFromDescription(description, afterIndex: 0),
          imageUrl: imageUrl,
          type: ContentType.song,
        ),
        'album' => SearchParams(
          album: name,
          artist: _extractArtistFromDescription(description, afterIndex: 1),
          imageUrl: imageUrl,
          type: ContentType.album,
        ),
        'artist' => SearchParams(
          artist: name,
          imageUrl: imageUrl,
          type: ContentType.artist,
        ),
        _ => null,
      };
    } catch (_) {
      return null;
    }
  }

  String? _extractArtistFromDescription(
    String description, {
    required int afterIndex,
  }) {
    final parts = description.split('·').map((s) => s.trim()).toList();
    final artistIndex = afterIndex + 1;
    if (parts.length > artistIndex) {
      final artist = parts[artistIndex];
      if (artist.isNotEmpty) return artist;
    }
    return null;
  }

  Future<SearchParams?> _apiLookup(String id, String urlType) async {
    try {
      switch (urlType) {
        case 'track':
          final track = await _spotifyApi!.tracks.get(id);
          return SearchParams(
            name: track.name,
            album: track.album?.name,
            artist:
                track.artists?.isNotEmpty == true
                    ? track.artists!.first.name
                    : null,
            imageUrl: track.album?.images?.firstOrNull?.url,
            type: ContentType.song,
          );
        case 'artist':
          final artist = await _spotifyApi!.artists.get(id);
          return SearchParams(
            artist: artist.name,
            imageUrl: artist.images?.firstOrNull?.url,
            type: ContentType.artist,
          );
        case 'album':
          final album = await _spotifyApi!.albums.get(id);
          return SearchParams(
            album: album.name,
            artist:
                album.artists?.isNotEmpty == true
                    ? album.artists!.first.name
                    : null,
            imageUrl: album.images?.firstOrNull?.url,
            type: ContentType.album,
          );
        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _resolveShortLink(String url) async {
    try {
      final request = http.Request('GET', Uri.parse(url))
        ..followRedirects = false;
      final response = await request.send();
      return response.headers['location'];
    } catch (_) {
      return null;
    }
  }
}
