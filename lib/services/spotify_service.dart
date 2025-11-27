import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:spotify/spotify.dart';
import '../models/search_models.dart';

class SpotifyService {
  final SpotifyApi? _spotifyApi;

  static final _spotifyUrlPattern = RegExp(
    r'(?:https?://)?open\.spotify\.com/(track|artist|album)/([a-zA-Z0-9]+)'
  );
  static final _shortLinkPattern = RegExp(
    r'https?://spotify\.link/[a-zA-Z0-9]+'
  );
  static final _jsonLdPattern = RegExp(
    r'<script\s+type="application/ld\+json">\s*(.*?)\s*</script>',
    dotAll: true,
  );

  SpotifyService([this._spotifyApi]);

  static Future<SpotifyService> create(String clientId, String clientSecret) async {
    final credentials = SpotifyApiCredentials(clientId, clientSecret);
    final spotifyApi = SpotifyApi(credentials);
    return SpotifyService(spotifyApi);
  }

  static bool detect(String text) {
    return _spotifyUrlPattern.hasMatch(text) || _shortLinkPattern.hasMatch(text);
  }

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

      switch (urlType) {
        case 'track':
          // "Listen to X on Spotify. Song · ArtistName · 2024"
          final artist = _extractArtistFromDescription(description, afterIndex: 0);
          return SearchParams(
            name: name,
            artist: artist,
            type: ContentType.song,
          );
        case 'album':
          // "Listen to X on Spotify · album · ArtistName · 2024 · N songs"
          final artist = _extractArtistFromDescription(description, afterIndex: 1);
          return SearchParams(
            album: name,
            artist: artist,
            type: ContentType.album,
          );
        case 'artist':
          return SearchParams(
            artist: name,
            type: ContentType.artist,
          );
        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  String? _extractArtistFromDescription(String description, {required int afterIndex}) {
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
            artist: track.artists?.isNotEmpty == true ? track.artists!.first.name : null,
            type: ContentType.song,
          );
        case 'artist':
          final artist = await _spotifyApi!.artists.get(id);
          return SearchParams(
            artist: artist.name,
            type: ContentType.artist,
          );
        case 'album':
          final album = await _spotifyApi!.albums.get(id);
          return SearchParams(
            album: album.name,
            artist: album.artists?.isNotEmpty == true ? album.artists!.first.name : null,
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
      final request = http.Request('GET', Uri.parse(url))..followRedirects = false;
      final response = await request.send();
      return response.headers['location'];
    } catch (_) {
      return null;
    }
  }
}
