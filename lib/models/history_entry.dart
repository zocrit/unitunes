import 'search_models.dart';

class HistoryEntry {
  final String title;
  final String sourceUrl;
  final String targetUrl;
  final String sourceId;
  final String targetId;
  final ContentType type;
  final DateTime timestamp;
  final String? imageUrl;
  final String? artist;

  HistoryEntry({
    required this.title,
    required this.sourceUrl,
    required this.targetUrl,
    required this.sourceId,
    required this.targetId,
    required this.type,
    required this.timestamp,
    this.imageUrl,
    this.artist,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'sourceUrl': sourceUrl,
    'targetUrl': targetUrl,
    'sourceId': sourceId,
    'targetId': targetId,
    'type': type.name,
    'timestamp': timestamp.toIso8601String(),
    if (imageUrl != null) 'imageUrl': imageUrl,
    if (artist != null) 'artist': artist,
  };

  String get relativeTime {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
    title: json['title'] as String,
    sourceUrl: json['sourceUrl'] as String,
    targetUrl: json['targetUrl'] as String,
    sourceId: json['sourceId'] as String,
    targetId: json['targetId'] as String,
    type: ContentType.values.byName(json['type'] as String),
    timestamp: DateTime.parse(json['timestamp'] as String),
    imageUrl: json['imageUrl'] as String?,
    artist: json['artist'] as String?,
  );
}
