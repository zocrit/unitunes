import 'search_models.dart';

class HistoryEntry {
  final String title;
  final String sourceUrl;
  final String targetUrl;
  final String sourceId;
  final String targetId;
  final ContentType type;
  final DateTime timestamp;

  HistoryEntry({
    required this.title,
    required this.sourceUrl,
    required this.targetUrl,
    required this.sourceId,
    required this.targetId,
    required this.type,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'sourceUrl': sourceUrl,
        'targetUrl': targetUrl,
        'sourceId': sourceId,
        'targetId': targetId,
        'type': type.name,
        'timestamp': timestamp.toIso8601String(),
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        title: json['title'] as String,
        sourceUrl: json['sourceUrl'] as String,
        targetUrl: json['targetUrl'] as String,
        sourceId: json['sourceId'] as String,
        targetId: json['targetId'] as String,
        type: ContentType.values.byName(json['type'] as String),
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}
